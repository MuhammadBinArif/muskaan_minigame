import 'dart:math' as math;

/// Frame-rate independent, velocity-based movement from calibrated tilt angles.
class TiltMovement {
  TiltMovement({
    this.deadZoneDegrees = 3,
    this.maxTiltDegrees = 18,
    this.smoothingSeconds = .15,
    this.sensitivity = 1,
  });

  final double deadZoneDegrees;
  final double maxTiltDegrees;
  final double smoothingSeconds;
  final double sensitivity;
  double neutralDegrees = 0;
  double position = .5;
  double _filtered = 0;

  void calibrate(Iterable<double> samples) {
    final valid = samples.where((value) => value.isFinite).toList();
    if (valid.isEmpty) throw ArgumentError('No valid tilt samples');
    neutralDegrees = valid.reduce((a, b) => a + b) / valid.length;
    _filtered = 0;
    position = .5;
  }

  /// Reject incomplete or moving calibration samples before using their mean.
  bool calibrateStable(
    Iterable<double> samples, {
    int minimumSamples = 10,
    double maximumSpread = 6,
  }) {
    final valid = samples.where((value) => value.isFinite).toList();
    if (valid.length < minimumSamples) return false;
    final min = valid.reduce(math.min);
    final max = valid.reduce(math.max);
    if (max - min > maximumSpread) return false;
    calibrate(valid);
    return true;
  }

  double update(double angleDegrees, double dt) {
    if (!angleDegrees.isFinite || !dt.isFinite || dt <= 0) return position;
    final delta = (angleDegrees - neutralDegrees).clamp(
      -maxTiltDegrees,
      maxTiltDegrees,
    );
    final alpha = 1 - math.exp(-dt / smoothingSeconds);
    _filtered += (delta - _filtered) * alpha;
    final magnitude = ((_filtered.abs() - deadZoneDegrees) /
            (maxTiltDegrees - deadZoneDegrees))
        .clamp(0.0, 1.0);
    position = (position + _filtered.sign * magnitude * sensitivity * dt).clamp(
      .1,
      .9,
    );
    return position;
  }
}
