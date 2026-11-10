import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/profile/domain/player_profile.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/presentation/widgets/player_identity.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import '../support/player_fixture.dart';
import '../support/ownership_camera.dart';
import '../support/game_completion.dart';
import '../session_regression_test.dart' show RetryRepository;

void main() {
  testWidgets('historical and different owners never use the active profile', (
    tester,
  ) async {
    final repository = MemoryPlayerRepository();
    final container = ProviderContainer(
      overrides: [
        playerProfileRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProfileProvider.notifier).ready;
    final historical = GameSessionRecord(
      id: 7,
      score: 10,
      livesLost: 0,
      maxLives: 3,
      timePlayed: 1,
      bestCombo: 0,
      catches: 0,
      accuracy: 0,
      smileScore: 0,
      startedAt: DateTime.utc(2025),
      state: GameSessionState.results,
      isNewBest: false,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: PlayerIdentity(record: historical)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('◯ Player not recorded'), findsOneWidget);
    expect(find.textContaining(repository.saved.displayName), findsNothing);

    final other = GameSessionRecord.create(
      playerId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      playerName: 'Other Player',
      playerAvatar: '🦊',
    ).complete(
      finalScore: 10,
      finalLivesLost: 0,
      timePlayed: 1,
      finalBestCombo: 0,
      finalCatches: 0,
      finalAccuracy: 0,
      finalSmileScore: 0,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: PlayerIdentity(record: other))),
      ),
    );
    await tester.pump();
    expect(find.text('🦊 Other Player'), findsOneWidget);
    expect(find.textContaining(repository.saved.displayName), findsNothing);
  });

  testWidgets('Welcome skip initializes and preserves one player identity', (
    tester,
  ) async {
    final repository = MemoryPlayerRepository();
    repository.saved = repository.saved.copyWith(onboarded: false);
    final originalId = repository.saved.id;
    final container = ProviderContainer(
      overrides: [
        playerProfileRepositoryProvider.overrideWithValue(repository),
        allRecordsStreamProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    final router = createRouter(initialLocation: '/welcome');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Skip intro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.saved.id, originalId);
    expect(repository.saved.onboarded, isTrue);
    expect(find.text('Good evening,'), findsOneWidget);
  });

  testWidgets('Welcome normal path initializes without duplicating identity', (
    tester,
  ) async {
    final repository = MemoryPlayerRepository();
    repository.saved = repository.saved.copyWith(onboarded: false);
    final originalId = repository.saved.id;
    final container = ProviderContainer(
      overrides: [
        playerProfileRepositoryProvider.overrideWithValue(repository),
        allRecordsStreamProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    final router = createRouter(initialLocation: '/welcome');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('SEE HOW IT WORKS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.saved.id, originalId);
    expect(find.text('Position Your Face'), findsOneWidget);
  });

  testWidgets('Avatar Studio reset updates the authoritative profile', (
    tester,
  ) async {
    final repository = MemoryPlayerRepository();
    repository.saved = repository.saved.copyWith(avatar: '👩🏽');
    final container = ProviderContainer(
      overrides: [
        playerProfileRepositoryProvider.overrideWithValue(repository),
        allRecordsStreamProvider.overrideWith((ref) => Stream.value([])),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProfileProvider.notifier).ready;
    final router = createRouter(initialLocation: '/profile');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('open-avatar-studio')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-avatar-studio')));
    await tester.pump();
    expect(find.text('Avatar Studio'), findsOneWidget);
    await tester.tap(find.text('Reset avatar'));
    await tester.pump();
    expect(repository.saved.avatar, '🥷');
  });

  testWidgets('camera startup failure preserves owner through Touch fallback', (
    tester,
  ) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = PlayerProfileRepository(database);
    final camera = OwnershipCameraService()..failInitialization = true;
    addTearDown(camera.close);
    final container = ProviderContainer(
      overrides: [
        gameDatabaseProvider.overrideWithValue(database),
        playerProfileRepositoryProvider.overrideWithValue(profiles),
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProfileProvider.notifier).ready;
    final router = createRouter(initialLocation: '/game?touch=true');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    final game = container.read(gameSessionProvider.notifier);
    final owner = game.activePlayerId;
    expect(owner, container.read(playerProfileProvider).requireValue.id);
    await tester.tap(find.text('Smile mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.activePlayerId, owner);
    if (game.state.canResume) game.resumeGame();
    completeRoundByExhaustingLives(game);
    await game.persistCompletedSession();
    final saved =
        await container.read(gameRecordsRepositoryProvider).getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.playerId, owner);
  });

  testWidgets('camera interruption and recovery preserve round ownership', (
    tester,
  ) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = PlayerProfileRepository(database);
    final camera = OwnershipCameraService();
    addTearDown(camera.close);
    final container = ProviderContainer(
      overrides: [
        gameDatabaseProvider.overrideWithValue(database),
        playerProfileRepositoryProvider.overrideWithValue(profiles),
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProfileProvider.notifier).ready;
    final router = createRouter(initialLocation: '/game?touch=true');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    final game = container.read(gameSessionProvider.notifier);
    final owner = game.activePlayerId;
    await tester.tap(find.text('Smile mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.activePlayerId, owner);
    camera.interrupt();
    await tester.pump();
    expect(game.activePlayerId, owner);
    await tester.tap(find.text('Play Touch-Only'));
    await tester.pump();
    expect(game.activePlayerId, owner);
    completeRoundByExhaustingLives(game);
    await game.persistCompletedSession();
    final saved =
        await container.read(gameRecordsRepositoryProvider).getAllSessions();
    expect(saved, hasLength(1));
    expect(saved.single.playerId, owner);
  });

  testWidgets(
    'Game Over to Results keeps Player A after production profile becomes Player B',
    (tester) async {
      final database = GameDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final profiles = PlayerProfileRepository(database);
      final container = ProviderContainer(
        overrides: [
          gameDatabaseProvider.overrideWithValue(database),
          playerProfileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ready;
      final playerA = container.read(playerProfileProvider).requireValue;
      final game = container.read(gameSessionProvider.notifier);
      game.startGame();
      completeRoundByExhaustingLives(game);
      await game.persistCompletedSession();
      final original = game.state.completedRecord!;
      expect(original.playerId, playerA.id);

      final router = createRouter(initialLocation: '/game-over');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.textContaining(playerA.displayName), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('SESSION COMPLETE'), findsOneWidget);
      expect(
        find.text('${playerA.avatar} ${playerA.displayName}'),
        findsOneWidget,
      );

      final playerB = PlayerProfile(
        id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        displayName: 'Player B',
        avatar: '🧑🏽',
        createdAt: DateTime.utc(2026, 3),
        updatedAt: DateTime.utc(2026, 3),
        onboarded: true,
      );
      await profiles.save(playerB);
      await container.read(playerProfileProvider.notifier).retryLoad();
      await tester.pump();
      expect(container.read(playerProfileProvider).requireValue.id, playerB.id);
      expect(game.state.completedRecord!.playerId, playerA.id);
      expect(
        find.text('${playerA.avatar} ${playerA.displayName}'),
        findsOneWidget,
      );
      expect(find.textContaining('Player B'), findsNothing);
    },
  );

  testWidgets(
    'Touch-Only creates an owned result without constructing camera or ML Kit',
    (tester) async {
      final profiles = MemoryPlayerRepository();
      final records = RetryRepository()..fail = false;
      final container = ProviderContainer(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(profiles),
          gameRecordsRepositoryProvider.overrideWithValue(records),
          allRecordsStreamProvider.overrideWith((ref) => Stream.value([])),
          cameraServiceProvider.overrideWith(
            (ref) => throw StateError('Camera must not be constructed'),
          ),
          visionServiceProvider.overrideWith(
            (ref) => throw StateError('ML Kit must not be constructed'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ready;
      final router = createRouter(initialLocation: '/game?touch=true');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.text('🥷 Happy Panda'), findsOneWidget);
      await tester.tap(find.text('READY'));
      await tester.pump();
      final game = container.read(gameSessionProvider.notifier);
      expect(game.state.isPlaying, isTrue);
      final roundOwner = game.activePlayerId;
      expect(roundOwner, profiles.saved.id);
      game.pauseGame();
      expect(game.activePlayerId, roundOwner);
      game.resumeGame();
      expect(game.activePlayerId, roundOwner);
      container.read(touchOnlyModeProvider.notifier).state = false;
      expect(game.activePlayerId, roundOwner);
      container.read(touchOnlyModeProvider.notifier).state = true;
      expect(game.activePlayerId, roundOwner);
      var cameraFailed = false;
      try {
        await container.read(mouthTrackingProvider.notifier).startTracking();
      } catch (_) {
        cameraFailed = true;
      }
      expect(cameraFailed, isTrue);
      expect(game.activePlayerId, roundOwner);
      await container
          .read(playerProfileProvider.notifier)
          .update(name: 'Smile King', avatar: '👩🏽');
      await tester.pump();
      expect(find.text('👩🏽 Smile King'), findsOneWidget);
      completeRoundByExhaustingLives(game);
      await game.persistCompletedSession();
      final result = records.records.values.single;
      expect(result.playerId, profiles.saved.id);
      expect(result.playerName, 'Smile King');
      expect(result.averageSmileProbability, isNull);
      expect(result.smileSampleCount, 0);
      // A stored score's owner survives later edits; presentation resolves current name reactively.
      await container
          .read(playerProfileProvider.notifier)
          .update(name: 'Joyful Star');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: PlayerIdentity(record: result)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('👩🏽 Joyful Star'), findsOneWidget);
      expect(result.playerId, profiles.saved.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: PlayerIdentity(record: result, useResultSnapshot: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('👩🏽 Smile King'), findsOneWidget);
    },
  );

  testWidgets(
    'onboarding accepts default, profile edit and local leaderboard stay synchronized',
    (tester) async {
      final repository = MemoryPlayerRepository();
      repository.saved = repository.saved.copyWith(onboarded: false);
      final ownedRecord = createTestSession().complete(
        finalScore: 100,
        finalLivesLost: 0,
        timePlayed: 10,
        finalBestCombo: 1,
        finalCatches: 1,
        finalAccuracy: 1,
        finalSmileScore: 0,
      );
      final container = ProviderContainer(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(repository),
          allRecordsStreamProvider.overrideWith(
            (ref) => Stream.value([ownedRecord]),
          ),
          cameraServiceProvider.overrideWith(
            (ref) => throw StateError('No camera during identity onboarding'),
          ),
          visionServiceProvider.overrideWith(
            (ref) => throw StateError('No ML during identity onboarding'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ready;
      final router = createRouter(initialLocation: '/player-setup');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.text('Happy Panda'), findsOneWidget);
      await tester.tap(find.text('Keep generated name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.saved.onboarded, isTrue);
      router.go('/profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  Smile King  ');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(repository.saved.displayName, 'Smile King');
      final id = repository.saved.id;
      await tester.ensureVisible(find.byKey(const Key('open-avatar-studio')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-avatar-studio')));
      await tester.pump();
      await tester.tap(find.byTooltip('Choose avatar 4'));
      await tester.pump();
      expect(repository.saved.avatar, '👩🏽');
      router.go('/home');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('👩🏽 Smile King'), findsOneWidget);
      router.go('/leaderboard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Leaderboard on this device'), findsOneWidget);
      expect(find.text('👩🏽 Smile King'), findsOneWidget);
      expect(repository.saved.id, id);
      await container
          .read(playerProfileProvider.notifier)
          .update(name: 'Sunny Player', avatar: '👨🏾');
      await tester.pump();
      expect(find.text('👨🏾 Sunny Player'), findsOneWidget);
      expect(repository.saved.id, id);
    },
  );
}
