import '../../../core/domain/game_session.dart';

enum DailyChallengeId {
  completeOneRound,
  completeThreeRounds,
  scoreTarget,
  catchesTarget,
  measuredRound,
  validObservations,
  calibratedPeak,
  bothModes,
  multipleDays,
  beatPersonalBest,
}

class DailyChallengeDefinition {
  final DailyChallengeId id;
  final String title;
  final String description;
  final int target;
  final String badge;
  final bool requiresSmileData;

  const DailyChallengeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.badge,
    this.requiresSmileData = false,
  });
}

const dailyChallengeDefinitions = <DailyChallengeDefinition>[
  DailyChallengeDefinition(
    id: DailyChallengeId.completeOneRound,
    title: 'Play a Round',
    description: 'Complete 1 verified round today.',
    target: 1,
    badge: '🎮',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.completeThreeRounds,
    title: 'Triple Play',
    description: 'Complete 3 verified rounds today.',
    target: 3,
    badge: '3️⃣',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.scoreTarget,
    title: 'Score 500',
    description: 'Reach 500 points in one verified round today.',
    target: 500,
    badge: '⭐',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.catchesTarget,
    title: 'Five Catches',
    description: 'Make 5 successful catches in one verified round today.',
    target: 5,
    badge: '🎯',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.measuredRound,
    title: 'Measured Smile Round',
    description: 'Complete 1 round with valid calibrated smile observations.',
    target: 1,
    badge: '✨',
    requiresSmileData: true,
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.validObservations,
    title: 'Observation Practice',
    description: 'Record 20 valid calibrated smile observations today.',
    target: 20,
    badge: '🔎',
    requiresSmileData: true,
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.calibratedPeak,
    title: 'Peak Practice',
    description: 'Reach 80% calibrated peak intensity today.',
    target: 80,
    badge: '⛰️',
    requiresSmileData: true,
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.bothModes,
    title: 'Mix It Up',
    description:
        'Complete verified play using both Smile and Touch modes today.',
    target: 2,
    badge: '🔄',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.multipleDays,
    title: 'Return Player',
    description: 'Complete rounds on 2 distinct verified activity days.',
    target: 2,
    badge: '📅',
  ),
  DailyChallengeDefinition(
    id: DailyChallengeId.beatPersonalBest,
    title: 'Beat Your Best',
    description: 'Beat your previous verified score best today.',
    target: 1,
    badge: '🏆',
  ),
];

class DailyChallengeAssignment {
  final String playerId;
  final String dateKey;
  final DailyChallengeId challengeId;
  final int timezoneOffsetMinutes;
  final DateTime assignedAt;

  const DailyChallengeAssignment({
    required this.playerId,
    required this.dateKey,
    required this.challengeId,
    required this.timezoneOffsetMinutes,
    required this.assignedAt,
  });
}

class DailyChallengeProgress {
  final DailyChallengeDefinition definition;
  final int progress;
  final bool available;
  const DailyChallengeProgress({
    required this.definition,
    required this.progress,
    required this.available,
  });
  int get boundedProgress =>
      progress < 0
          ? 0
          : progress > definition.target
          ? definition.target
          : progress;
  bool get isComplete => available && progress >= definition.target;
  double get fraction => available ? boundedProgress / definition.target : 0;
}

class PlayerStreak {
  final int current;
  final int longest;
  final int activeDayCount;
  const PlayerStreak({
    required this.current,
    required this.longest,
    required this.activeDayCount,
  });
}

class DailyChallengeGenerator {
  const DailyChallengeGenerator();
  List<DailyChallengeId> generate({
    required String playerId,
    required String dateKey,
    required bool smileDataAvailable,
    int count = 3,
  }) {
    final pool =
        dailyChallengeDefinitions
            .where((item) => smileDataAvailable || !item.requiresSmileData)
            .map((item) => item.id)
            .toList();
    var seed = 2166136261;
    for (final value in '$playerId|$dateKey'.codeUnits) {
      seed = ((seed ^ value) * 16777619) & 0x7fffffff;
    }
    final selected = <DailyChallengeId>[];
    while (selected.length < count && pool.isNotEmpty) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      selected.add(pool.removeAt(seed % pool.length));
    }
    return selected;
  }
}

class DailyChallengeEvaluator {
  const DailyChallengeEvaluator();

  List<DailyChallengeProgress> evaluate({
    required String playerId,
    required List<DailyChallengeAssignment> assignments,
    required Iterable<GameSessionRecord> records,
  }) {
    if (assignments.isEmpty) return const [];
    final dateKey = assignments.first.dateKey;
    final offset = assignments.first.timezoneOffsetMinutes;
    final owned = _eligible(playerId, records);
    final today =
        owned
            .where(
              (record) =>
                  dateKeyFor(
                    record.endedAt!,
                    record.completionTimezoneOffsetMinutes ?? offset,
                  ) ==
                  dateKey,
            )
            .toList();
    final measuredToday = today.where(hasValidSmileMeasurement).toList();
    final smileAvailable = owned.any(hasValidSmileMeasurement);
    final activityDays =
        owned
            .map(
              (record) => dateKeyFor(
                record.endedAt!,
                record.completionTimezoneOffsetMinutes ?? 0,
              ),
            )
            .toSet()
            .length;
    final modes = <String>{};
    for (final record in today) {
      if (record.usedSmileMode == true) modes.add('smile');
      if (record.usedTouchMode == true) modes.add('touch');
    }
    final previous =
        owned
            .where(
              (record) =>
                  dateKeyFor(
                    record.endedAt!,
                    record.completionTimezoneOffsetMinutes ?? offset,
                  ).compareTo(dateKey) <
                  0,
            )
            .toList();
    final priorBest = previous.fold<int>(
      0,
      (best, record) => record.score > best ? record.score : best,
    );
    final beatBest =
        priorBest > 0 && today.any((record) => record.score > priorBest);
    final progress = <DailyChallengeId, (int, bool)>{
      DailyChallengeId.completeOneRound: (today.length, true),
      DailyChallengeId.completeThreeRounds: (today.length, true),
      DailyChallengeId.scoreTarget: (
        today.fold<int>(
          0,
          (best, record) => record.score > best ? record.score : best,
        ),
        true,
      ),
      DailyChallengeId.catchesTarget: (
        today.fold<int>(
          0,
          (best, record) => record.catches > best ? record.catches : best,
        ),
        true,
      ),
      DailyChallengeId.measuredRound: (
        measuredToday.isEmpty ? 0 : 1,
        smileAvailable,
      ),
      DailyChallengeId.validObservations: (
        measuredToday.fold<int>(
          0,
          (sum, record) => sum + (record.calibratedSmileSampleCount ?? 0),
        ),
        smileAvailable,
      ),
      DailyChallengeId.calibratedPeak: (
        measuredToday.fold<int>(0, (best, record) {
          final peak = record.peakCalibratedSmileIntensity!.floor();
          return peak > best ? peak : best;
        }),
        smileAvailable,
      ),
      DailyChallengeId.bothModes: (modes.length, true),
      DailyChallengeId.multipleDays: (activityDays, true),
      DailyChallengeId.beatPersonalBest: (
        beatBest ? 1 : 0,
        previous.isNotEmpty,
      ),
    };
    return [
      for (final assignment in assignments)
        PlayerChallengeProgressFactory.create(
          assignment.challengeId,
          progress[assignment.challengeId]!,
        ),
    ];
  }

  List<GameSessionRecord> _eligible(
    String playerId,
    Iterable<GameSessionRecord> records,
  ) {
    final byId = <int, GameSessionRecord>{};
    for (final record in records) {
      if (record.playerId == playerId &&
          record.state == GameSessionState.results &&
          record.endedAt != null)
        byId.putIfAbsent(record.id, () => record);
    }
    return byId.values.toList();
  }
}

class PlayerChallengeProgressFactory {
  static DailyChallengeProgress create(
    DailyChallengeId id,
    (int, bool) value,
  ) => DailyChallengeProgress(
    definition: dailyChallengeDefinitions.singleWhere((item) => item.id == id),
    progress: value.$1,
    available: value.$2,
  );
}

class StreakCalculator {
  const StreakCalculator();
  PlayerStreak calculate({
    required String playerId,
    required Iterable<GameSessionRecord> records,
    required String effectiveTodayKey,
  }) {
    final days =
        records
            .where(
              (record) =>
                  record.playerId == playerId &&
                  record.state == GameSessionState.results &&
                  record.endedAt != null,
            )
            .map(
              (record) => dateKeyFor(
                record.endedAt!,
                record.completionTimezoneOffsetMinutes ?? 0,
              ),
            )
            .toSet()
            .toList()
          ..sort();
    if (days.isEmpty)
      return const PlayerStreak(current: 0, longest: 0, activeDayCount: 0);
    var longest = 1;
    var run = 1;
    for (var index = 1; index < days.length; index++) {
      if (_parse(days[index]).difference(_parse(days[index - 1])).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    final gap = _parse(effectiveTodayKey).difference(_parse(days.last)).inDays;
    var current = 0;
    if (gap == 0 || gap == 1) {
      current = 1;
      for (var index = days.length - 1; index > 0; index--) {
        if (_parse(days[index]).difference(_parse(days[index - 1])).inDays != 1)
          break;
        current++;
      }
    }
    return PlayerStreak(
      current: current,
      longest: longest,
      activeDayCount: days.length,
    );
  }
}

bool hasValidSmileMeasurement(GameSessionRecord record) =>
    record.calibratedSmileAttempted == true &&
    (record.calibratedSmileSampleCount ?? 0) > 0 &&
    record.averageCalibratedSmileIntensity != null &&
    record.peakCalibratedSmileIntensity != null &&
    record.averageCalibratedSmileIntensity!.isFinite &&
    record.peakCalibratedSmileIntensity!.isFinite &&
    record.averageCalibratedSmileIntensity! >= 0 &&
    record.averageCalibratedSmileIntensity! <=
        record.peakCalibratedSmileIntensity! &&
    record.peakCalibratedSmileIntensity! <= 100;

String dateKeyFor(DateTime timestamp, int offsetMinutes) {
  final local = timestamp.toUtc().add(Duration(minutes: offsetMinutes));
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

DateTime _parse(String key) => DateTime.utc(
  int.parse(key.substring(0, 4)),
  int.parse(key.substring(5, 7)),
  int.parse(key.substring(8, 10)),
);
