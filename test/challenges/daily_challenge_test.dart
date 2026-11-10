import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/challenges/domain/daily_challenge.dart';

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const generator = DailyChallengeGenerator();
  const evaluator = DailyChallengeEvaluator();

  test('daily generation is stable, player-specific, and smile-aware', () {
    final first = generator.generate(
      playerId: playerA,
      dateKey: '2026-11-09',
      smileDataAvailable: false,
    );
    final restart = generator.generate(
      playerId: playerA,
      dateKey: '2026-11-09',
      smileDataAvailable: false,
    );
    final otherPlayer = generator.generate(
      playerId: playerB,
      dateKey: '2026-11-09',
      smileDataAvailable: false,
    );
    expect(first, restart);
    expect(otherPlayer, hasLength(3));
    expect(
      first.map(
        (id) =>
            dailyChallengeDefinitions
                .singleWhere((item) => item.id == id)
                .requiresSmileData,
      ),
      everyElement(isFalse),
    );
  });

  test('date keys respect explicit offsets at midnight', () {
    final instant = DateTime.utc(2026, 11, 8, 20);
    expect(dateKeyFor(instant, 300), '2026-11-09');
    expect(dateKeyFor(instant, -300), '2026-11-08');
  });

  test(
    'all gameplay, smile, and mode progress uses verified unique results',
    () {
      final assignments = [
        for (final id in DailyChallengeId.values)
          DailyChallengeAssignment(
            playerId: playerA,
            dateKey: '2026-11-09',
            challengeId: id,
            timezoneOffsetMinutes: 300,
            assignedAt: DateTime.utc(2026, 11, 9),
          ),
      ];
      final records = [
        _record(
          1,
          playerA,
          DateTime.utc(2026, 11, 8, 20),
          score: 400,
          catches: 2,
          smile: true,
          samples: 12,
          peak: 70,
          smileMode: true,
        ),
        _record(
          2,
          playerA,
          DateTime.utc(2026, 11, 9, 2),
          score: 600,
          catches: 6,
          smile: true,
          samples: 10,
          peak: 85,
          touchMode: true,
        ),
        _record(
          2,
          playerA,
          DateTime.utc(2026, 11, 9, 2),
          score: 600,
          catches: 6,
          smile: true,
          samples: 10,
          peak: 85,
          touchMode: true,
        ),
        _record(
          3,
          playerB,
          DateTime.utc(2026, 11, 9, 3),
          score: 9999,
          catches: 99,
        ),
        _record(
          4,
          playerA,
          DateTime.utc(2026, 11, 9, 4),
          score: 9999,
          catches: 99,
          state: GameSessionState.gameOver,
        ),
      ];
      final result = evaluator.evaluate(
        playerId: playerA,
        assignments: assignments,
        records: records,
      );
      DailyChallengeProgress item(DailyChallengeId id) =>
          result.singleWhere((value) => value.definition.id == id);
      expect(item(DailyChallengeId.completeOneRound).progress, 2);
      expect(item(DailyChallengeId.scoreTarget).progress, 600);
      expect(item(DailyChallengeId.catchesTarget).progress, 6);
      expect(item(DailyChallengeId.measuredRound).isComplete, isTrue);
      expect(item(DailyChallengeId.validObservations).progress, 22);
      expect(item(DailyChallengeId.calibratedPeak).progress, 85);
      expect(item(DailyChallengeId.bothModes).progress, 2);
    },
  );

  test('missing smile data is unavailable and progress is bounded', () {
    final assignment = DailyChallengeAssignment(
      playerId: playerA,
      dateKey: '2026-11-09',
      challengeId: DailyChallengeId.calibratedPeak,
      timezoneOffsetMinutes: 0,
      assignedAt: DateTime.utc(2026, 11, 9),
    );
    final result =
        evaluator
            .evaluate(
              playerId: playerA,
              assignments: [assignment],
              records: [
                _record(1, playerA, DateTime.utc(2026, 11, 9), score: 1000),
              ],
            )
            .single;
    expect(result.available, isFalse);
    expect(result.boundedProgress, 0);
  });

  test('personal best challenge requires earlier verified evidence', () {
    final assignment = DailyChallengeAssignment(
      playerId: playerA,
      dateKey: '2026-11-09',
      challengeId: DailyChallengeId.beatPersonalBest,
      timezoneOffsetMinutes: 0,
      assignedAt: DateTime.utc(2026, 11, 9),
    );
    final result =
        evaluator
            .evaluate(
              playerId: playerA,
              assignments: [assignment],
              records: [
                _record(1, playerA, DateTime.utc(2026, 11, 8, 12), score: 500),
                _record(2, playerA, DateTime.utc(2026, 11, 9, 12), score: 600),
              ],
            )
            .single;
    expect(result.isComplete, isTrue);
  });

  group('streaks', () {
    const calculator = StreakCalculator();
    test('same-day duplicates count once and consecutive days grow streak', () {
      final result = calculator.calculate(
        playerId: playerA,
        effectiveTodayKey: '2026-11-09',
        records: [
          _record(1, playerA, DateTime.utc(2026, 11, 7, 12)),
          _record(2, playerA, DateTime.utc(2026, 11, 8, 12)),
          _record(3, playerA, DateTime.utc(2026, 11, 8, 14)),
          _record(4, playerA, DateTime.utc(2026, 11, 9, 0)),
        ],
      );
      expect(result.current, 3);
      expect(result.longest, 3);
      expect(result.activeDayCount, 3);
    });
    test('missing day resets current but preserves historical longest', () {
      final result = calculator.calculate(
        playerId: playerA,
        effectiveTodayKey: '2026-11-12',
        records: [
          _record(1, playerA, DateTime.utc(2026, 11, 7)),
          _record(2, playerA, DateTime.utc(2026, 11, 8)),
          _record(3, playerA, DateTime.utc(2026, 11, 10)),
        ],
      );
      expect(result.current, 0);
      expect(result.longest, 2);
    });
  });
}

GameSessionRecord _record(
  int id,
  String playerId,
  DateTime endedAt, {
  int score = 0,
  int catches = 0,
  bool smile = false,
  int samples = 0,
  double peak = 0,
  bool smileMode = false,
  bool touchMode = false,
  GameSessionState state = GameSessionState.results,
}) => GameSessionRecord(
  playerId: playerId,
  playerName: 'Player',
  playerAvatar: '🥷',
  calibratedSmileAttempted: smile,
  calibratedSmileSampleCount: smile ? samples : 0,
  averageCalibratedSmileIntensity: smile ? peak / 2 : null,
  peakCalibratedSmileIntensity: smile ? peak : null,
  calibratedSmileObservationSpanMs: smile ? 1000 : null,
  usedSmileMode: smileMode,
  usedTouchMode: touchMode,
  completionTimezoneOffsetMinutes: null,
  id: id,
  score: score,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: catches,
  catches: catches,
  accuracy: catches == 0 ? 0 : 1,
  smileScore: 0,
  startedAt: endedAt.subtract(const Duration(minutes: 1)),
  endedAt: endedAt,
  state: state,
  isNewBest: false,
);
