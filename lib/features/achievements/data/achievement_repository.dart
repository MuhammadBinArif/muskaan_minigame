import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/data/game_database.dart';
import '../../game/data/records_repository.dart' show gameDatabaseProvider;
import '../domain/player_achievement.dart';

class AchievementRepository {
  AchievementRepository(this.database);
  final GameDatabase database;

  Future<List<AchievementUnlock>> getUnlocks(String playerId) async {
    _validatePlayerId(playerId);
    final rows =
        await database
            .customSelect(
              'SELECT achievement_id, unlocked_at, source_result_id FROM player_achievements WHERE player_id = ? ORDER BY unlocked_at, achievement_id',
              variables: [Variable<String>(playerId)],
            )
            .get();
    return rows
        .map((row) {
          final id = AchievementId.values.firstWhere(
            (value) => value.name == row.read<String>('achievement_id'),
            orElse:
                () => throw const FormatException('Unknown achievement ID.'),
          );
          return AchievementUnlock(
            playerId: playerId,
            achievementId: id,
            unlockedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('unlocked_at'),
              isUtc: true,
            ),
            sourceResultId: row.read<int>('source_result_id'),
          );
        })
        .toList(growable: false);
  }

  Future<List<AchievementUnlock>> persistEligible({
    required String playerId,
    required AchievementEvaluation evaluation,
    required int sourceResultId,
    required DateTime unlockedAt,
  }) async {
    _validatePlayerId(playerId);
    if (sourceResultId <= 0) {
      throw const FormatException('A persisted source result is required.');
    }
    final newlyUnlocked = <AchievementUnlock>[];
    await database.transaction(() async {
      for (final item in evaluation.eligibleToUnlock) {
        final changed = await database.customUpdate(
          'INSERT OR IGNORE INTO player_achievements(player_id, achievement_id, unlocked_at, source_result_id) VALUES(?, ?, ?, ?)',
          variables: [
            Variable<String>(playerId),
            Variable<String>(item.definition.id.name),
            Variable<int>(unlockedAt.toUtc().millisecondsSinceEpoch),
            Variable<int>(sourceResultId),
          ],
        );
        if (changed == 1) {
          newlyUnlocked.add(
            AchievementUnlock(
              playerId: playerId,
              achievementId: item.definition.id,
              unlockedAt: unlockedAt.toUtc(),
              sourceResultId: sourceResultId,
            ),
          );
        }
      }
    });
    return newlyUnlocked;
  }

  void _validatePlayerId(String playerId) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(playerId)) {
      throw const FormatException('A valid stable player ID is required.');
    }
  }
}

final achievementRepositoryProvider = Provider(
  (ref) => AchievementRepository(ref.watch(gameDatabaseProvider)),
);
