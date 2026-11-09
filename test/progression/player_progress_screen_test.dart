import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/progression/presentation/screens/player_progress_screen.dart';
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

  testWidgets('Player Progress derives persisted XP and cosmetic milestones', (
    tester,
  ) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final player = createTestPlayer();
    await PlayerProfileRepository(database).save(player);
    final records = GameRecordsRepositoryImpl(database);
    for (var id = 1; id <= 5; id++) {
      await records.saveSession(_record(id, player.id));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: PlayerProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('625 XP total · 125 / 500 to next level'), findsOneWidget);
    expect(find.text('5 lifetime verified rounds'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Smile Wizard'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Smile Wizard'), findsOneWidget);
    expect(find.textContaining('Reach level 3 · Level 2 of 3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Smart Glasses'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Smart Glasses'), findsOneWidget);
    expect(
      find.textContaining('Unlocked · Complete 5 verified rounds'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Recently unlocked'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Recently unlocked'), findsOneWidget);
  });
}

GameSessionRecord _record(int id, String playerId) => GameSessionRecord(
  playerId: playerId,
  playerName: 'Player',
  playerAvatar: '🥷',
  usedTouchMode: true,
  id: id,
  score: 500,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: 4,
  catches: 4,
  accuracy: 1,
  smileScore: 0,
  startedAt: DateTime.utc(2026, 1, id, 10),
  endedAt: DateTime.utc(2026, 1, id, 11),
  state: GameSessionState.results,
  isNewBest: false,
);
