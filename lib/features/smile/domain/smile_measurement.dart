/// On-device smile probability calibration. It is not an emotion estimate.
class SmileCalibration {
  const SmileCalibration({
    required this.neutralProbability,
    required this.naturalSmileProbability,
  });
  final double neutralProbability;
  final double naturalSmileProbability;

  bool isValid({required double minimumSeparation}) =>
      minimumSeparation.isFinite &&
      minimumSeparation > 0 &&
      neutralProbability.isFinite &&
      naturalSmileProbability.isFinite &&
      neutralProbability >= 0 &&
      naturalSmileProbability <= 1 &&
      naturalSmileProbability - neutralProbability >= minimumSeparation;

  @override
  bool operator ==(Object other) =>
      other is SmileCalibration &&
      other.neutralProbability == neutralProbability &&
      other.naturalSmileProbability == naturalSmileProbability;
  @override
  int get hashCode => Object.hash(neutralProbability, naturalSmileProbability);
}

enum SmileUnavailableReason {
  missingProbability,
  invalidProbability,
  unreliableObservation,
  staleObservation,
  futureObservation,
  duplicateObservation,
  outOfOrderObservation,
  missingCalibration,
  invalidCalibration,
}

class SmileMeasurement {
  const SmileMeasurement({
    required this.capturedAt,
    required this.rawProbability,
    required this.smoothedProbability,
    required this.rawCalibratedIntensity,
    required this.smoothedCalibratedIntensity,
    this.intensityUnavailableReason,
  });
  final DateTime capturedAt;
  final double rawProbability;
  final double smoothedProbability;
  final double? rawCalibratedIntensity;
  final double? smoothedCalibratedIntensity;
  final SmileUnavailableReason? intensityUnavailableReason;
  double? get calibratedIntensity => smoothedCalibratedIntensity;
  int get rawPercent => (rawProbability * 100).round();
  int get smoothedPercent => (smoothedProbability * 100).round();
}

/// Constant-memory EMA. Invalid/unreliable input clears live smoothing.
class SmileMeasurementEngine {
  SmileMeasurementEngine({
    this.alpha = .35,
    this.maxAge = const Duration(milliseconds: 500),
    this.minimumCalibrationSeparation = .05,
    SmileCalibration? calibration,
  }) : _calibration = calibration {
    if (!alpha.isFinite || alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'Must be in (0, 1].');
    }
    if (maxAge <= Duration.zero) {
      throw ArgumentError.value(maxAge, 'maxAge', 'Must be positive.');
    }
    if (!minimumCalibrationSeparation.isFinite ||
        minimumCalibrationSeparation <= 0 ||
        minimumCalibrationSeparation > 1) {
      throw ArgumentError.value(
        minimumCalibrationSeparation,
        'minimumCalibrationSeparation',
      );
    }
  }

  final double alpha;
  final Duration maxAge;
  final double minimumCalibrationSeparation;
  DateTime? _lastSeen;
  double? _smoothedProbability;
  double? _smoothedIntensity;
  SmileCalibration? _calibration;
  SmileMeasurement? current;
  SmileUnavailableReason? lastUnavailableReason;
  SmileCalibration? get calibration => _calibration;

  void updateCalibration(SmileCalibration? value) {
    if (_calibration == value) return;
    _calibration = value;
    reset();
  }

  SmileMeasurement? observe(
    double? probability, {
    required DateTime capturedAt,
    required DateTime now,
    bool reliable = true,
    SmileCalibration? calibration,
  }) {
    if (calibration != null && calibration != _calibration) {
      updateCalibration(calibration);
    }
    final rejected = _validate(
      probability,
      capturedAt: capturedAt,
      now: now,
      reliable: reliable,
    );
    if (rejected != null) {
      lastUnavailableReason = rejected;
      if (rejected == SmileUnavailableReason.duplicateObservation ||
          rejected == SmileUnavailableReason.outOfOrderObservation) {
        if (current != null && now.difference(current!.capturedAt) > maxAge) {
          invalidate(reason: SmileUnavailableReason.staleObservation);
        }
      } else {
        invalidate(reason: rejected);
      }
      return null;
    }

    final rawProbability = probability!;
    if (_lastSeen != null && capturedAt.difference(_lastSeen!) > maxAge) {
      _smoothedProbability = null;
      _smoothedIntensity = null;
    }
    _lastSeen = capturedAt;
    _smoothedProbability =
        _smoothedProbability == null
            ? rawProbability
            : alpha * rawProbability + (1 - alpha) * _smoothedProbability!;
    final activeCalibration = _calibration;
    double? rawIntensity;
    SmileUnavailableReason? intensityReason;
    if (activeCalibration == null) {
      intensityReason = SmileUnavailableReason.missingCalibration;
      _smoothedIntensity = null;
    } else if (!activeCalibration.isValid(
      minimumSeparation: minimumCalibrationSeparation,
    )) {
      intensityReason = SmileUnavailableReason.invalidCalibration;
      _smoothedIntensity = null;
    } else {
      rawIntensity =
          (((rawProbability - activeCalibration.neutralProbability) /
                          (activeCalibration.naturalSmileProbability -
                              activeCalibration.neutralProbability))
                      .clamp(0.0, 1.0) *
                  100)
              .toDouble();
      _smoothedIntensity =
          _smoothedIntensity == null
              ? rawIntensity
              : alpha * rawIntensity + (1 - alpha) * _smoothedIntensity!;
    }
    lastUnavailableReason = intensityReason;
    return current = SmileMeasurement(
      capturedAt: capturedAt,
      rawProbability: rawProbability,
      smoothedProbability: _smoothedProbability!,
      rawCalibratedIntensity: rawIntensity,
      smoothedCalibratedIntensity: _smoothedIntensity,
      intensityUnavailableReason: intensityReason,
    );
  }

  SmileUnavailableReason? _validate(
    double? probability, {
    required DateTime capturedAt,
    required DateTime now,
    required bool reliable,
  }) {
    if (!reliable) return SmileUnavailableReason.unreliableObservation;
    if (probability == null) return SmileUnavailableReason.missingProbability;
    if (!probability.isFinite || probability < 0 || probability > 1) {
      return SmileUnavailableReason.invalidProbability;
    }
    final age = now.difference(capturedAt);
    if (age.isNegative) return SmileUnavailableReason.futureObservation;
    if (age > maxAge) return SmileUnavailableReason.staleObservation;
    if (_lastSeen != null && capturedAt == _lastSeen) {
      return SmileUnavailableReason.duplicateObservation;
    }
    if (_lastSeen != null && capturedAt.isBefore(_lastSeen!)) {
      return SmileUnavailableReason.outOfOrderObservation;
    }
    return null;
  }

  void invalidate({SmileUnavailableReason? reason}) {
    current = null;
    _smoothedProbability = null;
    _smoothedIntensity = null;
    if (reason != null) lastUnavailableReason = reason;
  }

  void reset() {
    current = null;
    _lastSeen = null;
    _smoothedProbability = null;
    _smoothedIntensity = null;
    lastUnavailableReason = null;
  }
}

class SmileRoundStatistics {
  const SmileRoundStatistics({
    required this.playerId,
    required this.roundId,
    required this.validObservationCount,
    required this.averageCalibratedIntensity,
    required this.peakCalibratedIntensity,
    required this.observationSpan,
  });
  final String playerId;
  final int roundId;
  final int validObservationCount;
  final double? averageCalibratedIntensity;
  final double? peakCalibratedIntensity;
  final Duration? observationSpan;
}

/// Bounded collector tied to exactly one player and one round.
class SmileRoundStatisticsCollector {
  SmileRoundStatisticsCollector({
    required this.playerId,
    required this.roundId,
    this.maxAge = const Duration(milliseconds: 500),
  }) {
    if (playerId.isEmpty) throw ArgumentError.value(playerId, 'playerId');
    if (roundId <= 0) throw ArgumentError.value(roundId, 'roundId');
  }
  final String playerId;
  final int roundId;
  final Duration maxAge;
  int _count = 0;
  double _sum = 0;
  double _peak = 0;
  DateTime? _first;
  DateTime? _last;

  bool add(SmileMeasurement measurement, {required DateTime now}) {
    final intensity = measurement.rawCalibratedIntensity;
    final age = now.difference(measurement.capturedAt);
    if (intensity == null ||
        !intensity.isFinite ||
        intensity < 0 ||
        intensity > 100 ||
        age.isNegative ||
        age > maxAge ||
        (_last != null && !measurement.capturedAt.isAfter(_last!))) {
      return false;
    }
    _first ??= measurement.capturedAt;
    _last = measurement.capturedAt;
    _count++;
    _sum += intensity;
    if (intensity > _peak) _peak = intensity;
    return true;
  }

  SmileRoundStatistics get statistics => SmileRoundStatistics(
    playerId: playerId,
    roundId: roundId,
    validObservationCount: _count,
    averageCalibratedIntensity: _count == 0 ? null : _sum / _count,
    peakCalibratedIntensity: _count == 0 ? null : _peak,
    observationSpan:
        _count == 0
            ? null
            : (_count == 1 ? Duration.zero : _last!.difference(_first!)),
  );
}
