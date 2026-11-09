import '../../../core/domain/game_session.dart';

enum AchievementCategory { gameplay, smile, progress }

enum AchievementId {
  firstCatch,
  gettingStarted,
  dedicatedPlayer,
  scoreMilestone,
  consistency,
  firstSmileMeasurement,
  smileExplorer,
  highPeak,
  smileProgress,
  personalBest,
  comeback,
  regularPlayer,
}

class AchievementDefinition {
  final AchievementId id;
  final String title;
  final String description;
  final AchievementCategory category;
  final int target;
  final String badge;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.target,
    required this.badge,
  });
}

const achievementDefinitions = <AchievementDefinition>[
  AchievementDefinition(
    id: AchievementId.firstCatch,
    title: 'First Catch',
    description: 'Complete a verified round with a successful catch.',
    category: AchievementCategory.gameplay,
    target: 1,
    badge: '🎯',
  ),
  AchievementDefinition(
    id: AchievementId.gettingStarted,
    title: 'Getting Started',
    description: 'Complete 5 verified rounds.',
    category: AchievementCategory.gameplay,
    target: 5,
    badge: '🚀',
  ),
  AchievementDefinition(
    id: AchievementId.dedicatedPlayer,
    title: 'Dedicated Player',
    description: 'Complete 25 verified rounds.',
    category: AchievementCategory.gameplay,
    target: 25,
    badge: '🏅',
  ),
  AchievementDefinition(
    id: AchievementId.scoreMilestone,
    title: 'Score Milestone',
    description: 'Reach 1,000 points in a verified round.',
    category: AchievementCategory.gameplay,
    target: 1000,
    badge: '⭐',
  ),
  AchievementDefinition(
    id: AchievementId.consistency,
    title: 'Consistency',
    description: 'Complete 10 verified rounds.',
    category: AchievementCategory.gameplay,
    target: 10,
    badge: '🔥',
  ),
  AchievementDefinition(
    id: AchievementId.firstSmileMeasurement,
    title: 'First Smile Measurement',
    description: 'Complete a round with valid calibrated observations.',
    category: AchievementCategory.smile,
    target: 1,
    badge: '✨',
  ),
  AchievementDefinition(
    id: AchievementId.smileExplorer,
    title: 'Smile Explorer',
    description: 'Complete 5 calibrated measured rounds.',
    category: AchievementCategory.smile,
    target: 5,
    badge: '🧭',
  ),
  AchievementDefinition(
    id: AchievementId.highPeak,
    title: 'High Peak',
    description: 'Record a calibrated peak intensity of at least 90%.',
    category: AchievementCategory.smile,
    target: 90,
    badge: '⛰️',
  ),
  AchievementDefinition(
    id: AchievementId.smileProgress,
    title: 'Smile Progress',
    description:
        'Record a higher round-average intensity than an earlier measured round.',
    category: AchievementCategory.smile,
    target: 1,
    badge: '📈',
  ),
  AchievementDefinition(
    id: AchievementId.personalBest,
    title: 'Personal Best',
    description: 'Beat an earlier verified score.',
    category: AchievementCategory.progress,
    target: 1,
    badge: '🏆',
  ),
  AchievementDefinition(
    id: AchievementId.comeback,
    title: 'Comeback',
    description: 'Score higher than the immediately preceding verified round.',
    category: AchievementCategory.progress,
    target: 1,
    badge: '💪',
  ),
  AchievementDefinition(
    id: AchievementId.regularPlayer,
    title: 'Regular Player',
    description: 'Complete verified rounds on 3 distinct calendar days.',
    category: AchievementCategory.progress,
    target: 3,
    badge: '📅',
  ),
];

class AchievementUnlock {
  final String playerId;
  final AchievementId achievementId;
  final DateTime unlockedAt;
  final int sourceResultId;

  const AchievementUnlock({
    required this.playerId,
    required this.achievementId,
    required this.unlockedAt,
    required this.sourceResultId,
  });
}

class PlayerAchievementProgress {
  final AchievementDefinition definition;
  final int progress;
  final bool available;
  final AchievementUnlock? unlock;

  const PlayerAchievementProgress({
    required this.definition,
    required this.progress,
    required this.available,
    this.unlock,
  });
  int get boundedProgress =>
      progress < 0
          ? 0
          : progress > definition.target
          ? definition.target
          : progress;
  bool get isUnlocked => unlock != null;
  double get fraction =>
      definition.target == 0 ? 0 : boundedProgress / definition.target;
}

class AchievementEvaluation {
  final List<PlayerAchievementProgress> progress;
  const AchievementEvaluation(this.progress);
  List<PlayerAchievementProgress> get eligibleToUnlock => progress
      .where(
        (item) =>
            item.available &&
            !item.isUnlocked &&
            item.progress >= item.definition.target,
      )
      .toList(growable: false);
}

class AchievementEvaluator {
  const AchievementEvaluator();

  AchievementEvaluation evaluate({
    required String playerId,
    required Iterable<GameSessionRecord> records,
    Iterable<AchievementUnlock> unlocks = const [],
  }) {
    final completed =
        records
            .where(
              (record) =>
                  record.playerId == playerId &&
                  record.state == GameSessionState.results &&
                  record.endedAt != null,
            )
            .toList()
          ..sort((a, b) {
            final time = a.endedAt!.compareTo(b.endedAt!);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final unique =
        <int, GameSessionRecord>{
          for (final record in completed) record.id: record,
        }.values.toList();
    final unlockById = {
      for (final unlock in unlocks.where((item) => item.playerId == playerId))
        unlock.achievementId: unlock,
    };
    final measured = unique.where(_hasValidMeasurement).toList();
    final distinctDays =
        unique
            .map((record) {
              final time = record.endedAt!.toUtc();
              return '${time.year}-${time.month}-${time.day}';
            })
            .toSet()
            .length;
    final smileImproved = _hasLaterImprovement(
      measured,
      (record) => record.averageCalibratedSmileIntensity!,
    );
    final scoreImproved = _hasLaterImprovement(
      unique,
      (record) => record.score.toDouble(),
    );
    var comeback = false;
    for (var index = 1; index < unique.length; index++) {
      if (unique[index].score > unique[index - 1].score) comeback = true;
    }
    final progress = <AchievementId, (int, bool)>{
      AchievementId.firstCatch: (
        unique.any((r) => r.catches > 0) ? 1 : 0,
        true,
      ),
      AchievementId.gettingStarted: (unique.length, true),
      AchievementId.dedicatedPlayer: (unique.length, true),
      AchievementId.scoreMilestone: (
        unique.fold<int>(0, (best, r) => r.score > best ? r.score : best),
        true,
      ),
      AchievementId.consistency: (unique.length, true),
      AchievementId.firstSmileMeasurement: (
        measured.isEmpty ? 0 : 1,
        measured.isNotEmpty,
      ),
      AchievementId.smileExplorer: (measured.length, measured.isNotEmpty),
      AchievementId.highPeak: (
        measured.fold<int>(0, (best, r) {
          final value = r.peakCalibratedSmileIntensity!.floor();
          return value > best ? value : best;
        }),
        measured.isNotEmpty,
      ),
      AchievementId.smileProgress: (
        smileImproved ? 1 : 0,
        measured.length >= 2,
      ),
      AchievementId.personalBest: (scoreImproved ? 1 : 0, unique.length >= 2),
      AchievementId.comeback: (comeback ? 1 : 0, unique.length >= 2),
      AchievementId.regularPlayer: (distinctDays, unique.isNotEmpty),
    };
    return AchievementEvaluation([
      for (final definition in achievementDefinitions)
        PlayerAchievementProgress(
          definition: definition,
          progress: progress[definition.id]!.$1,
          available: progress[definition.id]!.$2,
          unlock: unlockById[definition.id],
        ),
    ]);
  }

  bool _hasValidMeasurement(GameSessionRecord record) =>
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

  bool _hasLaterImprovement(
    List<GameSessionRecord> records,
    double Function(GameSessionRecord) value,
  ) {
    if (records.length < 2) return false;
    var best = value(records.first);
    for (final record in records.skip(1)) {
      final current = value(record);
      if (current > best) return true;
    }
    return false;
  }
}
