import 'dart:math' as math;

/// Tracking states understood by gameplay. This contract deliberately contains
/// no camera, ML Kit, or Flame types.
enum FaceGameControlStatus {
  searching,
  tracking,
  temporarilyLost,
  lost,
  unavailable,
  paused,
}

class FaceGameControlSample {
  const FaceGameControlSample({
    required this.normalizedX,
    required this.status,
    required this.observedAt,
  });

  final double? normalizedX;
  final FaceGameControlStatus status;
  final DateTime observedAt;

  bool get isValid =>
      status == FaceGameControlStatus.tracking &&
      normalizedX != null &&
      normalizedX!.isFinite &&
      normalizedX! >= 0 &&
      normalizedX! <= 1;
}

class FaceGameControlConfig {
  const FaceGameControlConfig({
    required this.neutralX,
    required this.horizontalRange,
    this.sensitivity = 1,
    this.responsePerSecond = 10,
    this.minimumTargetX = 0.1,
    this.maximumTargetX = 0.9,
    this.staleAfter = const Duration(milliseconds: 250),
    this.lostAfter = const Duration(milliseconds: 650),
  }) : assert(neutralX >= 0 && neutralX <= 1),
       assert(horizontalRange > 0 && horizontalRange <= 0.5),
       assert(sensitivity > 0),
       assert(responsePerSecond > 0),
       assert(minimumTargetX >= 0),
       assert(maximumTargetX <= 1),
       assert(minimumTargetX < maximumTargetX);

  final double neutralX;

  /// Face movement from neutral required to reach either edge.
  final double horizontalRange;
  final double sensitivity;

  /// Exponential response rate. The resulting smoothing is frame-rate
  /// independent because [FaceGameControl.update] uses elapsed seconds.
  final double responsePerSecond;
  final double minimumTargetX;
  final double maximumTargetX;
  final Duration staleAfter;
  final Duration lostAfter;
}

/// Converts normalized mirrored face coordinates into stable gameplay input.
class FaceGameControl {
  FaceGameControl({required this.config})
    : assert(config.lostAfter >= config.staleAfter);

  FaceGameControlConfig config;
  double _currentX = 0.5;
  double _targetX = 0.5;
  DateTime? _lastValidObservation;
  FaceGameControlStatus _status = FaceGameControlStatus.searching;
  bool _paused = false;

  double get currentX => _currentX;
  double get targetX => _targetX;
  FaceGameControlStatus get status => _status;
  bool get isActionable => _status == FaceGameControlStatus.tracking;

  void configure(FaceGameControlConfig next) {
    config = next;
    reset();
  }

  void ingest(FaceGameControlSample sample, {DateTime? now}) {
    if (_paused) return;
    final timestamp = now ?? DateTime.now();
    final age = timestamp.difference(sample.observedAt);
    if (sample.isValid && !age.isNegative && age <= config.staleAfter) {
      _targetX = mapNormalizedX(sample.normalizedX!);
      _lastValidObservation = sample.observedAt;
      _status = FaceGameControlStatus.tracking;
      return;
    }

    _status = switch (sample.status) {
      FaceGameControlStatus.temporarilyLost =>
        FaceGameControlStatus.temporarilyLost,
      FaceGameControlStatus.unavailable => FaceGameControlStatus.unavailable,
      FaceGameControlStatus.paused => FaceGameControlStatus.paused,
      FaceGameControlStatus.searching => FaceGameControlStatus.searching,
      _ => FaceGameControlStatus.lost,
    };
  }

  double mapNormalizedX(double normalizedX) {
    if (!normalizedX.isFinite) {
      throw ArgumentError.value(normalizedX, 'normalizedX');
    }
    final displacement =
        (normalizedX - config.neutralX) /
        config.horizontalRange *
        config.sensitivity;
    return (0.5 + displacement * 0.5).clamp(
      config.minimumTargetX,
      config.maximumTargetX,
    );
  }

  double worldX({required double worldWidth, required double targetRadius}) {
    if (!worldWidth.isFinite ||
        !targetRadius.isFinite ||
        worldWidth <= 0 ||
        targetRadius < 0 ||
        targetRadius * 2 > worldWidth) {
      throw ArgumentError('Invalid game-world dimensions');
    }
    return (_currentX * worldWidth).clamp(
      targetRadius,
      worldWidth - targetRadius,
    );
  }

  void update(double dt, {DateTime? now}) {
    if (_paused || dt <= 0 || !dt.isFinite) return;
    final timestamp = now ?? DateTime.now();
    final lastValid = _lastValidObservation;
    if (lastValid != null) {
      final age = timestamp.difference(lastValid);
      if (age.isNegative || age > config.lostAfter) {
        _status = FaceGameControlStatus.lost;
      } else if (age > config.staleAfter) {
        _status = FaceGameControlStatus.temporarilyLost;
      }
    }

    // Freeze immediately whenever input is invalid. The grace state is useful
    // feedback, but it never keeps extrapolating an old observation.
    if (_status != FaceGameControlStatus.tracking) return;
    final alpha = 1 - math.exp(-config.responsePerSecond * dt);
    _currentX += (_targetX - _currentX) * alpha;
    _currentX = _currentX.clamp(config.minimumTargetX, config.maximumTargetX);
  }

  void pause() {
    _paused = true;
    _lastValidObservation = null;
    _status = FaceGameControlStatus.paused;
  }

  void resume() {
    _paused = false;
    _lastValidObservation = null;
    _targetX = _currentX;
    _status = FaceGameControlStatus.searching;
  }

  void reset() {
    _paused = false;
    _currentX = 0.5;
    _targetX = 0.5;
    _lastValidObservation = null;
    _status = FaceGameControlStatus.searching;
  }
}
