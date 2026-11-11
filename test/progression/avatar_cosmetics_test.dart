import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/presentation/screens/profile_screen.dart';
import 'package:muskaan_minigame/features/progression/data/progression_repository.dart';
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

  testWidgets('Avatar Studio locks, equips, restores, and resets cosmetics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final profiles = PlayerProfileRepository(database);
    await profiles.save(createTestPlayer());
    final records = GameRecordsRepositoryImpl(database);
    for (var id = 1; id <= 5; id++) {
      await records.saveSession(_record(id));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byKey(const Key('open-avatar-studio')));
    await tester.tap(find.byKey(const Key('open-avatar-studio')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Smart Glasses'), findsOneWidget);
    expect(find.text('Smile Wizard'), findsOneWidget);
    expect(find.textContaining('Reach level 3'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Choose avatar 7'));
    await tester.tap(find.byTooltip('Choose avatar 7'));
    await tester.pump();
    expect((await profiles.loadOrCreate()).avatar, '🥷');
    expect(find.text('Avatar Studio'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Choose avatar 8'));
    await tester.tap(find.byTooltip('Choose avatar 8'));
    await tester.pump();
    expect((await profiles.loadOrCreate()).avatar, '🤓');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('🤓'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('open-avatar-studio')));
    await tester.tap(find.byKey(const Key('open-avatar-studio')));
    await tester.pump();
    await tester.tap(find.text('Reset avatar'));
    await tester.pump();
    expect((await profiles.loadOrCreate()).avatar, '🥷');
    expect(
      (await ProgressionRepository(
        database,
      ).getUnlocks(createTestPlayer().id)).map((item) => item.cosmeticId),
      contains('glasses'),
    );
  });
}

GameSessionRecord _record(int id) => GameSessionRecord(
  playerId: createTestPlayer().id,
  playerName: createTestPlayer().displayName,
  playerAvatar: createTestPlayer().avatar,
  usedTouchMode: true,
  id: id,
  score: 0,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: 0,
  catches: 0,
  accuracy: 0,
  smileScore: 0,
  startedAt: DateTime.utc(2026, 1, id, 10),
  endedAt: DateTime.utc(2026, 1, id, 11),
  state: GameSessionState.results,
  isNewBest: false,
);
