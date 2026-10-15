// Per-player calibration data.
//
// Established during the calibration flow (Slice 4) and consumed by
// the state machine during gameplay.

class CalibrationConfig {
  /// Normalised raw openness at the player's mouth-closed baseline.
  final double closedBaseline;

  /// Normalised raw openness at the player's mouth-open threshold.
  final double openThreshold;

  /// Face confidence floor — results below this are ignored.
  final double faceConfidenceFloor;

  /// Whether the config has been calibrated by a real session.
  final bool calibrated;

  const CalibrationConfig({
    required this.closedBaseline,
    required this.openThreshold,
    this.faceConfidenceFloor = 0.4,
    this.calibrated = true,
  });

  /// A safe default used before the player has calibrated.
  /// Derived from typical ML Kit values across test subjects; the
  /// player should still run the calibration flow for reliable results.
  factory CalibrationConfig.defaults() => const CalibrationConfig(
    closedBaseline: 0.015,
    openThreshold: 0.055,
    calibrated: false,
  );

  /// Whether the config has valid, non-overlapping thresholds.
  bool get isValid =>
      openThreshold > closedBaseline &&
      closedBaseline >= 0.0 &&
      openThreshold <= 0.5;

  /// The deadband gap between close and open transitions. A wider
  /// band reduces flicker at the cost of responsiveness.
  double get deadband => openThreshold - closedBaseline;

  CalibrationConfig copyWith({
    double? closedBaseline,
    double? openThreshold,
    double? faceConfidenceFloor,
    bool? calibrated,
  }) => CalibrationConfig(
    closedBaseline: closedBaseline ?? this.closedBaseline,
    openThreshold: openThreshold ?? this.openThreshold,
    faceConfidenceFloor: faceConfidenceFloor ?? this.faceConfidenceFloor,
    calibrated: calibrated ?? this.calibrated,
  );

  @override
  String toString() =>
      'CalibrationConfig(closed: ${closedBaseline.toStringAsFixed(3)}, '
      'open: ${openThreshold.toStringAsFixed(3)}, '
      'calibrated: $calibrated)';
}
