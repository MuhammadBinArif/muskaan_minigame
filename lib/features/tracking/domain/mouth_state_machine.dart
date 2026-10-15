// Converts a stream of noisy raw openness values into a stable
// boolean "mouth is open" state, with hysteresis to prevent flicker.
//
// The state machine never emits the same transition twice — the
// caller sees a `MouthTransition` with `justOpened` or `justClosed`
// set exactly once per state change.

import 'calibration_config.dart';

/// Snapshot of the state machine after an `update()`.
class MouthTransition {
  /// True if the mouth is currently considered open.
  final bool isOpen;

  /// True on the frame the state changed from closed → open.
  final bool justOpened;

  /// True on the frame the state changed from open → closed.
  final bool justClosed;

  /// How long the mouth has been in its current state. Zero on the
  /// first frame after a change.
  final Duration currentStateDuration;

  /// The smoothed raw openness that produced this transition.
  final double smoothedOpenness;

  const MouthTransition({
    required this.isOpen,
    required this.justOpened,
    required this.justClosed,
    required this.currentStateDuration,
    required this.smoothedOpenness,
  });

  static const MouthTransition idle = MouthTransition(
    isOpen: false,
    justOpened: false,
    justClosed: false,
    currentStateDuration: Duration.zero,
    smoothedOpenness: 0.0,
  );
}

class MouthStateMachine {
  /// Current calibration. Can be swapped at runtime when calibration
  /// completes.
  CalibrationConfig config;

  /// Exponential moving average coefficient for raw openness.
  /// Lower = smoother but laggier. 0.4 is a good default at 15 Hz.
  double smoothingAlpha;

  /// Minimum time the mouth must stay open before `justClosed` can
  /// fire. Prevents sub-100 ms blips from producing catch events.
  Duration minimumOpenDuration;

  bool _isOpen = false;
  DateTime? _lastTransitionAt;
  double _smoothed = 0.0;
  bool _primed = false;

  MouthStateMachine({
    required this.config,
    this.smoothingAlpha = 0.4,
    this.minimumOpenDuration = const Duration(milliseconds: 100),
  });

  /// Feed a new raw openness value. Returns the transition state.
  ///
  /// [rawOpenness] should come from `MouthGeometry.openness()`.
  /// `null` values (face missing) should be handled by the caller —
  /// this method expects a real number.
  MouthTransition update(double rawOpenness, {DateTime? now}) {
    final t = now ?? DateTime.now();

    // Smoothing: first sample initialises directly, subsequent
    // samples are blended.
    if (!_primed) {
      _smoothed = rawOpenness;
      _primed = true;
    } else {
      _smoothed =
          _smoothed * (1 - smoothingAlpha) + rawOpenness * smoothingAlpha;
    }

    final wasOpen = _isOpen;
    bool justOpened = false;
    bool justClosed = false;

    if (_isOpen) {
      // Currently open — close when below the closed baseline and minimum open duration has passed.
      if (_smoothed <= config.closedBaseline) {
        final openFor =
            _lastTransitionAt == null
                ? Duration.zero
                : t.difference(_lastTransitionAt!);
        if (openFor >= minimumOpenDuration) {
          _isOpen = false;
          _lastTransitionAt = t;
          justClosed = true;
        }
      }
    } else {
      // Currently closed — open when above the open threshold.
      if (_smoothed >= config.openThreshold) {
        _isOpen = true;
        _lastTransitionAt = t;
        justOpened = true;
      }
    }

    final duration =
        _lastTransitionAt == null
            ? Duration.zero
            : t.difference(_lastTransitionAt!);

    return MouthTransition(
      isOpen: _isOpen,
      justOpened: justOpened && !wasOpen,
      justClosed: justClosed,
      currentStateDuration: duration,
      smoothedOpenness: _smoothed,
    );
  }

  /// Swap the calibration. Resets smoothing so old samples don't
  /// bleed into the new baseline.
  void updateConfig(CalibrationConfig next) {
    config = next;
    reset();
  }

  /// Force the machine into a known state — used after a
  /// calibration flow completes.
  void reset({bool open = false}) {
    _isOpen = open;
    _lastTransitionAt = null;
    _smoothed = 0.0;
    _primed = false;
  }

  /// Current state without feeding a new sample.
  bool get isOpen => _isOpen;
}
