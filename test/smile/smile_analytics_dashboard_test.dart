import 'dart:ffi';
import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:muskaan_minigame/features/smile/domain/player_smile_analytics.dart';
import 'package:muskaan_minigame/features/smile/presentation/screens/smile_analytics_screen.dart';
import 'package:sqlite3/open.dart';

import '../support/player_fixture.dart';

void main() {
  const playerId = '0123456789abcdef0123456789abcdef';

  HistoricalSmileRound round({
    required int id,
    required int day,
    required double average,
    required double peak,
  }) => HistoricalSmileRound(
    resultId: id,
    playerId: playerId,
    averageIntensity: average,
    peakIntensity: peak,
    validObservationCount: 5,
    observedSpan: const Duration(seconds: 2),
    completedAt: DateTime.now().subtract(Duration(days: day)),
  );

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  test('chart series uses exact values in chronological order', () {
    final newest = round(id: 2, day: 1, average: 60, peak: 90);
    final oldest = round(id: 1, day: 2, average: 40, peak: 70);
    expect(
      buildSmileChartSeries([
        newest,
        oldest,
      ], SmileChartMetric.average).map((point) => point.value),
      [40, 60],
    );
    expect(
      buildSmileChartSeries([
        newest,
        oldest,
      ], SmileChartMetric.peak).map((point) => point.value),
      [70, 90],
    );
  });

  test('chart excludes invalid data instead of plotting zero', () {
    final invalid = HistoricalSmileRound(
      resultId: 3,
      playerId: playerId,
      averageIntensity: 0,
      peakIntensity: 0,
      validObservationCount: 0,
      observedSpan: Duration.zero,
      completedAt: DateTime.now(),
    );
    expect(buildSmileChartSeries([invalid], SmileChartMetric.average), isEmpty);
  });

  testWidgets('dashboard renders genuine SQLite history and range controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PlayerProfileRepository(database);
    await repository.save(createTestPlayer());
    final records = <GameSessionRecord>[
      _record(id: 1, average: 42, peak: 75),
      _record(id: 2, average: 68, peak: 93),
    ];
    final gameRepository = GameRecordsRepositoryImpl(database);
    for (final record in records) {
      await gameRepository.saveSession(record);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SmileAnalyticsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Happy Panda'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('55.0%'), findsWidgets);
    expect(find.text('93.0%'), findsWidgets);
    expect(find.byKey(const Key('smile-history-chart')), findsOneWidget);
    expect(find.byKey(const Key('range-sevenDays')), findsOneWidget);
    expect(find.textContaining('Valid Observations: 5'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('range-sevenDays')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('55.0%'), findsWidgets);
    expect(find.text('93.0%'), findsWidgets);
    await tester.ensureVisible(find.text('Open result').first);
    await tester.tap(find.text('Open result').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ResultsScreen), findsOneWidget);
  });

  testWidgets('dashboard shows a genuine empty state', (tester) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await PlayerProfileRepository(database).save(createTestPlayer());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SmileAnalyticsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
    expect(find.text('No measured rounds yet'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('dashboard distinguishes loading and database errors', (
    tester,
  ) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await PlayerProfileRepository(database).save(createTestPlayer());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameDatabaseProvider.overrideWithValue(database),
          gameRecordsRepositoryProvider.overrideWithValue(
            _PendingRecordsRepository(database),
          ),
        ],
        child: const MaterialApp(home: SmileAnalyticsScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('analytics-loading')), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameDatabaseProvider.overrideWithValue(database),
          gameRecordsRepositoryProvider.overrideWithValue(
            _ErrorRecordsRepository(database),
          ),
        ],
        child: const MaterialApp(home: SmileAnalyticsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('analytics-error')), findsOneWidget);
    expect(find.text('Analytics could not be loaded'), findsOneWidget);
  });

  testWidgets('profile replacement cannot retain prior player analytics', (
    tester,
  ) async {
    final database = GameDatabase.forTesting(NativeDatabase.memory());
    final profileRepository = PlayerProfileRepository(database);
    await profileRepository.save(createTestPlayer(name: 'Player A'));
    await GameRecordsRepositoryImpl(
      database,
    ).saveSession(_record(id: 9, average: 88, peak: 97));
    final container = ProviderContainer(
      overrides: [gameDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SmileAnalyticsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Player A'), findsOneWidget);
    expect(find.text('88.0%'), findsWidgets);

    await container
        .read(playerProfileProvider.notifier)
        .replaceCorruptProfile();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Player A'), findsNothing);
    expect(find.text('88.0%'), findsNothing);
    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
  });
}

class _PendingRecordsRepository extends GameRecordsRepositoryImpl {
  _PendingRecordsRepository(super.database);

  @override
  Future<List<HistoricalSmileRound>> getPlayerSmileHistory({
    required String playerId,
    int limit = 50,
    int offset = 0,
    DateTime? completedFrom,
    DateTime? completedThrough,
    SmileHistoryOrder order = SmileHistoryOrder.newestFirst,
  }) => Completer<List<HistoricalSmileRound>>().future;
}

class _ErrorRecordsRepository extends GameRecordsRepositoryImpl {
  _ErrorRecordsRepository(super.database);

  @override
  Future<List<HistoricalSmileRound>> getPlayerSmileHistory({
    required String playerId,
    int limit = 50,
    int offset = 0,
    DateTime? completedFrom,
    DateTime? completedThrough,
    SmileHistoryOrder order = SmileHistoryOrder.newestFirst,
  }) => Future.error(StateError('read failed'));
}

GameSessionRecord _record({
  required int id,
  required double average,
  required double peak,
}) => GameSessionRecord(
  playerId: '0123456789abcdef0123456789abcdef',
  playerName: 'Happy Panda',
  playerAvatar: '🥷',
  calibratedSmileAttempted: true,
  calibratedSmileSampleCount: 5,
  averageCalibratedSmileIntensity: average,
  peakCalibratedSmileIntensity: peak,
  calibratedSmileObservationSpanMs: 2000,
  id: id,
  score: 100,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: 1,
  catches: 1,
  accuracy: 1,
  smileScore: 0,
  startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
  endedAt: DateTime.now().subtract(const Duration(minutes: 1)),
  state: GameSessionState.results,
  isNewBest: false,
);
