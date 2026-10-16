import 'dart:ui' show Offset;

/// Lifecycle state for the stabilized on-device tracking signal.
enum FaceTrackingStatus { searching, tracking, temporarilyLost, lost }

/// One ML-Kit-agnostic observation produced from a camera frame.
///
/// Coordinates use the upright input-image space normalized to `[0, 1]`:
/// `(0, 0)` is preview top-left and `(1, 1)` is preview bottom-right. The
/// horizontal coordinate is mirrored once for the front camera so movement
/// follows the player's on-screen reflection.
class FaceTrackingObservation {
  final bool faceDetected;
  final int faceCount;
  final Offset? facePosition;
  final double? faceSize;
  final Offset? mouthPosition;
  final double? mouthOpenness;
  final DateTime capturedAt;

  const FaceTrackingObservation({
    required this.faceDetected,
    required this.faceCount,
    required this.facePosition,
    required this.faceSize,
    required this.mouthPosition,
    required this.mouthOpenness,
    required this.capturedAt,
  });

  factory FaceTrackingObservation.missing({
    required DateTime capturedAt,
    int faceCount = 0,
  }) => FaceTrackingObservation(
    faceDetected: false,
    faceCount: faceCount,
    facePosition: null,
    faceSize: null,
    mouthPosition: null,
    mouthOpenness: null,
    capturedAt: capturedAt,
  );

  bool get isUsable =>
      faceDetected &&
      faceCount == 1 &&
      facePosition != null &&
      faceSize != null;
}

/// Stable tracking output consumed by calibration and, later, Phase 3.4.
class StableFaceTracking {
  final FaceTrackingStatus status;
  final int faceCount;
  final Offset? position;
  final double? faceSize;
  final Offset? mouthPosition;
  final double? mouthOpenness;
  final DateTime? lastDetectedAt;
  final DateTime updatedAt;

  const StableFaceTracking({
    required this.status,
    required this.faceCount,
    required this.position,
    required this.faceSize,
    required this.mouthPosition,
    required this.mouthOpenness,
    required this.lastDetectedAt,
    required this.updatedAt,
  });

  factory StableFaceTracking.searching({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return StableFaceTracking(
      status: FaceTrackingStatus.searching,
      faceCount: 0,
      position: null,
      faceSize: null,
      mouthPosition: null,
      mouthOpenness: null,
      lastDetectedAt: null,
      updatedAt: timestamp,
    );
  }

  bool get isTracking => status == FaceTrackingStatus.tracking;
  bool get hasFreshCoordinates => isTracking && position != null;
}
