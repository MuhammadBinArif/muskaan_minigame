import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/gameplay_screen.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/domain/profile_avatar.dart';
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:sqlite3/open.dart';

import '../support/player_fixture.dart';

const otherPlayer = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

GameSessionRecord result({
  required int id,
  String? playerId,
  GameSessionState state = GameSessionState.results,
  bool completed = true,
}) {
  final player = createTestPlayer(id: playerId ?? createTestPlayer().id);
  return GameSessionRecord(
    playerId: player.id,
    playerName: player.displayName,
    playerAvatar: player.avatar,
    id: id,
    score: 640,
    livesLost: 1,
    maxLives: 3,
    timePlayed: 30,
    bestCombo: 4,
    catches: 8,
    accuracy: .8,
    smileScore: 0,
    startedAt: DateTime.utc(2026, 11, 10, 10),
    endedAt: completed ? DateTime.utc(2026, 11, 10, 10, 1) : null,
    state: state,
    isNewBest: false,
  );
}

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  group('persisted results route integrity', () {
    late GameDatabase database;
    late GameRecordsRepositoryImpl repository;

    setUp(() {
      database = GameDatabase.forTesting(NativeDatabase.memory());
      repository = GameRecordsRepositoryImpl(database);
    });
    tearDown(() => database.close());

    Future<GoRouter> pumpRoute(WidgetTester tester, String location) async {
      final router = createRouter(initialLocation: location);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProfileRepositoryProvider.overrideWithValue(
              MemoryPlayerRepository(),
            ),
            gameRecordsRepositoryProvider.overrideWithValue(repository),
            allRecordsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return router;
    }

    testWidgets('missing and invalid IDs never fabricate results', (
      tester,
    ) async {
      await pumpRoute(tester, '/results');
      expect(find.text('Result unavailable'), findsOneWidget);
      expect(find.byType(ResultsScreen), findsNothing);

      await pumpRoute(tester, '/results?id=invalid');
      expect(find.text('Result unavailable'), findsOneWidget);
      expect(find.byType(ResultsScreen), findsNothing);
    });

    testWidgets('deleted and abandoned result IDs are unavailable', (
      tester,
    ) async {
      await repository.saveSession(result(id: 11));
      await database.deleteSession(11);
      await pumpRoute(tester, '/results?id=11');
      expect(find.text('Result unavailable'), findsOneWidget);

      // Abandoned rounds have no persisted result by Phase 1 contract.
      await pumpRoute(tester, '/results?id=12');
      expect(find.text('Result unavailable'), findsOneWidget);
    });

    testWidgets('incomplete and another player results are unavailable', (
      tester,
    ) async {
      await repository.saveSession(
        result(
          id: 21,
          state: GameSessionState.playing,
          completed: false,
        ),
      );
      await repository.saveSession(result(id: 22, playerId: otherPlayer));

      await pumpRoute(tester, '/results?id=21');
      expect(find.text('Result unavailable'), findsOneWidget);
      await pumpRoute(tester, '/results?id=22');
      expect(find.text('Result unavailable'), findsOneWidget);
    });

    testWidgets('valid persisted result supports replay and Home navigation', (
      tester,
    ) async {
      await repository.saveSession(result(id: 31));
      final router = await pumpRoute(tester, '/results?id=31');
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.text('SESSION COMPLETE'), findsOneWidget);

      await tester.ensureVisible(find.text('PLAY AGAIN'));
      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/countdown');
      router.go('/results?id=31');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      router.go('/home');
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
  });

  testWidgets('simulation snapshots do not rebuild the GameplayScreen', (
    tester,
  ) async {
    final avatars = StreamController<ProfileAvatar?>();
    addTearDown(avatars.close);
    final container = ProviderContainer(
      overrides: [
        playerProfileRepositoryProvider.overrideWithValue(
          MemoryPlayerRepository(),
        ),
        profileAvatarProvider.overrideWith((ref) => avatars.stream),
      ],
    );
    addTearDown(container.dispose);
    var builds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameplayScreen(
            touchOnly: true,
            onBuildForTest: () => builds++,
          ),
        ),
      ),
    );
    await tester.pump();
    await container.read(playerProfileProvider.notifier).ready;
    await tester.pump();
    final baseline = builds;
    final game = container.read(gameSessionProvider.notifier);
    game.startGame(touchOnly: true);
    await tester.pump();
    final afterStart = builds;

    for (var frame = 0; frame < 10; frame++) {
      game.state = game.state.copyWith(
        activeFoods: [
          FoodItem(
            type: FoodItemType.gold,
            positionX: .5,
            positionY: frame / 100,
            velocityX: 0,
            velocityY: .2,
            size: .08,
            creationTime: 0,
          ),
        ],
      );
    }
    await tester.pump();
    expect(baseline, greaterThan(0));
    expect(builds, afterStart);

    final caught = game.state.stats
        .recordSpawn(FoodItemType.gold)
        .applyCollision(
          const CollisionEvent(
            foodType: FoodItemType.gold,
            mouthX: .5,
            mouthY: .52,
            timestamp: 1,
            isCatch: true,
          ),
        );
    game.state = game.state.copyWith(stats: caught);
    await tester.pump();
    expect(builds, afterStart);
    expect(find.text('100'), findsOneWidget);
    game.abandonGame();
  });
}
