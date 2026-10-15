// Boundary between camera input and the tracking pipeline.
//
// The UI and the game depend on this interface only. The concrete
// implementation (ML Kit) lives in `data/`, and can be swapped for
// a fake in tests.

import 'dart:ui' show Offset;

import 'package:camera/camera.dart' show CameraImage;

/// One output frame from the vision service.
///
/// `rawOpenness` is the normalised openness BEFORE calibration
/// thresholds are applied — the state machine consumes it.
class VisionFrame {
  /// Raw (uncalibrated) openness in normalised units.
  /// `null` when no face or unusable face pose.
  final double? rawOpenness;

  /// Mouth centre in normalised [0,1] camera coordinates.
  /// `null` when no face.
  final Offset? mouthCenter;

  /// Face detection confidence in [0,1]. `0.0` when no face.
  final double confidence;

  /// True if a usable face was detected in this frame.
  final bool faceDetected;

  /// Server-side timestamp.
  final DateTime capturedAt;

  const VisionFrame({
    required this.rawOpenness,
    required this.mouthCenter,
    required this.confidence,
    required this.faceDetected,
    required this.capturedAt,
  });

  factory VisionFrame.noFace({DateTime? now}) => VisionFrame(
    rawOpenness: null,
    mouthCenter: null,
    confidence: 0.0,
    faceDetected: false,
    capturedAt: now ?? DateTime.now(),
  );
}

/// ML-Kit-agnostic face/mouth detection boundary.
abstract class VisionService {
  /// Process one camera frame.
  ///
  /// Never throws — always returns a frame; errors are logged and
  /// result in a `noFace` frame.
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
