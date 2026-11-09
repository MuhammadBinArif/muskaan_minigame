import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/smile/domain/player_smile_analytics.dart';

void main() {
  const analytics = PlayerSmileAnalytics();
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  HistoricalSmileRound round({
    required int id,
    String playerId = playerA,
    double average = 50,
    double peak = 80,
    int count = 4,
    int span = 1000,
    int day = 1,
  }) => HistoricalSmileRound(
    resultId: id,
    playerId: playerId,
    averageIntensity: average,
    peakIntensity: peak,
    validObservationCount: count,
    observedSpan: Duration(milliseconds: span),
    completedAt: DateTime.utc(2026, 1, day),
  );

  test('personal bests report values and deterministic source rounds', () {
    final bests = analytics.personalBests([
      round(id: 2, average: 70, peak: 90, day: 2),
      round(id: 1, average: 70, peak: 85),
      round(id: 3, average: 60, peak: 90, day: 3),
    ]);
    expect(bests!.highestAverageIntensity, 70);
    expect(bests.bestByAverage.resultId, 1);
    expect(bests.highestPeakIntensity, 90);
    expect(bests.bestByPeak.resultId, 2);
    expect(analytics.personalBests(const []), isNull);
  });

  test('progress is average of round averages and deduplicates result IDs', () {
    final summary = analytics.progress([
      round(id: 1, average: 40, peak: 70),
      round(id: 1, average: 99, peak: 100),
      round(id: 2, average: 80, peak: 95, day: 4),
      round(id: 3, count: 0),
    ]);
    expect(summary!.eligibleRoundCount, 2);
    expect(summary.excludedInvalidCount, 1);
    expect(summary.averageOfRoundAverages, 60);
    expect(summary.highestPeakIntensity, 95);
    expect(summary.mostRecentRound.resultId, 2);
    expect(summary.firstMeasurementAt, DateTime.utc(2026, 1, 1));
    expect(summary.latestMeasurementAt, DateTime.utc(2026, 1, 4));
    expect(analytics.progress(const []), isNull);
  });

  test('comparison covers higher, lower, equal, and span/count', () {
    final comparison = analytics.compare(
      round(id: 1, average: 40, peak: 90, count: 5, span: 2000),
      round(id: 2, average: 60, peak: 80, count: 5, span: 3000),
    );
    expect(
      comparison.averageIntensity.direction,
      SmileComparisonDirection.higher,
    );
    expect(comparison.peakIntensity.direction, SmileComparisonDirection.lower);
    expect(
      comparison.validObservationCount.direction,
      SmileComparisonDirection.equal,
    );
    expect(
      comparison.observedSpanMilliseconds.direction,
      SmileComparisonDirection.higher,
    );
  });

  test('comparison rejects another player and invalid measurements', () {
    expect(
      () => analytics.compare(round(id: 1), round(id: 2, playerId: playerB)),
      throwsFormatException,
    );
    expect(
      () => analytics.compare(round(id: 1), round(id: 2, count: 0)),
      throwsFormatException,
    );
  });
}
