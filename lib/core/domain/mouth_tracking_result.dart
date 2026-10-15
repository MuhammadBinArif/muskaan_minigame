// Domain model that crosses the camera/ML boundary.
//
// The Flame engine and game logic consume ONLY this type. Nothing
// downstream (game_session, gameplay_screen, flame components)
// may import camera, ML Kit, or any platform-specific type.

import 'dart:ui' show Offset;

/// A single snapshot of the player's mouth position and openness.
///
/// Produced by the vision layer at camera-frame rate (~30 Hz) and
/// consumed by the game input layer.
class MouthTrackingResult {
  /// Mouth centre in normalised [0,1] × [0,1] camera coordinates.
  /// The origin is top-left of the frame, matching Flutter's
  /// coordinate system after vertical flip on the front camera.
  final Offset normalizedPosition;

  /// Mouth openness in `[0, 1]`.
  ///
  /// 0 = fully closed (at the calibration baseline).
  /// 1 = fully open (at or above the calibrated open threshold).
  /// Values between are linearly interpolated.
  final double openness;

  /// Detector confidence in `[0, 1]`. Drop results below ~0.4.
  final double confidence;

  /// True when at least one face was detected and the landmarks
  /// used to compute [openness] were present.
  final bool faceDetected;

  /// True when the result is fresh (arrived within the last
  /// [staleAfter] window). Stale results must never trigger catches.
  final bool isFresh;

  /// Wall-clock timestamp for latency and staleness checks.
  final DateTime capturedAt;

  const MouthTrackingResult({
    required this.normalizedPosition,
    required this.openness,
    required this.confidence,
    required this.faceDetected,
    required this.isFresh,
    required this.capturedAt,
  });

  /// Neutral result used while the pipeline is warming up.
  factory MouthTrackingResult.empty() => MouthTrackingResult(
    normalizedPosition: const Offset(0.5, 0.5),
    openness: 0.0,
    confidence: 0.0,
    faceDetected: false,
    isFresh: false,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// A result older than this is treated as stale and cannot
  /// trigger gameplay events.
  static const Duration staleAfter = Duration(milliseconds: 200);

  /// Whether this result should be allowed to fire a mouth-open
  /// event, or contribute to scoring.
  bool get isActionable =>
      faceDetected &&
      isFresh &&
      confidence >= 0.4 &&
      DateTime.now().difference(capturedAt) < staleAfter;

  @override
  String toString() =>
      'MouthTrackingResult('
      'pos: ($normalizedPosition), '
      'open: ${openness.toStringAsFixed(2)}, '
      'conf: ${confidence.toStringAsFixed(2)}, '
      'detected: $faceDetected, '
      'fresh: $isFresh)';
}
