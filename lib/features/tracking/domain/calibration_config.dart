// Per-player calibration data.
//
// Established during the calibration flow (Slice 4) and consumed by
// the state machine during gameplay.

import 'dart:ui' show Offset;

class CalibrationConfig {
  /// Normalised raw openness at the player's mouth-closed baseline.
  final double closedBaseline;

  /// Normalised raw openness at the player's mouth-open threshold.
  final double openThreshold;

  /// Smoothed neutral face centre in mirrored normalized coordinates.
  final Offset neutralFacePosition;

  /// Normalized face size at the neutral calibration pose.
  final double neutralFaceSize;

  /// Horizontal face movement from neutral used to reach a gameplay edge.
  final double horizontalControlRange;

  /// Whether the config has been calibrated by a real session.
  final bool calibrated;

  const CalibrationConfig({
    required this.closedBaseline,
    required this.openThreshold,
    this.neutralFacePosition = const Offset(0.5, 0.5),
    this.neutralFaceSize = 0,
    this.horizontalControlRange = 0.22,
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
      openThreshold <= 0.5 &&
      neutralFacePosition.dx.isFinite &&
      neutralFacePosition.dy.isFinite &&
      neutralFacePosition.dx >= 0.0 &&
      neutralFacePosition.dx <= 1.0 &&
      neutralFacePosition.dy >= 0.0 &&
      neutralFacePosition.dy <= 1.0 &&
      neutralFaceSize.isFinite &&
      neutralFaceSize >= 0.0 &&
      neutralFaceSize <= 1.0 &&
      horizontalControlRange.isFinite &&
      horizontalControlRange >= 0.08 &&
      horizontalControlRange <= 0.5;

  /// The deadband gap between close and open transitions. A wider
  /// band reduces flicker at the cost of responsiveness.
  double get deadband => openThreshold - closedBaseline;

  CalibrationConfig copyWith({
    double? closedBaseline,
    double? openThreshold,
    Offset? neutralFacePosition,
    double? neutralFaceSize,
    double? horizontalControlRange,
    bool? calibrated,
  }) => CalibrationConfig(
    closedBaseline: closedBaseline ?? this.closedBaseline,
    openThreshold: openThreshold ?? this.openThreshold,
    neutralFacePosition: neutralFacePosition ?? this.neutralFacePosition,
    neutralFaceSize: neutralFaceSize ?? this.neutralFaceSize,
    horizontalControlRange:
        horizontalControlRange ?? this.horizontalControlRange,
    calibrated: calibrated ?? this.calibrated,
  );

  @override
  String toString() =>
      'CalibrationConfig(closed: ${closedBaseline.toStringAsFixed(3)}, '
      'open: ${openThreshold.toStringAsFixed(3)}, '
      'calibrated: $calibrated)';
}
