// Boundary between camera input and the tracking pipeline.
//
// The UI and the game depend on this interface only. The concrete
// implementation (ML Kit) lives in `data/`, and can be swapped for
// a fake in tests.

import 'dart:ui' show Offset;

import 'package:camera/camera.dart' show CameraImage;

import 'face_tracking.dart';

/// One output frame from the vision service.
///
/// `rawOpenness` is the normalised openness BEFORE calibration
/// thresholds are applied — the state machine consumes it.
class VisionFrame {
  final FaceTrackingObservation observation;

  const VisionFrame({required this.observation});

  factory VisionFrame.noFace({DateTime? now, int faceCount = 0}) => VisionFrame(
    observation: FaceTrackingObservation.missing(
      capturedAt: now ?? DateTime.now(),
      faceCount: faceCount,
    ),
  );

  double? get rawOpenness => observation.mouthOpenness;
  Offset? get mouthCenter => observation.mouthPosition;
  Offset? get faceCenter => observation.facePosition;
  double? get faceSize => observation.faceSize;
  bool get faceDetected => observation.faceDetected;
  int get faceCount => observation.faceCount;
  DateTime get capturedAt => observation.capturedAt;
}

/// ML-Kit-agnostic face/mouth detection boundary.
abstract class VisionService {
  /// Process one camera frame.
  ///
  /// Returns noFace for valid frames without a usable face.
  /// Processing/configuration errors propagate to camera diagnostics.
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  });

  /// Release the underlying detector. Must be called before disposal.
  Future<void> dispose();
}

/// Pass-through implementation used as a placeholder before the real
/// camera is wired up. Every frame is "no face" — useful for tests
/// that just want a valid service.
class NullVisionService implements VisionService {
  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async => VisionFrame.noFace();

  @override
  Future<void> dispose() async {}
}
