import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/game_session.dart';
import '../../game/data/records_repository.dart';
import '../data/achievement_repository.dart';
import '../domain/player_achievement.dart';

class AchievementService {
  AchievementService(this.records, this.unlocks);
  final GameRecordsRepository records;
  final AchievementRepository unlocks;
  static const evaluator = AchievementEvaluator();

  Future<List<AchievementUnlock>> evaluatePersistedResult({
    required String playerId,
    required int sourceResultId,
    required DateTime completedAt,
  }) async {
    final sessions = await records.getPlayerSessions(playerId);
    final existing = await unlocks.getUnlocks(playerId);
    final evaluation = evaluator.evaluate(
      playerId: playerId,
      records: sessions,
      unlocks: existing,
    );
    return unlocks.persistEligible(
      playerId: playerId,
      evaluation: evaluation,
      sourceResultId: sourceResultId,
      unlockedAt: completedAt,
    );
  }

  Future<AchievementEvaluation> getProgress(String playerId) async {
    final sessions = await records.getPlayerSessions(playerId);
    final existing = await unlocks.getUnlocks(playerId);
    var evaluation = evaluator.evaluate(
      playerId: playerId,
      records: sessions,
      unlocks: existing,
    );
    final completed =
        sessions
            .where(
              (record) =>
                  record.playerId == playerId &&
                  record.state == GameSessionState.results &&
                  record.endedAt != null,
            )
            .toList()
          ..sort((a, b) => a.endedAt!.compareTo(b.endedAt!));
    if (evaluation.eligibleToUnlock.isNotEmpty && completed.isNotEmpty) {
      final source = completed.last;
      await unlocks.persistEligible(
        playerId: playerId,
        evaluation: evaluation,
        sourceResultId: source.id,
        unlockedAt: source.endedAt!,
      );
      evaluation = evaluator.evaluate(
        playerId: playerId,
        records: sessions,
        unlocks: await unlocks.getUnlocks(playerId),
      );
    }
    return evaluation;
  }
}

final achievementServiceProvider = Provider(
  (ref) => AchievementService(
    ref.watch(gameRecordsRepositoryProvider),
    ref.watch(achievementRepositoryProvider),
  ),
);

final playerAchievementProgressProvider = FutureProvider.autoDispose
    .family<AchievementEvaluation, String>(
      (ref, playerId) =>
          ref.watch(achievementServiceProvider).getProgress(playerId),
    );

final latestAchievementUnlocksProvider = StateProvider<List<AchievementUnlock>>(
  (ref) => const [],
);
