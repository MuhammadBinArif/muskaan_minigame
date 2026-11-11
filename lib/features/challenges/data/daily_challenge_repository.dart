import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/data/game_database.dart';
import '../../game/data/records_repository.dart' show gameDatabaseProvider;
import '../domain/daily_challenge.dart';

class DailyChallengeRepository {
  DailyChallengeRepository(this.database);
  final GameDatabase database;
  static const generator = DailyChallengeGenerator();

  Future<List<DailyChallengeAssignment>> loadOrCreate({
    required String playerId,
    required DateTime now,
    required bool smileDataAvailable,
  }) async {
    _validatePlayerId(playerId);
    final offset = now.timeZoneOffset.inMinutes;
    final requestedKey = dateKeyFor(now, offset);
    return database.transaction(() async {
      final clock =
          await database
              .customSelect(
                'SELECT latest_date_key FROM player_challenge_clock WHERE player_id = ?',
                variables: [Variable<String>(playerId)],
              )
              .getSingleOrNull();
      final previousKey = clock?.read<String>('latest_date_key');
      final effectiveKey =
          previousKey != null && previousKey.compareTo(requestedKey) > 0
              ? previousKey
              : requestedKey;
      await database.customStatement(
        'INSERT INTO player_challenge_clock(player_id, latest_date_key) VALUES(?, ?) ON CONFLICT(player_id) DO UPDATE SET latest_date_key = CASE WHEN excluded.latest_date_key > latest_date_key THEN excluded.latest_date_key ELSE latest_date_key END',
        [playerId, effectiveKey],
      );
      var assignments = await _load(playerId, effectiveKey);
      if (assignments.isNotEmpty) return assignments;
      final ids = generator.generate(
        playerId: playerId,
        dateKey: effectiveKey,
        smileDataAvailable: smileDataAvailable,
      );
      final assignedAt = now.toUtc();
      for (final id in ids) {
        await database.customStatement(
          'INSERT OR IGNORE INTO daily_challenge_assignments(player_id, date_key, challenge_id, timezone_offset_minutes, assigned_at) VALUES(?, ?, ?, ?, ?)',
          [
            playerId,
            effectiveKey,
            id.name,
            offset,
            assignedAt.millisecondsSinceEpoch,
          ],
        );
      }
      assignments = await _load(playerId, effectiveKey);
      return assignments;
    });
  }

  Future<List<DailyChallengeAssignment>> _load(
    String playerId,
    String dateKey,
  ) async {
    final rows =
        await database
            .customSelect(
              'SELECT challenge_id, timezone_offset_minutes, assigned_at FROM daily_challenge_assignments WHERE player_id = ? AND date_key = ? ORDER BY challenge_id',
              variables: [
                Variable<String>(playerId),
                Variable<String>(dateKey),
              ],
            )
            .get();
    return rows
        .map(
          (row) => DailyChallengeAssignment(
            playerId: playerId,
            dateKey: dateKey,
            challengeId: DailyChallengeId.values.firstWhere(
              (id) => id.name == row.read<String>('challenge_id'),
              orElse:
                  () => throw const FormatException('Unknown daily challenge.'),
            ),
            timezoneOffsetMinutes: row.read<int>('timezone_offset_minutes'),
            assignedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('assigned_at'),
              isUtc: true,
            ),
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

final dailyChallengeRepositoryProvider = Provider(
  (ref) => DailyChallengeRepository(ref.watch(gameDatabaseProvider)),
);
