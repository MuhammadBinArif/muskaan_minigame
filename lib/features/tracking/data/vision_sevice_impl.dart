import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/mouth_geometry.dart';
import '../domain/vision_service.dart';
import 'input_image_converter.dart';
import '../domain/tracking_coordinates.dart';

/// Real implementation backed by Google ML Kit.
class VisionServiceImpl implements VisionService {
  VisionServiceImpl()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );

  final FaceDetector _detector;

  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    final input = buildInputImage(
      image: image,
      rotationDegrees: rotationDegrees,
    );

    final capturedAt = DateTime.now();
    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return VisionFrame.noFace();

    // Pick the largest face — closest to the camera.
    faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
    final face = faces.first;

    // ── Head-pose sanity check ──
    // If ML Kit populates Euler angles, verify they are within acceptable tilt.
    // If null, we proceed with landmark extraction rather than dropping the frame.
    final eulerX = face.headEulerAngleX;
    final eulerY = face.headEulerAngleY;
    if (eulerX != null && eulerY != null) {
      if (!MouthGeometry.isHeadPoseUsable(eulerX: eulerX, eulerY: eulerY)) {
        return VisionFrame.noFace();
      }
    }

    // ── Landmark extraction ──
    final bottom = face.landmarks[FaceLandmarkType.bottomMouth];
    final left = face.landmarks[FaceLandmarkType.leftMouth];
    final right = face.landmarks[FaceLandmarkType.rightMouth];

    if (bottom == null || left == null || right == null) {
      return VisionFrame.noFace();
    }

    // ML Kit's landmark positions are `Point<int>` — use `.x` / `.y`
    // (not `.dx` / `.dy`) and widen to `double` for the geometry math.
    final openness = MouthGeometry.openness(
      leftMouthX: left.position.x.toDouble(),
      leftMouthY: left.position.y.toDouble(),
      rightMouthX: right.position.x.toDouble(),
      rightMouthY: right.position.y.toDouble(),
      bottomMouthY: bottom.position.y.toDouble(),
      faceHeightPx: face.boundingBox.height,
    );

    if (openness == null) return VisionFrame.noFace();

    // Mouth centre in normalised [0,1] camera coordinates.
    // `int / int` yields `double` in Dart, so no explicit cast needed.
    final position = TrackingCoordinates.normalize(
      x: bottom.position.x.toDouble(),
      y: bottom.position.y.toDouble(),
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      rotationDegrees: rotationDegrees,
      mirrored: true,
    );

    return VisionFrame(
      rawOpenness: openness,
      mouthCenter: Offset(position.x, position.y),
      // ML Kit doesn't expose a per-face confidence score; when
      // landmarks are present we trust them.
      confidence: 1.0,
      faceDetected: true,
      capturedAt: capturedAt,
    );
  }

  @override
  Future<void> dispose() => _detector.close();
}
