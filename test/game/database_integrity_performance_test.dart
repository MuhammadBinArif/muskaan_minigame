import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

GameSessionRecord completed(int id, String playerId, int score) =>
    GameSessionRecord(
      playerId: playerId,
      playerName: 'Player $playerId',
      playerAvatar: 'avatar-$playerId',
      id: id,
      score: score,
      livesLost: 0,
      maxLives: 3,
      timePlayed: 30,
      bestCombo: 1,
      catches: 1,
      accuracy: 1,
      smileScore: 0,
      startedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
      endedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id + 1)),
      state: GameSessionState.results,
      isNewBest: false,
    );

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  test('new records use game_records as the sole ownership source', () async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = GameRecordsRepositoryImpl(database);
    await repository.saveSession(completed(1, playerA, 100));

    final owner = await database
        .customSelect('SELECT player_id FROM game_records WHERE id = 1')
        .getSingle();
    final columns = await database
        .customSelect('PRAGMA table_info(session_details)')
        .get();
    expect(owner.read<String>('player_id'), playerA);
    expect(
      columns.map((column) => column.read<String>('name')),
      isNot(contains('player_id')),
    );
  });

  test('player history is isolated, ordered, and handles empty results', () async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = GameRecordsRepositoryImpl(database);
    for (var id = 1; id <= 120; id++) {
      await repository.saveSession(
        completed(id, id.isEven ? playerA : playerB, id),
      );
    }
    await database.customStatement(
      "UPDATE session_details SET smile_samples = 'corrupt' WHERE session_id = 1",
    );

    final history = await repository.getPlayerSessions(playerA);
    expect(history, hasLength(60));
    expect(history.every((record) => record.playerId == playerA), isTrue);
    expect(history.first.id, 120);
    expect(history.last.id, 2);
    expect(
      await repository.getPlayerSessions('cccccccccccccccccccccccccccccccc'),
      isEmpty,
    );
  });

  test('history and score queries use their owner indexes', () async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').getSingle();

    final historyPlan = await database
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT id FROM game_records WHERE player_id = ? AND state = ? ORDER BY started_at DESC, id DESC',
          variables: [
            Variable<String>(playerA),
            Variable<int>(SessionState.completed.index),
          ],
        )
        .get();
    final scorePlan = await database
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT MAX(score) FROM game_records WHERE player_id = ? AND state = ? AND ended_at IS NOT NULL',
          variables: [
            Variable<String>(playerA),
            Variable<int>(SessionState.completed.index),
          ],
        )
        .get();
    expect(
      historyPlan.map((row) => row.data.values.join(' ')).join(' '),
      contains('game_records_player_history'),
    );
    expect(
      scorePlan.map((row) => row.data.values.join(' ')).join(' '),
      contains('game_records_player_score'),
    );
  });

  test('v7 migration preserves metadata and nullable ownership', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''CREATE TABLE game_records (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          score INTEGER NOT NULL, lives_lost INTEGER NOT NULL,
          max_lives INTEGER NOT NULL, time_played INTEGER NOT NULL,
          best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
          accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
          started_at INTEGER NOT NULL, ended_at INTEGER, state INTEGER NOT NULL,
          is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
          player_id TEXT)''');
        database.execute('''CREATE TABLE session_details (
          session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE,
          player_id TEXT, display_name TEXT, avatar TEXT,
          smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL,
          smile_peak REAL, calibrated_smile_attempted INTEGER,
          calibrated_smile_samples INTEGER, calibrated_smile_average REAL,
          calibrated_smile_peak REAL, calibrated_smile_span_ms INTEGER,
          used_smile_mode INTEGER, used_touch_mode INTEGER,
          completion_timezone_offset_minutes INTEGER)''');
        database.execute(
          "INSERT INTO game_records VALUES (1, 10, 0, 3, 30, 1, 1, 1.0, 0, 1700000000, 1700000030, 5, 1, '$playerA')",
        );
        database.execute(
          'INSERT INTO game_records VALUES (2, 5, 0, 3, 30, 1, 1, 1.0, 0, 1700000100, 1700000130, 5, 0, NULL)',
        );
        database.execute(
          "INSERT INTO session_details(session_id, player_id, display_name, avatar) VALUES (1, '$playerA', 'Player A', 'avatar-a')",
        );
        database.execute(
          "INSERT INTO session_details(session_id, display_name, avatar) VALUES (2, 'Legacy', 'legacy')",
        );
        database.execute('PRAGMA user_version = 7');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final records = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(database.schemaVersion, 8);
    expect(records.singleWhere((record) => record.id == 1).playerId, playerA);
    expect(
      records.singleWhere((record) => record.id == 1).playerName,
      'Player A',
    );
    expect(records.singleWhere((record) => record.id == 2).playerId, isNull);
    final columns = await database
        .customSelect('PRAGMA table_info(session_details)')
        .get();
    expect(
      columns.map((column) => column.read<String>('name')),
      isNot(contains('player_id')),
    );
    expect(
      (await database.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
  });

  test('failed v7 migration rolls back without advancing schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'muskaan_failed_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/records.sqlite');
    final database = GameDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('''CREATE TABLE game_records (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            score INTEGER NOT NULL, lives_lost INTEGER NOT NULL,
            max_lives INTEGER NOT NULL, time_played INTEGER NOT NULL,
            best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
            accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
            started_at INTEGER NOT NULL, ended_at INTEGER, state INTEGER NOT NULL,
            is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
            player_id TEXT)''');
          // Deliberately lacks columns required by the v8 copy operation.
          raw.execute(
            'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY, display_name TEXT)',
          );
          raw.execute('PRAGMA user_version = 7');
        },
      ),
    );
    await expectLater(
      database.customSelect('SELECT 1').getSingle(),
      throwsA(anything),
    );
    try {
      await database.close();
    } on Object {
      // Opening failed; there may be no initialized Drift connection to close.
    }

    final raw = sqlite.sqlite3.open(file.path);
    addTearDown(raw.dispose);
    expect(raw.select('PRAGMA user_version').single.values.single, 7);
    final tables = raw.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'session_details%' ORDER BY name",
    );
    expect(tables.map((row) => row['name']), ['session_details']);
  });
}
