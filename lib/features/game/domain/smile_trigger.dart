/// Detects one deliberate smile per neutral-to-smile cycle.
class SmileTrigger {
  SmileTrigger({
    this.threshold = .65,
    this.neutralThreshold = .35,
    this.stableDuration = const Duration(milliseconds: 150),
  });

  final double threshold;
  final double neutralThreshold;
  final Duration stableDuration;
  DateTime? _candidateSince;
  bool _waitingForNeutral = false;

  /// Returns true once when a valid smile has remained stable long enough.
  bool update(double? probability, DateTime now) {
    if (probability == null ||
        !probability.isFinite ||
        probability < 0 ||
        probability > 1) {
      _candidateSince = null;
      return false;
    }
    if (_waitingForNeutral) {
      if (probability <= neutralThreshold) _waitingForNeutral = false;
      return false;
    }
    if (probability < threshold) {
      _candidateSince = null;
      return false;
    }
    final start = _candidateSince ??= now;
    if (now.difference(start) < stableDuration) return false;
    _candidateSince = null;
    _waitingForNeutral = true;
    return true;
  }

  void reset() {
    _candidateSince = null;
    _waitingForNeutral = false;
  }
}
