import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/achievements/application/achievement_service.dart';
import 'package:muskaan_minigame/features/achievements/data/achievement_repository.dart';
import 'package:muskaan_minigame/features/challenges/application/daily_challenge_service.dart';
import 'package:muskaan_minigame/features/challenges/data/daily_challenge_repository.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/progression/application/progression_service.dart';
import 'package:muskaan_minigame/features/progression/data/progression_repository.dart';

import '../support/game_completion.dart';
import '../support/player_fixture.dart';

void main() {
  late GameDatabase database;
  late GameRecordsRepositoryImpl records;

  setUp(() {
    database = GameDatabase.forTesting(NativeDatabase.memory());
    records = GameRecordsRepositoryImpl(database);
  });

  tearDown(() => database.close());

  test('timer expiry persists exactly one owned result', () async {
    var rewardCallbacks = 0;
    final game = GameSessionNotifier(
      repository: records,
      profile: createTestPlayer,
      sessionDuration: const Duration(milliseconds: 20),
      onResultPersisted: (_) async {
        rewardCallbacks++;
      },
    );
    addTearDown(game.dispose);

    game.startGame();
    final owner = game.activePlayerId;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await game.persistCompletedSession();
    await Future<void>.delayed(Duration.zero);
    await game.persistCompletedSession();

    final saved = await records.getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.playerId, owner);
    expect(rewardCallbacks, 1);
  });

  test('exhausted lives persist exactly one owned result', () async {
    final game = GameSessionNotifier(
      repository: records,
      profile: createTestPlayer,
    );
    addTearDown(game.dispose);

    game.startGame();
    final owner = game.activePlayerId;
    completeRoundByExhaustingLives(game);
    await game.persistCompletedSession();
    game.leaveGame();
    game.quitGame();
    await game.persistCompletedSession();

    final saved = await records.getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.playerId, owner);
    expect(saved.single.livesLost, saved.single.maxLives);
  });

  test(
    'quit, leave, pause-exit and repeated abandonment save nothing',
    () async {
    for (final abandon in <void Function(GameSessionNotifier)>[
      (game) => game.quitGame(),
      (game) => game.leaveGame(),
      (game) {
        game.pauseGame();
        game.quitGame();
      },
      (game) {
        game.leaveGame();
        game.leaveGame();
        game.quitGame();
      },
    ]) {
      final game = GameSessionNotifier(
        repository: records,
        profile: createTestPlayer,
        sessionDuration: const Duration(milliseconds: 20),
      );
      game.startGame();
      abandon(game);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await game.persistCompletedSession();
      expect(game.state.completedRecord, isNull);
      game.dispose();
    }

    expect(await records.getAllSessions(), isEmpty);
    final playerId = createTestPlayer().id;
    final achievementProgress = await AchievementService(
      records,
      AchievementRepository(database),
    ).getProgress(playerId);
    final progression = await ProgressionService(
      records,
      AchievementRepository(database),
      ProgressionRepository(database),
    ).synchronize(playerId);
    final engagement = await DailyChallengeService(
      records,
      DailyChallengeRepository(database),
    ).load(playerId, now: DateTime(2026));
    expect(
      achievementProgress.progress.where((item) => item.isUnlocked),
      isEmpty,
    );
    expect(progression.totalXp, 0);
    expect(progression.lifetimeVerifiedRounds, 0);
    expect(engagement.challenges.every((item) => item.progress == 0), isTrue);
    expect(engagement.streak.activeDayCount, 0);
    },
  );

  test(
    'rapid pause, resume and exit cannot be completed by a delayed tick',
    () async {
    final game = GameSessionNotifier(
      repository: records,
      profile: createTestPlayer,
      sessionDuration: const Duration(milliseconds: 35),
    );
    addTearDown(game.dispose);

    game.startGame();
    game.pauseGame();
    game.resumeGame();
    game.pauseGame();
    game.resumeGame();
    game.leaveGame();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(game.state.completedRecord, isNull);
    expect(await records.getAllSessions(), isEmpty);
    },
  );

  test('background-style pause never completes a round automatically', () async {
    final game = GameSessionNotifier(
      repository: records,
      profile: createTestPlayer,
      sessionDuration: const Duration(milliseconds: 20),
    );
    addTearDown(game.dispose);

    game.startGame();
    game.pauseGame();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(game.state.completedRecord, isNull);
    expect(await records.getAllSessions(), isEmpty);

    game.resumeGame();
    completeRoundByExhaustingLives(game);
    await game.persistCompletedSession();
    expect(await records.getAllSessions(), hasLength(1));
  });

  test(
    'abandonment leaves existing data and derived rewards unchanged',
    () async {
    final completed = GameSessionRecord.create(
      playerId: createTestPlayer().id,
      playerName: createTestPlayer().displayName,
      playerAvatar: createTestPlayer().avatar,
    ).complete(
      finalScore: 100,
      finalLivesLost: 3,
      timePlayed: 10,
      finalBestCombo: 1,
      finalCatches: 1,
      finalAccuracy: 1,
      finalSmileScore: 0,
    );
    await records.saveSession(completed);

    final game = GameSessionNotifier(
      repository: records,
      profile: createTestPlayer,
    );
    addTearDown(game.dispose);
    game.startGame();
    game.leaveGame();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final history = await records.getAllSessions();
    expect(history.map((record) => record.id), [completed.id]);

    final achievements = AchievementService(
      records,
      AchievementRepository(database),
    );
    final progression = ProgressionService(
      records,
      AchievementRepository(database),
      ProgressionRepository(database),
    );
    final challenges = DailyChallengeService(
      records,
      DailyChallengeRepository(database),
    );
    final achievementProgress = await achievements.getProgress(
      createTestPlayer().id,
    );
    final playerProgression = await progression.synchronize(
      createTestPlayer().id,
    );
    final engagement = await challenges.load(
      createTestPlayer().id,
      now: completed.endedAt,
    );

    expect(
      achievementProgress.progress
          .where((item) => item.isUnlocked)
          .map((item) => item.definition.id),
      hasLength(1),
    );
    expect(playerProgression.lifetimeVerifiedRounds, 1);
    expect(
      engagement.challenges
          .where((challenge) => challenge.isComplete)
          .length,
      lessThanOrEqualTo(1),
    );
    expect(engagement.streak.activeDayCount, 1);
    },
  );
}
