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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

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

  Future<void> upsertSession(GameSessionRecord record) async {
    await into(gameRecords).insertOnConflictUpdate(record.toCompanion());
  }

  Future<void> deleteSession(int sessionId) {
    return (delete(gameRecords)..where((t) => t.id.equals(sessionId))).go();
  }

  Future<void> clearAllSessions() => delete(gameRecords).go();

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
