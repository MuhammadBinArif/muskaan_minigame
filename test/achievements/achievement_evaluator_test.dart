import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/achievements/domain/player_achievement.dart';

void main() {
  const evaluator = AchievementEvaluator();
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  GameSessionRecord record({
    required int id,
    String playerId = playerA,
    int catches = 1,
    int score = 100,
    int day = 1,
    double? average,
    double? peak,
    GameSessionState state = GameSessionState.results,
  }) => GameSessionRecord(
    playerId: playerId,
    playerName: 'Player',
    playerAvatar: '🥷',
    calibratedSmileAttempted: average != null,
    calibratedSmileSampleCount: average == null ? 0 : 5,
    averageCalibratedSmileIntensity: average,
    peakCalibratedSmileIntensity: peak,
    calibratedSmileObservationSpanMs: average == null ? null : 1000,
    id: id,
    score: score,
    livesLost: 0,
    maxLives: 3,
    timePlayed: 10,
    bestCombo: catches == 0 ? 0 : 1,
    catches: catches,
    accuracy: catches == 0 ? 0 : 1,
    smileScore: 0,
    startedAt: DateTime.utc(2026, 1, day, 10),
    endedAt: DateTime.utc(2026, 1, day, 11),
    state: state,
    isNewBest: false,
  );

  PlayerAchievementProgress progress(
    AchievementEvaluation evaluation,
    AchievementId id,
  ) => evaluation.progress.singleWhere((item) => item.definition.id == id);

  test('gameplay boundaries use only owned completed unique results', () {
    final records = [
      for (var id = 1; id <= 5; id++)
        record(id: id, score: id == 5 ? 1000 : 100),
      record(id: 5, score: 1000),
      record(id: 6, playerId: playerB, score: 5000),
      record(id: 7, state: GameSessionState.gameOver, score: 5000),
    ];
    final result = evaluator.evaluate(playerId: playerA, records: records);
    expect(progress(result, AchievementId.firstCatch).progress, 1);
    expect(progress(result, AchievementId.gettingStarted).progress, 5);
    expect(
      progress(result, AchievementId.gettingStarted).eligibleToUnlock,
      isTrue,
    );
    expect(progress(result, AchievementId.scoreMilestone).progress, 1000);
    expect(progress(result, AchievementId.dedicatedPlayer).isUnlocked, isFalse);
  });

  test('smile rules require genuine calibrated measurements', () {
    final result = evaluator.evaluate(
      playerId: playerA,
      records: [
        record(id: 1, average: 40, peak: 70),
        record(id: 2, average: 60, peak: 91),
        record(id: 3),
      ],
    );
    expect(progress(result, AchievementId.firstSmileMeasurement).progress, 1);
    expect(progress(result, AchievementId.highPeak).progress, 91);
    expect(progress(result, AchievementId.smileProgress).progress, 1);
    expect(progress(result, AchievementId.smileExplorer).progress, 2);
  });

  test('missing smile data is unavailable rather than zero progress', () {
    final result = evaluator.evaluate(
      playerId: playerA,
      records: [record(id: 1)],
    );
    expect(
      progress(result, AchievementId.firstSmileMeasurement).available,
      isFalse,
    );
    expect(progress(result, AchievementId.highPeak).available, isFalse);
  });

  test('personal best, comeback, and distinct-day rules are deterministic', () {
    final result = evaluator.evaluate(
      playerId: playerA,
      records: [
        record(id: 1, score: 300, day: 1),
        record(id: 2, score: 100, day: 2),
        record(id: 3, score: 400, day: 3),
      ],
    );
    expect(progress(result, AchievementId.personalBest).progress, 1);
    expect(progress(result, AchievementId.comeback).progress, 1);
    expect(progress(result, AchievementId.regularPlayer).progress, 3);
  });

  test('existing unlock is restored and not eligible twice', () {
    final unlock = AchievementUnlock(
      playerId: playerA,
      achievementId: AchievementId.firstCatch,
      unlockedAt: DateTime.utc(2026),
      sourceResultId: 1,
    );
    final result = evaluator.evaluate(
      playerId: playerA,
      records: [record(id: 1)],
      unlocks: [unlock],
    );
    final item = progress(result, AchievementId.firstCatch);
    expect(item.unlock, same(unlock));
    expect(
      result.eligibleToUnlock.where(
        (entry) => entry.definition.id == AchievementId.firstCatch,
      ),
      isEmpty,
    );
  });
}

extension on PlayerAchievementProgress {
  bool get eligibleToUnlock => available && progress >= definition.target;
}
