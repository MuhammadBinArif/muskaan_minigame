import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:sqlite3/open.dart';

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late GameDatabase database;
  late GameRecordsRepository repository;

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  setUp(() {
    database = GameDatabase.forTesting(NativeDatabase.memory());
    repository = GameRecordsRepositoryImpl(database);
  });

  tearDown(() => database.close());

  GameSessionRecord measured({
    required int id,
    required String playerId,
    required int day,
    GameSessionState state = GameSessionState.results,
    double average = 50,
    double peak = 80,
  }) => GameSessionRecord(
    playerId: playerId,
    playerName: 'Player',
    playerAvatar: 'classic',
    calibratedSmileAttempted: true,
    calibratedSmileSampleCount: 5,
    averageCalibratedSmileIntensity: average,
    peakCalibratedSmileIntensity: peak,
    calibratedSmileObservationSpanMs: 1200,
    id: id,
    score: 100,
    livesLost: 0,
    maxLives: 3,
    timePlayed: 10,
    bestCombo: 1,
    catches: 1,
    accuracy: 1,
    smileScore: 92,
    startedAt: DateTime.utc(2026, 1, day, 10),
    endedAt: DateTime.utc(2026, 1, day, 11),
    state: state,
    isNewBest: false,
  );

  test(
    'SQLite history enforces player ownership and completed state',
    () async {
      await repository.saveSession(measured(id: 1, playerId: playerA, day: 1));
      await repository.saveSession(measured(id: 2, playerId: playerB, day: 2));
      await repository.saveSession(
        measured(
          id: 3,
          playerId: playerA,
          day: 3,
          state: GameSessionState.playing,
        ),
      );
      await repository.saveSession(measured(id: 4, playerId: playerA, day: 4));
      await database.customStatement(
        'UPDATE game_records SET player_id = NULL WHERE id = 4',
      );

      expect(
        (await repository.getPlayerSmileHistory(
          playerId: playerA,
        )).map((round) => round.resultId),
        [1],
      );
      expect(
        (await repository.getPlayerSmileHistory(
          playerId: playerB,
        )).single.resultId,
        2,
      );
    },
  );

  test('missing calibrated data and Touch-only records are excluded', () async {
    final legacy = measured(id: 1, playerId: playerA, day: 1);
    await repository.saveSession(legacy);
    await database.customStatement(
      'UPDATE session_details SET calibrated_smile_attempted = NULL, calibrated_smile_samples = NULL, calibrated_smile_average = NULL, calibrated_smile_peak = NULL, calibrated_smile_span_ms = NULL WHERE session_id = 1',
    );
    await repository.saveSession(
      GameSessionRecord(
        playerId: playerA,
        playerName: 'Player',
        playerAvatar: 'classic',
        calibratedSmileAttempted: false,
        calibratedSmileSampleCount: 0,
        id: 2,
        score: 100,
        livesLost: 0,
        maxLives: 3,
        timePlayed: 10,
        bestCombo: 1,
        catches: 1,
        accuracy: 1,
        smileScore: 100,
        smileSampleCount: 1,
        averageSmileProbability: .99,
        peakSmileProbability: .99,
        startedAt: DateTime.utc(2026, 1, 2),
        endedAt: DateTime.utc(2026, 1, 2, 1),
        state: GameSessionState.results,
        isNewBest: false,
      ),
    );
    expect(await repository.getPlayerSmileHistory(playerId: playerA), isEmpty);
  });

  test(
    'date range, chronological order, pagination, and retry are deterministic',
    () async {
      for (var day = 1; day <= 4; day++) {
        await repository.saveSession(
          measured(
            id: day,
            playerId: playerA,
            day: day,
            average: (day * 10).toDouble(),
          ),
        );
      }
      await repository.saveSession(
        measured(id: 2, playerId: playerA, day: 2, average: 20),
      );
      final page = await repository.getPlayerSmileHistory(
        playerId: playerA,
        completedFrom: DateTime.utc(2026, 1, 2),
        completedThrough: DateTime.utc(2026, 1, 4, 11),
        order: SmileHistoryOrder.oldestFirst,
        limit: 2,
        offset: 1,
      );
      expect(page.map((round) => round.resultId), [3, 4]);
      expect(
        await repository.getPlayerSmileHistory(playerId: playerA),
        hasLength(4),
      );
    },
  );
}
