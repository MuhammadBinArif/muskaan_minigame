import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/data/game_database.dart';
import '../../game/data/records_repository.dart' show gameDatabaseProvider;
import '../domain/player_progression.dart';

class ProgressionRepository {
  ProgressionRepository(this.database);
  final GameDatabase database;

  Future<void> awardResult(ProgressionAward award) async {
    _validatePlayerId(award.playerId);
    if (award.resultId <= 0 || award.xp < 100 || award.xp > 200) {
      throw const FormatException('Invalid progression award.');
    }
    await database.customStatement(
      'INSERT OR IGNORE INTO player_progression_awards(player_id, result_id, xp, awarded_at) VALUES(?, ?, ?, ?)',
      [
        award.playerId,
        award.resultId,
        award.xp,
        award.awardedAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<ProgressionAward>> getAwards(String playerId) async {
    _validatePlayerId(playerId);
    final rows =
        await database
            .customSelect(
              'SELECT result_id, xp, awarded_at FROM player_progression_awards WHERE player_id = ? ORDER BY awarded_at, result_id',
              variables: [Variable<String>(playerId)],
            )
            .get();
    return rows
        .map(
          (row) => ProgressionAward(
            playerId: playerId,
            resultId: row.read<int>('result_id'),
            xp: row.read<int>('xp'),
            awardedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('awarded_at'),
              isUtc: true,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> unlock(CosmeticUnlock unlock) async {
    _validatePlayerId(unlock.playerId);
    await database.customStatement(
      'INSERT OR IGNORE INTO player_cosmetic_unlocks(player_id, cosmetic_id, unlocked_at, source) VALUES(?, ?, ?, ?)',
      [
        unlock.playerId,
        unlock.cosmeticId,
        unlock.unlockedAt.toUtc().millisecondsSinceEpoch,
        unlock.source,
      ],
    );
  }

  Future<List<CosmeticUnlock>> getUnlocks(String playerId) async {
    _validatePlayerId(playerId);
    final rows =
        await database
            .customSelect(
              'SELECT cosmetic_id, unlocked_at, source FROM player_cosmetic_unlocks WHERE player_id = ? ORDER BY unlocked_at DESC, cosmetic_id',
              variables: [Variable<String>(playerId)],
            )
            .get();
    return rows
        .map(
          (row) => CosmeticUnlock(
            playerId: playerId,
            cosmeticId: row.read<String>('cosmetic_id'),
            unlockedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('unlocked_at'),
              isUtc: true,
            ),
            source: row.read<String>('source'),
          ),
        )
        .toList(growable: false);
  }

  void _validatePlayerId(String playerId) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(playerId)) {
      throw const FormatException('A valid stable player ID is required.');
    }
  }
}

final progressionRepositoryProvider = Provider(
  (ref) => ProgressionRepository(ref.watch(gameDatabaseProvider)),
);
