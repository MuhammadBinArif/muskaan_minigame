// Drift database for game records.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:muskaan_minigame/core/domain/game_session.dart';

part 'game_database.g.dart';

// ============================================================
// TABLE
// ============================================================
class GameRecords extends Table {
  @override
  String get tableName => 'game_records';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get score => integer()();
  IntColumn get livesLost => integer().named('lives_lost')();
  IntColumn get maxLives => integer().named('max_lives')();
  IntColumn get timePlayed => integer().named('time_played')();
  IntColumn get bestCombo => integer().named('best_combo')();
  IntColumn get catches => integer()();
  RealColumn get accuracy => real()();
  IntColumn get smileScore => integer().named('smile_score')();
  DateTimeColumn get startedAt => dateTime().named('started_at')();
  DateTimeColumn get endedAt => dateTime().named('ended_at').nullable()();
  IntColumn get state => integer()();
  BoolColumn get isNewBest => boolean().named('is_new_best')();
}

// ============================================================
// DATABASE
// ============================================================
@DriftDatabase(tables: [GameRecords])
class GameDatabase extends _$GameDatabase {
  /// Production constructor — opens the on-disk database.
  GameDatabase() : super(_openConnection());

  /// Test / DI constructor — accepts any [QueryExecutor].
  ///
  /// In tests, pass `NativeDatabase.memory()`:
  /// ```dart
  /// final db = GameDatabase.forTesting(NativeDatabase.memory());
  /// ```
  GameDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIdentityTables();
      await _addResultOwnershipColumn(copyVersionTwoOwnership: false);
      await _createAchievementTable();
      await _createDailyChallengeTables();
      await _createProgressionTables();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await _createIdentityTables();
      if (from < 3) {
        await _addResultOwnershipColumn(copyVersionTwoOwnership: from == 2);
      }
      if (from >= 2 && from < 4) await _addCalibratedSmileColumns();
      if (from < 5) await _createAchievementTable();
      if (from < 6) {
        if (from >= 2) await _addEngagementResultColumns();
        await _createDailyChallengeTables();
      }
      if (from < 7) await _createProgressionTables();
    },
  );

  Future<void> _createIdentityTables() async {
    await customStatement(
      'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL, calibrated_smile_attempted INTEGER, calibrated_smile_samples INTEGER, calibrated_smile_average REAL, calibrated_smile_peak REAL, calibrated_smile_span_ms INTEGER, used_smile_mode INTEGER, used_touch_mode INTEGER, completion_timezone_offset_minutes INTEGER)',
    );
  }

  Future<void> _addCalibratedSmileColumns() async {
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN calibrated_smile_attempted INTEGER',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN calibrated_smile_samples INTEGER',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN calibrated_smile_average REAL',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN calibrated_smile_peak REAL',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN calibrated_smile_span_ms INTEGER',
    );
  }

  Future<void> _createAchievementTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS player_achievements (player_id TEXT NOT NULL, achievement_id TEXT NOT NULL, unlocked_at INTEGER NOT NULL, source_result_id INTEGER NOT NULL REFERENCES game_records(id) ON DELETE CASCADE, PRIMARY KEY(player_id, achievement_id))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS player_achievements_owner ON player_achievements(player_id, unlocked_at)',
    );
  }

  Future<void> _addEngagementResultColumns() async {
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN used_smile_mode INTEGER',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN used_touch_mode INTEGER',
    );
    await customStatement(
      'ALTER TABLE session_details ADD COLUMN completion_timezone_offset_minutes INTEGER',
    );
  }

  Future<void> _createDailyChallengeTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS daily_challenge_assignments (player_id TEXT NOT NULL, date_key TEXT NOT NULL, challenge_id TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL, assigned_at INTEGER NOT NULL, PRIMARY KEY(player_id, date_key, challenge_id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS player_challenge_clock (player_id TEXT PRIMARY KEY, latest_date_key TEXT NOT NULL)',
    );
  }

  Future<void> _createProgressionTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS player_progression_awards (player_id TEXT NOT NULL, result_id INTEGER NOT NULL REFERENCES game_records(id) ON DELETE CASCADE, xp INTEGER NOT NULL CHECK(xp >= 0), awarded_at INTEGER NOT NULL, PRIMARY KEY(player_id, result_id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS player_cosmetic_unlocks (player_id TEXT NOT NULL, cosmetic_id TEXT NOT NULL, unlocked_at INTEGER NOT NULL, source TEXT NOT NULL, PRIMARY KEY(player_id, cosmetic_id))',
    );
  }

  Future<void> _addResultOwnershipColumn({
    required bool copyVersionTwoOwnership,
  }) async {
    await customStatement('ALTER TABLE game_records ADD COLUMN player_id TEXT');
    if (copyVersionTwoOwnership) {
      await customStatement(
        'UPDATE game_records SET player_id = (SELECT player_id FROM session_details WHERE session_id = game_records.id) WHERE EXISTS (SELECT 1 FROM session_details WHERE session_id = game_records.id AND player_id IS NOT NULL)',
      );
    }
  }

  // ── Reads ──────────────────────────────────────────────────
  Stream<List<GameRecord>> getAllSessionsStream() =>
      (select(gameRecords)
            ..where(
              (t) => t.state.isIn([
                SessionState.completed.index,
                SessionState.gameOver.index,
              ]),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  Future<List<GameRecord>> getCompletedSessions() {
    return (select(gameRecords)
          ..where(
            (t) => t.state.isIn([
              SessionState.completed.index,
              SessionState.gameOver.index,
            ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<GameRecord?> getSessionById(int sessionId) {
    return (select(gameRecords)
      ..where((t) => t.id.equals(sessionId))).getSingleOrNull();
  }

  Future<GameRecord?> getBestSession() {
    return (select(gameRecords)
          ..where(
            (t) => t.state.isIn([
              SessionState.completed.index,
              SessionState.gameOver.index,
            ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.score)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ── Writes ─────────────────────────────────────────────────
  Future<int> insertSession(GameSessionRecord record) =>
      into(gameRecords).insert(record.toCompanion());

  Future<void> updateSession(GameSessionRecord record) {
    return (update(gameRecords)
      ..where((t) => t.id.equals(record.id))).write(record.toCompanion());
  }

  Future<int> upsertSession(GameSessionRecord record) =>
      into(gameRecords).insertOnConflictUpdate(record.toCompanion());

  Future<void> deleteSession(int sessionId) => transaction(() async {
    await customStatement('DELETE FROM session_details WHERE session_id = ?', [
      sessionId,
    ]);
    await (delete(gameRecords)..where((t) => t.id.equals(sessionId))).go();
  });

  Future<void> clearAllSessions() => transaction(() async {
    await customStatement('DELETE FROM session_details');
    await delete(gameRecords).go();
  });

  /// Closes the underlying database connection.
  ///
  /// Call this when the app tears down or when the Riverpod provider
  /// that owns this instance is disposed.
  @override
  Future<void> close() => super.close();
}

// ============================================================
// CONNECTION
// ============================================================
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'muskaan_minigame_game_records.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

// ============================================================
// ENUM BRIDGE — GameSessionState ↔ Drift SessionState
// ============================================================
enum SessionState { ready, preparing, playing, paused, gameOver, completed }

extension GameSessionStateDriftX on GameSessionState {
  SessionState toDrift() {
    switch (this) {
      case GameSessionState.ready:
        return SessionState.ready;
      case GameSessionState.preparing:
        return SessionState.preparing;
      case GameSessionState.playing:
        return SessionState.playing;
      case GameSessionState.paused:
        return SessionState.paused;
      case GameSessionState.gameOver:
        return SessionState.gameOver;
      case GameSessionState.results:
        return SessionState.completed;
    }
  }
}

extension SessionStateDomainX on SessionState {
  GameSessionState toDomain() {
    switch (this) {
      case SessionState.ready:
        return GameSessionState.ready;
      case SessionState.preparing:
        return GameSessionState.preparing;
      case SessionState.playing:
        return GameSessionState.playing;
      case SessionState.paused:
        return GameSessionState.paused;
      case SessionState.gameOver:
        return GameSessionState.gameOver;
      case SessionState.completed:
        return GameSessionState.results;
    }
  }
}

// ============================================================
// DTO MAPPER — GameSessionRecord → Drift companion
// (Lives here, not in game_session.dart, to avoid the cycle.)
// ============================================================
extension GameSessionRecordMapper on GameSessionRecord {
  GameRecordsCompanion toCompanion() {
    validate();
    return GameRecordsCompanion(
      // 0 = "not yet persisted" → let Drift assign the auto-increment id.
      id: id == 0 ? const Value.absent() : Value(id),
      score: Value(score),
      livesLost: Value(livesLost),
      maxLives: Value(maxLives),
      timePlayed: Value(timePlayed),
      bestCombo: Value(bestCombo),
      catches: Value(catches),
      accuracy: Value(accuracy),
      smileScore: Value(smileScore),
      // DateTimeColumn accepts a raw DateTime; Drift handles encoding.
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      state: Value(state.toDrift().index),
      isNewBest: Value(isNewBest),
    );
  }
}
