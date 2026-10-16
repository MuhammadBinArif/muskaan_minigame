import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/mouth_geometry.dart';
import '../domain/face_tracking.dart';
import '../domain/vision_service.dart';
import 'input_image_converter.dart';
import '../domain/tracking_coordinates.dart';

/// Real implementation backed by Google ML Kit.
class VisionServiceImpl implements VisionService {
  VisionServiceImpl()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: false,
          enableContours: true,
          enableTracking: true,
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
    if (faces.length != 1) {
      return VisionFrame.noFace(now: capturedAt, faceCount: faces.length);
    }
    final face = faces.single;

    // ── Head-pose sanity check ──
    // If ML Kit populates Euler angles, verify they are within acceptable tilt.
    // If null, we proceed with landmark extraction rather than dropping the frame.
    final eulerX = face.headEulerAngleX;
    final eulerY = face.headEulerAngleY;
    if (eulerX != null && eulerY != null) {
      if (!MouthGeometry.isHeadPoseUsable(eulerX: eulerX, eulerY: eulerY)) {
        return VisionFrame.noFace(now: capturedAt, faceCount: 1);
      }
    }

    final faceCenter = TrackingCoordinates.normalize(
      x: face.boundingBox.center.dx,
      y: face.boundingBox.center.dy,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      rotationDegrees: rotationDegrees,
      mirrored: true,
    );
    final faceSize = TrackingCoordinates.normalizeFaceSize(
      faceWidth: face.boundingBox.width,
      faceHeight: face.boundingBox.height,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      rotationDegrees: rotationDegrees,
    );

    final upper = face.contours[FaceContourType.upperLipBottom]?.points;
    final lower = face.contours[FaceContourType.lowerLipTop]?.points;
    double? openness;
    Offset? mouthCenter;
    if (upper != null &&
        lower != null &&
        upper.isNotEmpty &&
        lower.isNotEmpty) {
      openness = MouthGeometry.contourOpenness(
        upperLipBottomY: upper.map((point) => point.y.toDouble()).toList(),
        lowerLipTopY: lower.map((point) => point.y.toDouble()).toList(),
        faceHeightPx: face.boundingBox.height,
      );
      final points = [...upper, ...lower];
      final centerX =
          points.fold<double>(0, (sum, point) => sum + point.x) / points.length;
      final centerY =
          points.fold<double>(0, (sum, point) => sum + point.y) / points.length;
      final normalizedMouth = TrackingCoordinates.normalize(
        x: centerX,
        y: centerY,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        rotationDegrees: rotationDegrees,
        mirrored: true,
      );
      mouthCenter = Offset(normalizedMouth.x, normalizedMouth.y);
    }

    return VisionFrame(
      observation: FaceTrackingObservation(
        faceDetected: true,
        faceCount: 1,
        facePosition: Offset(faceCenter.x, faceCenter.y),
        faceSize: faceSize,
        mouthPosition: mouthCenter,
        mouthOpenness: openness,
        capturedAt: capturedAt,
      ),
    );
  }

  @override
  Future<void> dispose() => _detector.close();
}
