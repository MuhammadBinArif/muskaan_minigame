import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/achievements/application/achievement_service.dart';
import 'package:muskaan_minigame/features/achievements/data/achievement_repository.dart';
import 'package:muskaan_minigame/features/achievements/domain/player_achievement.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:sqlite3/open.dart';

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late GameDatabase database;
  late GameRecordsRepositoryImpl records;
  late AchievementRepository achievements;
  late AchievementService service;

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
    achievements = AchievementRepository(database);
    service = AchievementService(records, achievements);
  });
  tearDown(() => database.close());

  test(
    'unlocks persist across repository recreation and retry is idempotent',
    () async {
      final round = _record(1, playerA, catches: 1);
      await records.saveSession(round);
      final first = await service.evaluatePersistedResult(
        playerId: playerA,
        sourceResultId: 1,
        completedAt: round.endedAt!,
      );
      final retry = await service.evaluatePersistedResult(
        playerId: playerA,
        sourceResultId: 1,
        completedAt: round.endedAt!,
      );
      expect(
        first.map((unlock) => unlock.achievementId),
        contains(AchievementId.firstCatch),
      );
      expect(retry, isEmpty);
      expect(
        (await AchievementRepository(database).getUnlocks(
          playerA,
        )).where((unlock) => unlock.achievementId == AchievementId.firstCatch),
        hasLength(1),
      );
    },
  );

  test(
    'player ownership is isolated and NULL/unverified history cannot unlock',
    () async {
      await records.saveSession(_record(1, playerA, catches: 1));
      await records.saveSession(_record(2, playerB, catches: 1));
      await records.saveSession(
        _record(3, playerA, catches: 9, state: GameSessionState.gameOver),
      );
      await database.customStatement(
        'UPDATE game_records SET player_id = NULL WHERE id = 1',
      );
      final unlocks = await service.evaluatePersistedResult(
        playerId: playerA,
        sourceResultId: 3,
        completedAt: DateTime.utc(2026, 1, 3),
      );
      expect(
        unlocks.where(
          (unlock) => unlock.achievementId == AchievementId.firstCatch,
        ),
        isEmpty,
      );
      expect(await achievements.getUnlocks(playerB), isEmpty);
    },
  );

  test(
    'current schema contains achievement table and completed results',
    () async {
      await records.saveSession(_record(1, playerA, catches: 1));
      final tables =
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='player_achievements'",
              )
              .get();
      expect(database.schemaVersion, 7);
      expect(tables, hasLength(1));
      expect(await records.getAllSessions(), hasLength(1));
    },
  );
}

GameSessionRecord _record(
  int id,
  String playerId, {
  int catches = 0,
  GameSessionState state = GameSessionState.results,
}) => GameSessionRecord(
  playerId: playerId,
  playerName: 'Player',
  playerAvatar: '🥷',
  id: id,
  score: catches * 100,
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
