import 'package:camera/camera.dart' show CameraImage;

import 'face_detection_result.dart';

abstract class FaceDetectionService {
  Future<FaceDetectionResult> process(
    CameraImage image, {
    required int rotationDegrees,
  });

  Future<void> dispose();
}
