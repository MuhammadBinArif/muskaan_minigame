// Repository for game session records.
//
// Handles all data operations for game session persistence including:
// - Saving completed game sessions
// - Loading game history
// - Managing best scores and statistics
// - Handling database errors gracefully

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';

/// Interface for the records repository.
abstract class GameRecordsRepository {
  Future<void> saveSession(GameSessionRecord record);
  Future<List<GameSessionRecord>> getAllSessions();
  Future<GameSessionRecord?> getBestSession();
  Future<GameSessionRecord?> getSessionById(int sessionId);
  Future<void> updateSessionCompletion(GameSessionRecord record);
  Future<void> clearAllSessions();
  Future<List<GameSessionRecord>> getSessionsSince(DateTime date);
  Stream<List<GameSessionRecord>> watchAllSessions();
}

/// Implementation backed by the Drift [GameDatabase].
class GameRecordsRepositoryImpl implements GameRecordsRepository {
  final GameDatabase _database;

  GameRecordsRepositoryImpl(this._database);

  @override
  Future<void> saveSession(GameSessionRecord record) async {
    try {
      await _database.upsertSession(record);
    } catch (e, st) {
      throw GameRepositoryException('Failed to save game session.', e, st);
    }
  }

  @override
  Future<List<GameSessionRecord>> getAllSessions() async {
    try {
      final records = await _database.getCompletedSessions();
      return records.map(_toDomainRecord).toList();
    } catch (e, st) {
      throw GameRepositoryException('Failed to get sessions.', e, st);
    }
  }

  @override
  Future<GameSessionRecord?> getBestSession() async {
    try {
      final record = await _database.getBestSession();
      return record == null ? null : _toDomainRecord(record);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get best session.', e, st);
    }
  }

  @override
  Future<GameSessionRecord?> getSessionById(int sessionId) async {
    try {
      final record = await _database.getSessionById(sessionId);
      return record == null ? null : _toDomainRecord(record);
    } catch (e, st) {
      throw GameRepositoryException('Failed to get session by ID.', e, st);
    }
  }

  @override
  Future<void> updateSessionCompletion(GameSessionRecord record) async {
    try {
      await _database.updateSession(record);
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
      await _database.clearAllSessions();
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
  Stream<List<GameSessionRecord>> watchAllSessions() {
    return _database
        .getAllSessionsStream()
        .map((records) => records.map(_toDomainRecord).toList())
        .handleError((Object error, StackTrace stack) {
          throw GameRepositoryException(
            'Unable to load game history.',
            error,
            stack,
          );
        });
  }

  // ── Private ────────────────────────────────────────────────
  GameSessionRecord _toDomainRecord(GameRecord row) {
    final record = GameSessionRecord(
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

/// Custom exception for repository errors.
class GameRepositoryException implements Exception {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const GameRepositoryException(this.message, this.error, this.stackTrace);

  @override
  String toString() => 'GameRepositoryException: $message';
}
