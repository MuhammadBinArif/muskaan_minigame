import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/challenges/data/daily_challenge_repository.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:sqlite3/open.dart';

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late GameDatabase database;
  late DailyChallengeRepository repository;

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });
  setUp(() {
    database = GameDatabase.forTesting(NativeDatabase.memory());
    repository = DailyChallengeRepository(database);
  });
  tearDown(() => database.close());

  test('assignments survive restart and remain player-isolated', () async {
    final instant = DateTime(2026, 11, 9, 10);
    final first = await repository.loadOrCreate(
      playerId: playerA,
      now: instant,
      smileDataAvailable: false,
    );
    final restored = await DailyChallengeRepository(database).loadOrCreate(
      playerId: playerA,
      now: instant.add(const Duration(hours: 2)),
      smileDataAvailable: true,
    );
    final other = await repository.loadOrCreate(
      playerId: playerB,
      now: instant,
      smileDataAvailable: false,
    );
    expect(
      restored.map((item) => item.challengeId),
      first.map((item) => item.challengeId),
    );
    expect(restored.every((item) => item.playerId == playerA), isTrue);
    expect(other.every((item) => item.playerId == playerB), isTrue);
  });

  test('forward date advances once and backward clock cannot reroll', () async {
    final dayOne = await repository.loadOrCreate(
      playerId: playerA,
      now: DateTime(2026, 11, 9, 10),
      smileDataAvailable: false,
    );
    final dayTwo = await repository.loadOrCreate(
      playerId: playerA,
      now: DateTime(2026, 11, 10, 10),
      smileDataAvailable: false,
    );
    final backwards = await repository.loadOrCreate(
      playerId: playerA,
      now: DateTime(2026, 11, 8, 10),
      smileDataAvailable: true,
    );
    expect(dayOne.first.dateKey, '2026-11-09');
    expect(dayTwo.first.dateKey, '2026-11-10');
    expect(backwards.first.dateKey, '2026-11-10');
    expect(
      backwards.map((item) => item.challengeId),
      dayTwo.map((item) => item.challengeId),
    );
  });

  test('current schema retains engagement tables', () async {
    await repository.loadOrCreate(
      playerId: playerA,
      now: DateTime(2026, 11, 9),
      smileDataAvailable: false,
    );
    final tables =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('daily_challenge_assignments', 'player_challenge_clock') ORDER BY name",
            )
            .get();
    expect(database.schemaVersion, 7);
    expect(tables, hasLength(2));
    final integrity =
        await database.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.data.values.single, 'ok');
  });
}
