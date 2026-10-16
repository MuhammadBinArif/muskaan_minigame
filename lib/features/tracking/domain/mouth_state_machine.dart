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

  /// A threshold must remain crossed for this long before changing state.
  /// This prevents a single noisy frame from firing a transition.
  Duration minimumEvidenceDuration;

  bool _isOpen = false;
  DateTime? _lastTransitionAt;
  double _smoothed = 0.0;
  bool _primed = false;
  bool? _candidateOpen;
  DateTime? _candidateSince;

  MouthStateMachine({
    required this.config,
    this.smoothingAlpha = 0.4,
    this.minimumOpenDuration = const Duration(milliseconds: 100),
    this.minimumEvidenceDuration = const Duration(milliseconds: 70),
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

    final wantsOpen = !_isOpen && _smoothed >= config.openThreshold;
    final wantsClosed = _isOpen && _smoothed <= config.closedBaseline;
    final target = wantsOpen ? true : (wantsClosed ? false : null);
    if (target == null) {
      _candidateOpen = null;
      _candidateSince = null;
    } else if (_candidateOpen != target) {
      _candidateOpen = target;
      _candidateSince = t;
      final openFor =
          _lastTransitionAt == null
              ? Duration.zero
              : t.difference(_lastTransitionAt!);
      final canClose = target || openFor >= minimumOpenDuration;
      if (minimumEvidenceDuration == Duration.zero && canClose) {
        _isOpen = target;
        _lastTransitionAt = t;
        justOpened = target;
        justClosed = !target;
        _candidateOpen = null;
        _candidateSince = null;
      }
    } else {
      final evidenceFor = t.difference(_candidateSince!);
      final openFor =
          _lastTransitionAt == null
              ? Duration.zero
              : t.difference(_lastTransitionAt!);
      final canClose = target || openFor >= minimumOpenDuration;
      if (evidenceFor >= minimumEvidenceDuration && canClose) {
        _isOpen = target;
        _lastTransitionAt = t;
        justOpened = target;
        justClosed = !target;
        _candidateOpen = null;
        _candidateSince = null;
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
    _candidateOpen = null;
    _candidateSince = null;
  }

  /// Current state without feeding a new sample.
  bool get isOpen => _isOpen;
}
