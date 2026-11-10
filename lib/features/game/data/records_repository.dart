// Repository for game session records.
//
// Handles all data operations for game session persistence including:
// - Saving completed game sessions
// - Loading game history
// - Managing best scores and statistics
// - Handling database errors gracefully

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/smile/domain/player_smile_analytics.dart';

enum SmileHistoryOrder { newestFirst, oldestFirst }

/// Interface for the records repository.
abstract class GameRecordsRepository {
  Future<GameSessionRecord> saveSession(GameSessionRecord record);
  Future<List<GameSessionRecord>> getAllSessions();
  Future<List<GameSessionRecord>> getPlayerSessions(String playerId);
  Future<GameSessionRecord?> getBestSession();
  Future<GameSessionRecord?> getSessionById(int sessionId);
  Future<GameSessionRecord> updateSessionCompletion(GameSessionRecord record);
  Future<void> clearAllSessions();
  Future<List<GameSessionRecord>> getSessionsSince(DateTime date);
  Future<List<HistoricalSmileRound>> getPlayerSmileHistory({
    required String playerId,
    int limit = 50,
    int offset = 0,
    DateTime? completedFrom,
    DateTime? completedThrough,
    SmileHistoryOrder order = SmileHistoryOrder.newestFirst,
  });
  Stream<List<GameSessionRecord>> watchAllSessions();
}

/// Implementation backed by the Drift [GameDatabase].
class GameRecordsRepositoryImpl implements GameRecordsRepository {
  final GameDatabase _database;

  GameRecordsRepositoryImpl(this._database);

  @override
  Future<GameSessionRecord> saveSession(GameSessionRecord record) async {
    try {
      if (record.playerId == null ||
          record.playerName == null ||
          record.playerAvatar == null) {
        throw const FormatException(
          'Newly persisted results require player ownership.',
        );
      }
      return await _database.transaction(() async {
        // The app has one score board: a round may use Smile, Touch, or both.
        final eligible =
            record.state == GameSessionState.results && record.endedAt != null;
        final existing =
            record.id == 0
                ? null
                : await _database
                    .customSelect(
                      'SELECT is_new_best FROM game_records WHERE id = ?',
                      variables: [Variable<int>(record.id)],
                    )
                    .getSingleOrNull();
        final previousBest =
            eligible && existing == null
                ? (await _database
                        .customSelect(
                          'SELECT MAX(score) AS best FROM game_records WHERE player_id = ? AND id != ? AND state = ? AND ended_at IS NOT NULL',
                          variables: [
                            Variable<String>(record.playerId!),
                            Variable<int>(record.id),
                            Variable<int>(SessionState.completed.index),
                          ],
                        )
                        .getSingle())
                    .readNullable<int>('best')
                : null;
        final canonical = record.persisted(
          id: record.id,
          isNewBest:
              existing?.read<bool>('is_new_best') ??
              (eligible &&
                  (previousBest == null || record.score > previousBest)),
        );
        final insertedId = await _database.upsertSession(canonical);
        final resultId = record.id == 0 ? insertedId : record.id;
        await _database.customStatement(
          'UPDATE game_records SET player_id = ? WHERE id = ?',
          [canonical.playerId, resultId],
        );
        await _database.customStatement(
          'INSERT INTO session_details(session_id, display_name, avatar, smile_samples, smile_average, smile_peak, calibrated_smile_attempted, calibrated_smile_samples, calibrated_smile_average, calibrated_smile_peak, calibrated_smile_span_ms, used_smile_mode, used_touch_mode, completion_timezone_offset_minutes) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(session_id) DO UPDATE SET display_name=excluded.display_name, avatar=excluded.avatar, smile_samples=excluded.smile_samples, smile_average=excluded.smile_average, smile_peak=excluded.smile_peak, calibrated_smile_attempted=excluded.calibrated_smile_attempted, calibrated_smile_samples=excluded.calibrated_smile_samples, calibrated_smile_average=excluded.calibrated_smile_average, calibrated_smile_peak=excluded.calibrated_smile_peak, calibrated_smile_span_ms=excluded.calibrated_smile_span_ms, used_smile_mode=excluded.used_smile_mode, used_touch_mode=excluded.used_touch_mode, completion_timezone_offset_minutes=excluded.completion_timezone_offset_minutes',
          [
            resultId,
            canonical.playerName,
            canonical.playerAvatar,
            canonical.smileSampleCount,
            canonical.averageSmileProbability,
            canonical.peakSmileProbability,
            canonical.calibratedSmileAttempted == null
                ? null
                : canonical.calibratedSmileAttempted!
                ? 1
                : 0,
            canonical.calibratedSmileSampleCount,
            canonical.averageCalibratedSmileIntensity,
            canonical.peakCalibratedSmileIntensity,
            canonical.calibratedSmileObservationSpanMs,
            canonical.usedSmileMode == null
                ? null
                : canonical.usedSmileMode!
                ? 1
                : 0,
            canonical.usedTouchMode == null
                ? null
                : canonical.usedTouchMode!
                ? 1
                : 0,
            canonical.completionTimezoneOffsetMinutes,
          ],
        );
        return canonical.persisted(id: resultId, isNewBest: canonical.isNewBest);
      });
    } catch (e, st) {
      throw GameRepositoryException('Failed to save game session.', e, st);
    }
  }

  @override
  Future<List<GameSessionRecord>> getAllSessions() async {
    try {
      final records = await _database.getCompletedSessions();
      return await _toDomainRecords(records);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get sessions.', e, st);
    }
  }

  @override
  Future<List<GameSessionRecord>> getPlayerSessions(String playerId) async {
    _validatePlayerId(playerId);
    try {
      final owned =
          await _database
              .customSelect(
                'SELECT id FROM game_records WHERE player_id = ? AND state IN (?, ?) ORDER BY started_at DESC',
                variables: [
                  Variable<String>(playerId),
                  Variable<int>(SessionState.completed.index),
                  Variable<int>(SessionState.gameOver.index),
                ],
              )
              .get();
      final rows = await _database.getCompletedSessionsByIds(
        owned.map((row) => row.read<int>('id')).toList(growable: false),
      );
      return _toDomainRecords(rows, knownPlayerId: playerId);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get player sessions.', e, st);
    }
  }

  @override
  Future<GameSessionRecord?> getBestSession() async {
    try {
      final record = await _database.getBestSession();
      return record == null ? null : await _toDomainRecord(record);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get best session.', e, st);
    }
  }

  @override
  Future<GameSessionRecord?> getSessionById(int sessionId) async {
    try {
      final record = await _database.getSessionById(sessionId);
      return record == null ? null : await _toDomainRecord(record);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get session by ID.', e, st);
    }
  }

  @override
  Future<GameSessionRecord> updateSessionCompletion(
    GameSessionRecord record,
  ) async {
    try {
      return await saveSession(record);
    } catch (e, st) {
      throw GameRepositoryException(
        'Failed to update session completion.',
        e,
        st,
      );
    }
  }

  @override
  Future<void> clearAllSessions() async {
    try {
      await _database.transaction(() async {
        await _database.customStatement('DELETE FROM session_details');
        await _database.clearAllSessions();
      });
    } catch (e, st) {
      throw GameRepositoryException('Failed to clear sessions.', e, st);
    }
  }

  @override
  Future<List<GameSessionRecord>> getSessionsSince(DateTime date) async {
    try {
      final all = await getAllSessions();
      return all.where((s) => s.startedAt.isAfter(date)).toList();
    } catch (e, st) {
      throw GameRepositoryException(
        'Failed to get sessions since date.',
        e,
        st,
      );
    }
  }

  @override
  Future<List<HistoricalSmileRound>> getPlayerSmileHistory({
    required String playerId,
    int limit = 50,
    int offset = 0,
    DateTime? completedFrom,
    DateTime? completedThrough,
    SmileHistoryOrder order = SmileHistoryOrder.newestFirst,
  }) async {
    _validatePlayerId(playerId);
    if (limit < 1 || limit > 100 || offset < 0) {
      throw RangeError('History limit must be 1–100 and offset non-negative.');
    }
    if (completedFrom != null &&
        completedThrough != null &&
        completedFrom.isAfter(completedThrough)) {
      throw const FormatException('Invalid completion date range.');
    }
    try {
      final conditions = <String>[
        'r.player_id = ?',
        'r.state = ?',
        'r.ended_at IS NOT NULL',
        'd.calibrated_smile_attempted = 1',
        'd.calibrated_smile_samples > 0',
        'd.calibrated_smile_average IS NOT NULL',
        'd.calibrated_smile_peak IS NOT NULL',
        'd.calibrated_smile_span_ms IS NOT NULL',
      ];
      final variables = <Variable<Object>>[
        Variable<String>(playerId),
        Variable<int>(SessionState.completed.index),
      ];
      if (completedFrom != null) {
        conditions.add('r.ended_at >= ?');
        variables.add(Variable<DateTime>(completedFrom));
      }
      if (completedThrough != null) {
        conditions.add('r.ended_at <= ?');
        variables.add(Variable<DateTime>(completedThrough));
      }
      variables
        ..add(Variable<int>(limit))
        ..add(Variable<int>(offset));
      final direction = order == SmileHistoryOrder.newestFirst ? 'DESC' : 'ASC';
      final rows =
          await _database
              .customSelect(
                'SELECT r.id, r.player_id, r.ended_at, d.calibrated_smile_samples, d.calibrated_smile_average, d.calibrated_smile_peak, d.calibrated_smile_span_ms FROM game_records r INNER JOIN session_details d ON d.session_id = r.id WHERE ${conditions.join(' AND ')} ORDER BY r.ended_at $direction, r.id $direction LIMIT ? OFFSET ?',
                variables: variables,
              )
              .get();
      return rows
          .map((row) {
            final round = HistoricalSmileRound(
              resultId: row.read<int>('id'),
              playerId: row.read<String>('player_id'),
              averageIntensity: row.read<double>('calibrated_smile_average'),
              peakIntensity: row.read<double>('calibrated_smile_peak'),
              validObservationCount: row.read<int>('calibrated_smile_samples'),
              observedSpan: Duration(
                milliseconds: row.read<int>('calibrated_smile_span_ms'),
              ),
              completedAt: row.read<DateTime>('ended_at'),
            );
            if (!round.isValid) {
              throw const FormatException(
                'Invalid persisted smile measurement.',
              );
            }
            return round;
          })
          .toList(growable: false);
    } catch (e, st) {
      if (e is FormatException || e is RangeError) rethrow;
      throw GameRepositoryException(
        'Failed to get player smile history.',
        e,
        st,
      );
    }
  }

  @override
  Stream<List<GameSessionRecord>> watchAllSessions() {
    return _database
        .getAllSessionsStream()
        .asyncMap(_toDomainRecords)
        .handleError((Object error, StackTrace stack) {
          throw GameRepositoryException(
            'Unable to load game history.',
            error,
            stack,
          );
        });
  }

  // ── Private ────────────────────────────────────────────────
  Future<List<GameSessionRecord>> _toDomainRecords(
    List<GameRecord> rows, {
    String? knownPlayerId,
  }) async {
    if (rows.isEmpty) return [];
    final placeholders = List.filled(rows.length, '?').join(', ');
    final idVariables = rows.map((row) => Variable<int>(row.id)).toList();
    final details =
        await _database
            .customSelect(
              'SELECT * FROM session_details WHERE session_id IN ($placeholders)',
              variables: idVariables,
            )
            .get();
    final ownership =
        knownPlayerId == null
            ? await _database
                .customSelect(
                  'SELECT id, player_id FROM game_records WHERE id IN ($placeholders)',
                  variables: idVariables,
                )
                .get()
            : const <QueryRow>[];
    final byId = {
      for (final detail in details) detail.read<int>('session_id'): detail,
    };
    final ownerById = {
      for (final row in ownership)
        row.read<int>('id'): row.readNullable<String>('player_id'),
    };
    return Future.wait(
      rows.map(
        (row) => _toDomainRecord(
          row,
          metadata: byId[row.id],
          playerId: knownPlayerId ?? ownerById[row.id],
          fetchMetadata: false,
        ),
      ),
    );
  }

  void _validatePlayerId(String playerId) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(playerId)) {
      throw const FormatException('A valid stable player ID is required.');
    }
  }

  Future<GameSessionRecord> _toDomainRecord(
    GameRecord row, {
    QueryRow? metadata,
    String? playerId,
    bool fetchMetadata = true,
  }) async {
    final details =
        fetchMetadata
            ? await _database
                .customSelect(
                  'SELECT * FROM session_details WHERE session_id = ?',
                  variables: [Variable.withInt(row.id)],
                )
                .getSingleOrNull()
            : metadata;
    final owner =
        fetchMetadata
            ? await _database
                .customSelect(
                  'SELECT player_id FROM game_records WHERE id = ?',
                  variables: [Variable.withInt(row.id)],
                )
                .getSingleOrNull()
            : null;
    final record = GameSessionRecord(
      playerId:
          fetchMetadata ? owner?.readNullable<String>('player_id') : playerId,
      playerName: details?.readNullable<String>('display_name'),
      playerAvatar: details?.readNullable<String>('avatar'),
      smileSampleCount: details?.read<int>('smile_samples') ?? 0,
      averageSmileProbability: details?.readNullable<double>('smile_average'),
      peakSmileProbability: details?.readNullable<double>('smile_peak'),
      calibratedSmileAttempted:
          details?.readNullable<int>('calibrated_smile_attempted') == null
              ? null
              : details!.read<int>('calibrated_smile_attempted') == 1,
      calibratedSmileSampleCount: details?.readNullable<int>(
        'calibrated_smile_samples',
      ),
      averageCalibratedSmileIntensity: details?.readNullable<double>(
        'calibrated_smile_average',
      ),
      peakCalibratedSmileIntensity: details?.readNullable<double>(
        'calibrated_smile_peak',
      ),
      calibratedSmileObservationSpanMs: details?.readNullable<int>(
        'calibrated_smile_span_ms',
      ),
      usedSmileMode:
          details?.readNullable<int>('used_smile_mode') == null
              ? null
              : details!.read<int>('used_smile_mode') == 1,
      usedTouchMode:
          details?.readNullable<int>('used_touch_mode') == null
              ? null
              : details!.read<int>('used_touch_mode') == 1,
      completionTimezoneOffsetMinutes: details?.readNullable<int>(
        'completion_timezone_offset_minutes',
      ),
      id: row.id,
      score: row.score,
      livesLost: row.livesLost,
      maxLives: row.maxLives,
      timePlayed: row.timePlayed,
      bestCombo: row.bestCombo,
      catches: row.catches,
      accuracy: row.accuracy,
      smileScore: row.smileScore,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      state: _stateFromInt(row.state),
      isNewBest: row.isNewBest,
    );
    record.validate();
    return record;
  }

  GameSessionState _stateFromInt(int raw) {
    if (raw < 0 || raw >= SessionState.values.length) {
      throw const FormatException('Invalid game session state.');
    }
    return SessionState.values[raw].toDomain();
  }
}

// ============================================================
// PROVIDERS
// ============================================================
/// The database is disposed when the provider is disposed.
final gameDatabaseProvider = Provider<GameDatabase>((ref) {
  final database = GameDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Provider for the [GameRecordsRepository].
final gameRecordsRepositoryProvider = Provider<GameRecordsRepository>((ref) {
  final database = ref.watch(gameDatabaseProvider);
  return GameRecordsRepositoryImpl(database);
});

/// Stream provider for all completed game sessions.
final allRecordsStreamProvider =
    StreamProvider.autoDispose<List<GameSessionRecord>>((ref) {
      final repo = ref.watch(gameRecordsRepositoryProvider);
      return repo.watchAllSessions();
    });

/// Stream provider for the best game session.
final bestRecordStreamProvider = StreamProvider.autoDispose<GameSessionRecord?>(
  (ref) {
    final repo = ref.watch(gameRecordsRepositoryProvider);
    return repo.watchAllSessions().map((sessions) {
      if (sessions.isEmpty) return null;
      return sessions.reduce(
        (curr, next) => curr.score >= next.score ? curr : next,
      );
    });
  },
);

/// Future provider for the best record (useful for one-shot reads).
final bestRecordFutureProvider = FutureProvider.autoDispose<GameSessionRecord?>(
  (ref) {
    final repo = ref.watch(gameRecordsRepositoryProvider);
    return repo.getBestSession();
  },
);

final resultByIdProvider = FutureProvider.autoDispose
    .family<GameSessionRecord?, int>(
      (ref, resultId) =>
          ref.watch(gameRecordsRepositoryProvider).getSessionById(resultId),
    );

/// Custom exception for repository errors.
class GameRepositoryException implements Exception {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const GameRepositoryException(this.message, this.error, this.stackTrace);

  @override
  String toString() => 'GameRepositoryException: $message';
}
