/// A persisted, calibrated smile measurement summary for one completed round.
class HistoricalSmileRound {
  final int resultId;
  final String playerId;
  final double averageIntensity;
  final double peakIntensity;
  final int validObservationCount;
  final Duration observedSpan;
  final DateTime completedAt;

  const HistoricalSmileRound({
    required this.resultId,
    required this.playerId,
    required this.averageIntensity,
    required this.peakIntensity,
    required this.validObservationCount,
    required this.observedSpan,
    required this.completedAt,
  });

  bool get isValid =>
      resultId > 0 &&
      playerId.isNotEmpty &&
      averageIntensity.isFinite &&
      peakIntensity.isFinite &&
      averageIntensity >= 0 &&
      averageIntensity <= peakIntensity &&
      peakIntensity <= 100 &&
      validObservationCount > 0 &&
      !observedSpan.isNegative;
}

class SmilePersonalBests {
  final HistoricalSmileRound bestByAverage;
  final HistoricalSmileRound bestByPeak;

  const SmilePersonalBests({
    required this.bestByAverage,
    required this.bestByPeak,
  });

  double get highestAverageIntensity => bestByAverage.averageIntensity;
  double get highestPeakIntensity => bestByPeak.peakIntensity;
}

class SmileProgressSummary {
  final int eligibleRoundCount;
  final int excludedInvalidCount;

  /// Each eligible round has equal weight, regardless of observation count.
  final double averageOfRoundAverages;
  final double highestPeakIntensity;
  final HistoricalSmileRound mostRecentRound;
  final DateTime firstMeasurementAt;
  final DateTime latestMeasurementAt;

  const SmileProgressSummary({
    required this.eligibleRoundCount,
    required this.excludedInvalidCount,
    required this.averageOfRoundAverages,
    required this.highestPeakIntensity,
    required this.mostRecentRound,
    required this.firstMeasurementAt,
    required this.latestMeasurementAt,
  });
}

enum SmileComparisonDirection { lower, equal, higher }

class SmileMetricComparison<T extends num> {
  final T first;
  final T second;
  final SmileComparisonDirection direction;

  const SmileMetricComparison(this.first, this.second, this.direction);
}

class SmileRoundComparison {
  final int firstResultId;
  final int secondResultId;
  final SmileMetricComparison<double> averageIntensity;
  final SmileMetricComparison<double> peakIntensity;
  final SmileMetricComparison<int> validObservationCount;
  final SmileMetricComparison<int> observedSpanMilliseconds;

  const SmileRoundComparison({
    required this.firstResultId,
    required this.secondResultId,
    required this.averageIntensity,
    required this.peakIntensity,
    required this.validObservationCount,
    required this.observedSpanMilliseconds,
  });
}

/// Pure deterministic aggregation over repository-filtered persisted rounds.
class PlayerSmileAnalytics {
  const PlayerSmileAnalytics();

  SmilePersonalBests? personalBests(Iterable<HistoricalSmileRound> rounds) {
    final eligible = _uniqueValid(rounds);
    if (eligible.isEmpty) return null;
    return SmilePersonalBests(
      bestByAverage: _best(eligible, (round) => round.averageIntensity),
      bestByPeak: _best(eligible, (round) => round.peakIntensity),
    );
  }

  SmileProgressSummary? progress(Iterable<HistoricalSmileRound> rounds) {
    final source = rounds.toList(growable: false);
    final eligible = _uniqueValid(source);
    if (eligible.isEmpty) return null;
    eligible.sort(_chronological);
    final average =
        eligible.fold<double>(0, (sum, r) => sum + r.averageIntensity) /
        eligible.length;
    final highestPeak = eligible
        .map((round) => round.peakIntensity)
        .reduce((a, b) => a > b ? a : b);
    return SmileProgressSummary(
      eligibleRoundCount: eligible.length,
      excludedInvalidCount: source.where((round) => !round.isValid).length,
      averageOfRoundAverages: average,
      highestPeakIntensity: highestPeak,
      mostRecentRound: eligible.last,
      firstMeasurementAt: eligible.first.completedAt,
      latestMeasurementAt: eligible.last.completedAt,
    );
  }

  SmileRoundComparison compare(
    HistoricalSmileRound first,
    HistoricalSmileRound second,
  ) {
    if (!first.isValid || !second.isValid) {
      throw const FormatException(
        'Both rounds require valid smile measurements.',
      );
    }
    if (first.playerId != second.playerId) {
      throw const FormatException('Rounds must belong to the same player.');
    }
    return SmileRoundComparison(
      firstResultId: first.resultId,
      secondResultId: second.resultId,
      averageIntensity: _compare(
        first.averageIntensity,
        second.averageIntensity,
      ),
      peakIntensity: _compare(first.peakIntensity, second.peakIntensity),
      validObservationCount: _compare(
        first.validObservationCount,
        second.validObservationCount,
      ),
      observedSpanMilliseconds: _compare(
        first.observedSpan.inMilliseconds,
        second.observedSpan.inMilliseconds,
      ),
    );
  }

  List<HistoricalSmileRound> _uniqueValid(
    Iterable<HistoricalSmileRound> rounds,
  ) {
    final byResult = <int, HistoricalSmileRound>{};
    for (final round in rounds) {
      if (round.isValid) byResult.putIfAbsent(round.resultId, () => round);
    }
    return byResult.values.toList();
  }

  HistoricalSmileRound _best(
    List<HistoricalSmileRound> rounds,
    double Function(HistoricalSmileRound) value,
  ) {
    return rounds.reduce((best, candidate) {
      final comparison = value(candidate).compareTo(value(best));
      if (comparison > 0) return candidate;
      if (comparison < 0) return best;
      // Stable tie break: earliest persisted completion, then smallest ID.
      return _chronological(candidate, best) < 0 ? candidate : best;
    });
  }

  int _chronological(HistoricalSmileRound a, HistoricalSmileRound b) {
    final byTime = a.completedAt.compareTo(b.completedAt);
    return byTime != 0 ? byTime : a.resultId.compareTo(b.resultId);
  }

  SmileMetricComparison<T> _compare<T extends num>(T first, T second) {
    final direction =
        second > first
            ? SmileComparisonDirection.higher
            : second < first
            ? SmileComparisonDirection.lower
            : SmileComparisonDirection.equal;
    return SmileMetricComparison(first, second, direction);
  }
}
