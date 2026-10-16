// Pure geometry for deriving mouth openness from ML Kit's three
// mouth landmarks. No ML Kit, no Flutter, no platform types.
//
// The ML Kit face detector exposes only three mouth-related
// landmarks:
//   - leftMouth   (left corner)
//   - rightMouth  (right corner)
//   - bottomMouth (bottom centre of lower lip)
//
// There is no upper-lip landmark. Openness is therefore derived
// from the vertical distance between the mouth's corner line and
// the lower-lip bottom, normalised by face bounding-box height so
// the value is invariant to camera distance and player size.

import 'dart:math' as math;

/// Result of a landmark measurement — still in the same units ML Kit
/// returned (pixels), before normalisation.
class RawMouthMeasurement {
  /// Raw opening in pixels.
  final double openingPx;

  /// The corner Y (average of left and right).
  final double cornerY;

  /// The bottom-lip Y.
  final double bottomY;

  /// Horizontal mouth width in pixels — useful for sanity checks
  /// (a face where the mouth width is zero is not trustworthy).
  final double mouthWidthPx;

  const RawMouthMeasurement({
    required this.openingPx,
    required this.cornerY,
    required this.bottomY,
    required this.mouthWidthPx,
  });
}

/// Stateless helpers for mouth geometry.
///
/// All methods are pure functions — they take primitives, return
/// primitives, and can be unit-tested with synthetic data.
class MouthGeometry {
  MouthGeometry._();

  /// Compute the raw (pre-normalisation) mouth opening from the
  /// three landmarks, in the same pixel units ML Kit provides.
  ///
  /// Returns `null` when the landmarks are degenerate (e.g. all
  /// three points on top of each other, which happens when a face
  /// is barely detected).
  static RawMouthMeasurement? computeRaw({
    required double leftMouthX,
    required double leftMouthY,
    required double rightMouthX,
    required double rightMouthY,
    required double bottomMouthY,
  }) {
    final cornerY = (leftMouthY + rightMouthY) / 2.0;
    final openingPx = bottomMouthY - cornerY;
    final mouthWidth = (rightMouthX - leftMouthX).abs();

    // Reject degenerate geometry — less than 2 px of mouth width
    // means the detector gave us noise.
    if (mouthWidth < 2.0) return null;

    // Reject impossible openings (bottom is above corners).
    if (openingPx < -1.0) return null;

    return RawMouthMeasurement(
      openingPx: openingPx.clamp(0.0, double.infinity),
      cornerY: cornerY,
      bottomY: bottomMouthY,
      mouthWidthPx: mouthWidth,
    );
  }

  /// Normalise a raw measurement by the face bounding-box height.
  ///
  /// The result is roughly `0.00` for a closed mouth and up to about
  /// `0.15` for a widely open mouth — but this varies per player,
  /// which is exactly what calibration handles.
  ///
  /// Returns `null` for degenerate face height.
  static double? normalize({
    required RawMouthMeasurement raw,
    required double faceHeightPx,
  }) {
    if (faceHeightPx < 20.0) return null; // too small to trust
    return raw.openingPx / faceHeightPx;
  }

  /// Convenience: raw compute + normalise in one call.
  static double? openness({
    required double leftMouthX,
    required double leftMouthY,
    required double rightMouthX,
    required double rightMouthY,
    required double bottomMouthY,
    required double faceHeightPx,
  }) {
    final raw = computeRaw(
      leftMouthX: leftMouthX,
      leftMouthY: leftMouthY,
      rightMouthX: rightMouthX,
      rightMouthY: rightMouthY,
      bottomMouthY: bottomMouthY,
    );
    if (raw == null) return null;
    return normalize(raw: raw, faceHeightPx: faceHeightPx);
  }

  /// Estimates the visible mouth aperture from ML Kit's lip contours.
  ///
  /// `upperLipBottom` and `lowerLipTop` are documented contour signals, not
  /// smile probabilities. The central third is used because lip corners
  /// normally meet even while the mouth is open. The pixel gap is normalized
  /// by face height to reduce sensitivity to camera distance.
  static double? contourOpenness({
    required List<double> upperLipBottomY,
    required List<double> lowerLipTopY,
    required double faceHeightPx,
  }) {
    if (faceHeightPx < 20 ||
        upperLipBottomY.length < 3 ||
        lowerLipTopY.length < 3) {
      return null;
    }
    final count = math.min(upperLipBottomY.length, lowerLipTopY.length);
    final start = count ~/ 3;
    final end = count - start;
    if (start >= end) return null;
    final gaps = <double>[];
    for (var i = start; i < end; i++) {
      final upper = upperLipBottomY[i];
      final lower = lowerLipTopY[i];
      if (!upper.isFinite || !lower.isFinite) return null;
      gaps.add(math.max(0, lower - upper));
    }
    gaps.sort();
    final median = gaps[gaps.length ~/ 2];
    final normalized = median / faceHeightPx;
    if (!normalized.isFinite || normalized > 0.5) return null;
    return normalized;
  }

  /// Reject faces with extreme tilt — past ~30° the landmark Y values
  /// are dominated by head rotation, not mouth motion.
  static bool isHeadPoseUsable({
    required double eulerX,
    required double eulerY,
  }) {
    const maxTiltDeg = 30.0;
    return eulerX.abs() <= maxTiltDeg && eulerY.abs() <= maxTiltDeg;
  }

  /// Smoothing helper — exponential moving average.
  ///
  /// `alpha = 0.4` is a good balance: responsive but not twitchy.
  static double ema({
    required double previous,
    required double next,
    double alpha = 0.4,
  }) {
    assert(alpha > 0 && alpha <= 1, 'alpha must be in (0, 1]');
    return previous * (1 - alpha) + next * alpha;
  }

  /// Clamp helper, occasionally useful when feeding into the state
  /// machine.
  static double clamp01(double v) => math.min(1.0, math.max(0.0, v));
}
