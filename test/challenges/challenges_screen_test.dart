import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/challenges/application/daily_challenge_service.dart';
import 'package:muskaan_minigame/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';

import '../support/player_fixture.dart';

void main() {
  testWidgets('shows a distinct loading state on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(
            MemoryPlayerRepository(),
          ),
          dailyEngagementProvider(
            createTestPlayer().id,
          ).overrideWith((ref) => Completer<DailyEngagementState>().future),
        ],
        child: const MaterialApp(home: ChallengesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('challenges-loading')), findsOneWidget);
  });

  testWidgets('database failures are not displayed as empty challenges', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(
            MemoryPlayerRepository(),
          ),
          dailyEngagementProvider(
            createTestPlayer().id,
          ).overrideWith((ref) => Future.error(StateError('read failed'))),
        ],
        child: const MaterialApp(home: ChallengesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('challenges-error')), findsOneWidget);
    expect(find.text('Challenges could not be loaded.'), findsOneWidget);
    expect(find.text('No challenges assigned'), findsNothing);
  });
}
