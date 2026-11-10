import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/game_session.dart';
import '../../game/data/records_repository.dart';
import '../data/daily_challenge_repository.dart';
import '../domain/daily_challenge.dart';

class DailyEngagementState {
  final String dateKey;
  final List<DailyChallengeProgress> challenges;
  final PlayerStreak streak;
  const DailyEngagementState({
    required this.dateKey,
    required this.challenges,
    required this.streak,
  });
}

class DailyChallengeService {
  DailyChallengeService(this.records, this.assignments);
  final GameRecordsRepository records;
  final DailyChallengeRepository assignments;
  static const evaluator = DailyChallengeEvaluator();
  static const streakCalculator = StreakCalculator();

  Future<bool> newlyCompletedByResult({
    required String playerId,
    required GameSessionRecord result,
  }) async {
    final completedAt = result.endedAt;
    if (completedAt == null || result.playerId != playerId) return false;
    final history = await records.getPlayerSessions(playerId);
    final owned = history.where((record) => record.playerId == playerId);
    final daily = await assignments.loadOrCreate(
      playerId: playerId,
      now: completedAt,
      smileDataAvailable: owned.any(hasValidSmileMeasurement),
    );
    final before = evaluator.evaluate(
      playerId: playerId,
      assignments: daily,
      records: history.where((record) => record.id != result.id),
    );
    final after = evaluator.evaluate(
      playerId: playerId,
      assignments: daily,
      records: history,
    );
    final completedBefore =
        before
            .where((item) => item.isComplete)
            .map((item) => item.definition.id)
            .toSet();
    return after.any(
      (item) =>
          item.isComplete && !completedBefore.contains(item.definition.id),
    );
  }

  Future<DailyEngagementState> load(String playerId, {DateTime? now}) async {
    final instant = now ?? DateTime.now();
    final history = await records.getPlayerSessions(playerId);
    final owned =
        history.where((record) => record.playerId == playerId).toList();
    final daily = await assignments.loadOrCreate(
      playerId: playerId,
      now: instant,
      smileDataAvailable: owned.any(hasValidSmileMeasurement),
    );
    final key =
        daily.isEmpty
            ? dateKeyFor(instant, instant.timeZoneOffset.inMinutes)
            : daily.first.dateKey;
    return DailyEngagementState(
      dateKey: key,
      challenges: evaluator.evaluate(
        playerId: playerId,
        assignments: daily,
        records: history,
      ),
      streak: streakCalculator.calculate(
        playerId: playerId,
        records: history,
        effectiveTodayKey: key,
      ),
    );
  }
}

final dailyChallengeServiceProvider = Provider(
  (ref) => DailyChallengeService(
    ref.watch(gameRecordsRepositoryProvider),
    ref.watch(dailyChallengeRepositoryProvider),
  ),
);

final dailyEngagementProvider = FutureProvider.autoDispose.family<
  DailyEngagementState,
  String
>((ref, playerId) => ref.watch(dailyChallengeServiceProvider).load(playerId));
