import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:muskaan_minigame/features/achievements/application/achievement_service.dart';
import 'package:muskaan_minigame/features/achievements/domain/player_achievement.dart';
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:sqlite3/open.dart';

import '../support/player_fixture.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  testWidgets('shows locked, unavailable, progress and category filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await PlayerProfileRepository(database).save(createTestPlayer());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AchievementsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Happy Panda'), findsOneWidget);
    expect(find.text('First Catch'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.byKey(const Key('achievement-filter-smile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('achievement-filter-smile')));
    await tester.pump();
    expect(find.text('First Smile Measurement'), findsOneWidget);
    expect(find.text('First Catch'), findsNothing);
  });

  testWidgets('new unlock is announced once without blocking Results', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final record = GameSessionRecord(
      playerId: '0123456789abcdef0123456789abcdef',
      playerName: 'Happy Panda',
      playerAvatar: '🥷',
      id: 10,
      score: 100,
      livesLost: 0,
      maxLives: 3,
      timePlayed: 10,
      bestCombo: 1,
      catches: 1,
      accuracy: 1,
      smileScore: 0,
      startedAt: DateTime.utc(2026),
      endedAt: DateTime.utc(2026, 1, 1, 0, 1),
      state: GameSessionState.results,
      isNewBest: false,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ResultsScreen(gameRecord: record)),
      ),
    );
    await tester.pump();
    container.read(latestAchievementUnlocksProvider.notifier).state = [
      AchievementUnlock(
        playerId: record.playerId!,
        achievementId: AchievementId.firstCatch,
        unlockedAt: record.endedAt!,
        sourceResultId: record.id,
      ),
    ];
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('achievement-unlock-dialog')), findsOneWidget);
    expect(find.text('Achievement unlocked!'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('achievement-unlock-dialog')), findsNothing);
    expect(container.read(latestAchievementUnlocksProvider), isEmpty);
  });
}
