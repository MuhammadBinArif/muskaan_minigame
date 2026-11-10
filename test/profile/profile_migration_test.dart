import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux)
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
  });
  test(
    'v1 migration preserves history without assigning it to the new identity',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute(
            '''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)))''',
          );
          database.execute(
            'INSERT INTO game_records VALUES (7, 100, 0, 3, 30, 1, 1, 1.0, 92, 1700000000, 1700000030, 5, 0)',
          );
          database.execute('PRAGMA user_version = 1');
        },
      );
      final database = GameDatabase.forTesting(executor);
      addTearDown(database.close);
      final profile = await PlayerProfileRepository(database).loadOrCreate();
      final history =
          await GameRecordsRepositoryImpl(database).getAllSessions();
      expect(history.single.id, 7);
      expect(history.single.score, 100);
      expect(history.single.smileScore, 92);
      expect(history.single.playerId, isNull);
      expect(history.single.averageSmileProbability, isNull);
      expect(history.single.averageCalibratedSmileIntensity, isNull);
      expect(history.single.calibratedSmileAttempted, isNull);
      expect(profile.id, isNotEmpty);
      expect(database.schemaVersion, 8);
    },
  );
  test('v2 migration adds nullable result ownership without changing history', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute(
          '''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)))''',
        );
        database.execute(
          'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
        );
        database.execute(
          'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL)',
        );
        database.execute(
          'INSERT INTO game_records VALUES (7, 100, 0, 3, 30, 1, 1, 1.0, 0, 1700000000, 1700000030, 5, 0)',
        );
        database.execute(
          'INSERT INTO game_records VALUES (8, 250, 0, 3, 40, 2, 3, 0.8, 0, 1700000100, 1700000140, 5, 1)',
        );
        database.execute(
          "INSERT INTO session_details(session_id, player_id, display_name, avatar) VALUES (8, '0123456789abcdef0123456789abcdef', 'Happy Panda', '🥷')",
        );
        database.execute('PRAGMA user_version = 2');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final history = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(history.map((row) => row.id), containsAll(<int>[7, 8]));
    expect(history.singleWhere((row) => row.id == 7).playerId, isNull);
    expect(
      history.singleWhere((row) => row.id == 8).playerId,
      '0123456789abcdef0123456789abcdef',
    );
    expect(history.singleWhere((row) => row.id == 7).score, 100);
    expect(history.singleWhere((row) => row.id == 8).score, 250);
    expect(
      history.singleWhere((row) => row.id == 8).state,
      GameSessionState.results,
    );
    final integrity =
        await database.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.data.values.single, 'ok');
    expect(database.schemaVersion, 8);
  });
  test(
    'schema v2 restores names and avatars across a real connection restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'muskaan_profile_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/records.sqlite');
      final first = GameDatabase.forTesting(NativeDatabase(file));
      final original = await PlayerProfileRepository(first).loadOrCreate();
      await PlayerProfileRepository(
        first,
      ).save(original.copyWith(displayName: 'Smile King', avatar: '👩🏽'));
      await first.close();
      final second = GameDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      final restored = await PlayerProfileRepository(second).loadOrCreate();
      expect(restored.id, original.id);
      expect(restored.displayName, 'Smile King');
      expect(restored.avatar, '👩🏽');
    },
  );
  test('v3 to v8 migration preserves history and adds later storage', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
        player_id TEXT)''');
        database.execute(
          'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
        );
        database.execute(
          'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL)',
        );
        database.execute(
          'INSERT INTO game_records VALUES (9, 321, 1, 3, 20, 2, 3, 0.75, 44, 1700000200, 1700000220, 5, 1, NULL)',
        );
        database.execute(
          'INSERT INTO session_details(session_id, smile_samples, smile_average, smile_peak) VALUES (9, 2, 0.4, 0.7)',
        );
        database.execute('PRAGMA user_version = 3');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final history = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(history, hasLength(1));
    expect(history.single.id, 9);
    expect(history.single.score, 321);
    expect(history.single.smileScore, 44);
    expect(history.single.averageSmileProbability, .4);
    expect(history.single.calibratedSmileAttempted, isNull);
    expect(history.single.calibratedSmileSampleCount, isNull);
    expect(history.single.averageCalibratedSmileIntensity, isNull);
    expect(history.single.peakCalibratedSmileIntensity, isNull);
    expect(database.schemaVersion, 8);
    final achievementTable =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='player_achievements'",
            )
            .get();
    expect(achievementTable, hasLength(1));
    final integrity =
        await database.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.data.values.single, 'ok');
  });

  test('v4 to v8 migration preserves results and adds local progress tables', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
        player_id TEXT)''');
        database.execute(
          'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
        );
        database.execute(
          'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL, calibrated_smile_attempted INTEGER, calibrated_smile_samples INTEGER, calibrated_smile_average REAL, calibrated_smile_peak REAL, calibrated_smile_span_ms INTEGER)',
        );
        database.execute(
          "INSERT INTO game_records VALUES (12, 700, 0, 3, 20, 2, 4, 1.0, 0, 1700000200, 1700000220, 5, 0, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')",
        );
        database.execute(
          "INSERT INTO session_details(session_id, display_name, avatar) VALUES (12, 'Player A', 'avatar-a')",
        );
        database.execute('PRAGMA user_version = 4');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final history = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(history.single.id, 12);
    expect(history.single.playerId, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    final table =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='player_achievements'",
            )
            .get();
    expect(table, hasLength(1));
    final integrity =
        await database.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.data.values.single, 'ok');
  });

  test('v5 to v8 migration preserves unlocks and adds later features', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
        player_id TEXT)''');
        database.execute(
          'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
        );
        database.execute(
          'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL, calibrated_smile_attempted INTEGER, calibrated_smile_samples INTEGER, calibrated_smile_average REAL, calibrated_smile_peak REAL, calibrated_smile_span_ms INTEGER)',
        );
        database.execute(
          'CREATE TABLE player_achievements (player_id TEXT NOT NULL, achievement_id TEXT NOT NULL, unlocked_at INTEGER NOT NULL, source_result_id INTEGER NOT NULL REFERENCES game_records(id) ON DELETE CASCADE, PRIMARY KEY(player_id, achievement_id))',
        );
        database.execute(
          "INSERT INTO game_records VALUES (14, 800, 0, 3, 20, 2, 4, 1.0, 0, 1700000200, 1700000220, 5, 0, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')",
        );
        database.execute(
          "INSERT INTO session_details(session_id, display_name, avatar) VALUES (14, 'Player A', 'avatar-a')",
        );
        database.execute(
          "INSERT INTO player_achievements VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'firstCatch', 1700000220000, 14)",
        );
        database.execute('PRAGMA user_version = 5');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final history = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(history.single.id, 14);
    expect(history.single.usedSmileMode, isNull);
    expect(history.single.usedTouchMode, isNull);
    final unlocks =
        await database
            .customSelect('SELECT achievement_id FROM player_achievements')
            .get();
    expect(unlocks.single.read<String>('achievement_id'), 'firstCatch');
    final tables =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('daily_challenge_assignments', 'player_challenge_clock')",
            )
            .get();
    expect(tables, hasLength(2));
    expect(database.schemaVersion, 8);
  });

  test('v6 to v8 migration preserves engagement and adds progression', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''CREATE TABLE game_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL, lives_lost INTEGER NOT NULL, max_lives INTEGER NOT NULL,
        time_played INTEGER NOT NULL, best_combo INTEGER NOT NULL, catches INTEGER NOT NULL,
        accuracy REAL NOT NULL, smile_score INTEGER NOT NULL,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        state INTEGER NOT NULL, is_new_best INTEGER NOT NULL CHECK(is_new_best IN (0, 1)),
        player_id TEXT)''');
        database.execute(
          'CREATE TABLE player_profile (slot INTEGER PRIMARY KEY CHECK(slot = 1), payload TEXT NOT NULL)',
        );
        database.execute(
          'CREATE TABLE session_details (session_id INTEGER PRIMARY KEY REFERENCES game_records(id) ON DELETE CASCADE, player_id TEXT, display_name TEXT, avatar TEXT, smile_samples INTEGER NOT NULL DEFAULT 0, smile_average REAL, smile_peak REAL, calibrated_smile_attempted INTEGER, calibrated_smile_samples INTEGER, calibrated_smile_average REAL, calibrated_smile_peak REAL, calibrated_smile_span_ms INTEGER, used_smile_mode INTEGER, used_touch_mode INTEGER, completion_timezone_offset_minutes INTEGER)',
        );
        database.execute(
          'CREATE TABLE player_achievements (player_id TEXT NOT NULL, achievement_id TEXT NOT NULL, unlocked_at INTEGER NOT NULL, source_result_id INTEGER NOT NULL REFERENCES game_records(id) ON DELETE CASCADE, PRIMARY KEY(player_id, achievement_id))',
        );
        database.execute(
          'CREATE TABLE daily_challenge_assignments (player_id TEXT NOT NULL, date_key TEXT NOT NULL, challenge_id TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL, assigned_at INTEGER NOT NULL, PRIMARY KEY(player_id, date_key, challenge_id))',
        );
        database.execute(
          'CREATE TABLE player_challenge_clock (player_id TEXT PRIMARY KEY, latest_date_key TEXT NOT NULL)',
        );
        database.execute(
          "INSERT INTO game_records VALUES (18, 900, 0, 3, 20, 2, 4, 1.0, 0, 1700000200, 1700000220, 5, 0, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')",
        );
        database.execute(
          "INSERT INTO session_details(session_id, display_name, avatar, used_touch_mode, completion_timezone_offset_minutes) VALUES (18, 'Player A', 'avatar-a', 1, 300)",
        );
        database.execute(
          "INSERT INTO daily_challenge_assignments VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', '2026-11-09', 'completeOneRound', 300, 1700000000000)",
        );
        database.execute(
          "INSERT INTO player_challenge_clock VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', '2026-11-09')",
        );
        database.execute('PRAGMA user_version = 6');
      },
    );
    final database = GameDatabase.forTesting(executor);
    addTearDown(database.close);
    final history = await GameRecordsRepositoryImpl(database).getAllSessions();
    expect(history.single.id, 18);
    expect(history.single.usedTouchMode, isTrue);
    final assignment =
        await database
            .customSelect(
              'SELECT challenge_id FROM daily_challenge_assignments',
            )
            .getSingle();
    expect(assignment.read<String>('challenge_id'), 'completeOneRound');
    final tables =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('player_progression_awards', 'player_cosmetic_unlocks')",
            )
            .get();
    expect(tables, hasLength(2));
    expect(database.schemaVersion, 8);
  });
}
