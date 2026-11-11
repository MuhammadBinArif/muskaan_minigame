import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';

void main() {
  Future<({
    GameDatabase database,
    ProviderContainer container,
    GoRouter router,
  })> mountGame(WidgetTester tester, {bool pushFromHome = false}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [gameDatabaseProvider.overrideWithValue(database)],
    );
    await container.read(playerProfileProvider.notifier).ready;
    await container.read(playerProfileProvider.notifier).update(onboarded: true);
    final router = createRouter(
      initialLocation: pushFromHome ? '/home' : '/game?touch=true',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    if (pushFromHome) {
      router.push('/game?touch=true');
      await tester.pump();
    }
    await tester.tap(find.text('READY'));
    await tester.pump();
    return (database: database, container: container, router: router);
  }

  Future<void> disposeHarness(
    WidgetTester tester,
    ({
      GameDatabase database,
      ProviderContainer container,
      GoRouter router,
    }) harness,
  ) async {
    harness.router.dispose();
    harness.container.dispose();
    await harness.database.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('home navigation and gameplay route disposal save no result', (
    tester,
  ) async {
    final harness = await mountGame(tester);
    addTearDown(() => disposeHarness(tester, harness));

    harness.router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      await harness.container
          .read(gameRecordsRepositoryProvider)
          .getAllSessions(),
      isEmpty,
    );
  });

  testWidgets('back navigation saves no result', (tester) async {
    final harness = await mountGame(tester, pushFromHome: true);
    addTearDown(() => disposeHarness(tester, harness));

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      await harness.container
          .read(gameRecordsRepositoryProvider)
          .getAllSessions(),
      isEmpty,
    );
  });

  testWidgets('paused Exit Game flow saves no result', (tester) async {
    final harness = await mountGame(tester);
    addTearDown(() => disposeHarness(tester, harness));

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    await tester.tap(find.text('QUIT ROUND'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      await harness.container
          .read(gameRecordsRepositoryProvider)
          .getAllSessions(),
      isEmpty,
    );
  });
}
