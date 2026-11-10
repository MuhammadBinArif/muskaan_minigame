import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/achievements/data/achievement_repository.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/domain/player_profile.dart';
import 'package:muskaan_minigame/features/progression/application/progression_service.dart';
import 'package:muskaan_minigame/features/progression/data/progression_repository.dart';
import 'package:muskaan_minigame/features/progression/domain/player_progression.dart';
import 'package:sqlite3/open.dart';

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late GameDatabase database;
  late GameRecordsRepositoryImpl records;
  late ProgressionRepository progression;
  late ProgressionService service;

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
    records = GameRecordsRepositoryImpl(database);
    progression = ProgressionRepository(database);
    service = ProgressionService(
      records,
      AchievementRepository(database),
      progression,
    );
  });
  tearDown(() => database.close());

  test(
    'result retry awards XP once and restores after repository restart',
    () async {
      final record = _record(1, playerA, score: 500, catches: 4);
      await records.saveSession(record);
      await service.synchronize(playerA);
      await records.saveSession(record);
      final restored = await ProgressionService(
        records,
        AchievementRepository(database),
        ProgressionRepository(database),
      ).synchronize(playerA);
      expect(restored.lifetimeVerifiedRounds, 1);
      expect(restored.totalXp, 125);
      expect(await progression.getAwards(playerA), hasLength(1));
    },
  );

  test('repository rejects XP outside the domain award bounds', () async {
    await records.saveSession(_record(1, playerA));
    await expectLater(
      progression.awardResult(
        ProgressionAward(
          playerId: playerA,
          resultId: 1,
          xp: 201,
          awardedAt: DateTime.utc(2026),
        ),
      ),
      throwsFormatException,
    );
    expect(await progression.getAwards(playerA), isEmpty);
  });

  test('Player A and B XP and cosmetics remain isolated', () async {
    for (var id = 1; id <= 5; id++) {
      await records.saveSession(_record(id, playerA, score: 1000, catches: 5));
    }
    await records.saveSession(_record(20, playerB, score: 100, catches: 0));
    final a = await service.synchronize(playerA);
    final b = await service.synchronize(playerB);
    expect(a.lifetimeVerifiedRounds, 5);
    expect(b.lifetimeVerifiedRounds, 1);
    expect(
      a.cosmetics.singleWhere((item) => item.item.id == 'glasses').unlocked,
      isTrue,
    );
    expect(
      b.cosmetics.singleWhere((item) => item.item.id == 'glasses').unlocked,
      isFalse,
    );
    expect(await progression.getUnlocks(playerB), isEmpty);
  });

  test(
    'profile replacement does not transfer original owner progression',
    () async {
      final profiles = PlayerProfileRepository(database);
      await profiles.save(_profile(playerA, 'Player A'));
      await records.saveSession(_record(1, playerA, score: 500, catches: 4));
      await profiles.save(_profile(playerB, 'Player B'));

      final a = await service.synchronize(playerA);
      final b = await service.synchronize(playerB);

      expect((await profiles.loadOrCreate()).id, playerB);
      expect(a.totalXp, 125);
      expect(b.totalXp, 0);
      expect(await progression.getAwards(playerA), hasLength(1));
      expect(await progression.getAwards(playerB), isEmpty);
    },
  );

  test('unverified and NULL-owner records never generate awards', () async {
    await records.saveSession(
      _record(1, playerA, state: GameSessionState.gameOver),
    );
    await records.saveSession(_record(2, playerA));
    await database.customStatement(
      'UPDATE game_records SET player_id = NULL WHERE id = 2',
    );
    final state = await service.synchronize(playerA);
    expect(state.totalXp, 0);
    expect(await progression.getAwards(playerA), isEmpty);
  });

  test('schema v7 contains progression tables and preserves results', () async {
    await records.saveSession(_record(1, playerA));
    await service.synchronize(playerA);
    final tables =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('player_progression_awards', 'player_cosmetic_unlocks')",
            )
            .get();
    expect(database.schemaVersion, 8);
    expect(tables, hasLength(2));
    expect(await records.getAllSessions(), hasLength(1));
  });
}

GameSessionRecord _record(
  int id,
  String playerId, {
  int score = 0,
  int catches = 0,
  GameSessionState state = GameSessionState.results,
}) => GameSessionRecord(
  playerId: playerId,
  playerName: 'Player',
  playerAvatar: '🥷',
  usedTouchMode: true,
  id: id,
  score: score,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: catches,
  catches: catches,
  accuracy: catches == 0 ? 0 : 1,
  smileScore: 0,
  startedAt: DateTime.utc(2026, 1, id, 10),
  endedAt: DateTime.utc(2026, 1, id, 11),
  state: state,
  isNewBest: false,
);

PlayerProfile _profile(String id, String name) => PlayerProfile(
  id: id,
  displayName: name,
  avatar: '🥷',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
