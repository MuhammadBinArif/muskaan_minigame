import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/domain/player_profile.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';

import '../support/ownership_camera.dart';

void main() {
  testWidgets(
    'empty first launch through Player A round and Player B replacement preserves result owner',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var storeWasEmpty = false;
      final executor = NativeDatabase.memory(
        setup: (raw) {
          final row = raw.select(
            "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name = 'player_profile'",
          );
          storeWasEmpty = row.single['count'] == 0;
        },
      );
      final database = GameDatabase.forTesting(executor);
      addTearDown(database.close);
      await database.customSelect('SELECT 1').getSingle();
      expect(storeWasEmpty, isTrue);

      final camera = OwnershipCameraService();
      addTearDown(camera.close);
      final container = ProviderContainer(
        overrides: [
          gameDatabaseProvider.overrideWithValue(database),
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
        ],
      );
      addTearDown(container.dispose);
      final router = createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('Meet your player! Keep this name or choose your own.'),
        findsOneWidget,
      );
      final generated = container.read(playerProfileProvider).requireValue;
      expect(generated.id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(generated.displayName, isNotEmpty);
      await tester.tap(find.text('Keep generated name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Skip intro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.go('/profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Player A');
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('open-avatar-studio')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-avatar-studio')));
      await tester.pump();
      await tester.tap(find.byTooltip('Choose avatar 4'));
      await tester.pump();
      final playerA = container.read(playerProfileProvider).requireValue;
      expect(playerA.id, generated.id);
      expect(playerA.displayName, 'Player A');
      expect(playerA.avatar, '👩🏽');
      expect(find.textContaining('Player A'), findsWidgets);

      router.go('/game');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final game = container.read(gameSessionProvider.notifier);
      expect(game.activePlayerId, playerA.id);
      await tester.tap(find.text('Touch mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.activePlayerId, playerA.id);
      await tester.tap(find.text('Smile mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.activePlayerId, playerA.id);

      await database.customStatement(
        "CREATE TRIGGER fail_journey_result BEFORE INSERT ON game_records BEGIN SELECT RAISE(FAIL, 'forced journey failure'); END",
      );
      game.quitGame();
      await game.persistCompletedSession();
      final original = game.state.completedRecord!;
      expect(original.playerId, playerA.id);
      expect(game.state.saveError, isNotNull);
      await database.customStatement('DROP TRIGGER fail_journey_result');

      final playerB = PlayerProfile(
        id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        displayName: 'Player B',
        avatar: '🧑🏽',
        createdAt: DateTime.utc(2026, 4),
        updatedAt: DateTime.utc(2026, 4),
        onboarded: true,
      );
      final profiles = container.read(playerProfileRepositoryProvider);
      await profiles.save(playerB);
      await container.read(playerProfileProvider.notifier).retryLoad();
      expect(container.read(playerProfileProvider).requireValue.id, playerB.id);

      await Future.wait([
        game.persistCompletedSession(),
        game.persistCompletedSession(),
      ]);
      final records =
          await container.read(gameRecordsRepositoryProvider).getAllSessions();
      expect(records, hasLength(1));
      final saved = records.single;
      expect(saved.playerId, playerA.id);
      expect(saved.id, original.id);
      expect(saved.score, original.score);
      expect(
        saved.startedAt.millisecondsSinceEpoch ~/ 1000,
        original.startedAt.millisecondsSinceEpoch ~/ 1000,
      );
      expect(saved.state, GameSessionState.results);
      final count =
          await database
              .customSelect('SELECT COUNT(*) AS count FROM game_records')
              .getSingle();
      expect(count.read<int>('count'), 1);

      router.go('/game-over');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('SESSION COMPLETE'), findsOneWidget);
      expect(find.text('👩🏽 Player A'), findsOneWidget);
      expect(find.textContaining('Player B'), findsNothing);
      expect(game.state.completedRecord!.playerId, playerA.id);

      router.go('/profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Player B'), findsWidgets);
      expect(find.text('🧑🏽'), findsWidgets);
      expect(container.read(playerProfileProvider).requireValue.id, playerB.id);
    },
  );
}
