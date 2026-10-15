import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../tracking/data/input_image_converter.dart';
import '../domain/face_detection_result.dart';
import '../domain/face_detection_service.dart';

class MlKitFaceDetectionService implements FaceDetectionService {
  MlKitFaceDetectionService({FaceDetector? detector})
    : _detector =
          detector ??
          FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.fast,
              enableLandmarks: false,
              enableContours: false,
              enableClassification: false,
              enableTracking: true,
              minFaceSize: 0.15,
            ),
          );

  final FaceDetector _detector;
  bool _disposed = false;

  @override
  Future<FaceDetectionResult> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    if (_disposed) {
      throw StateError('Face detector has been disposed.');
    }

    final inputImage = buildInputImage(
      image: image,
      rotationDegrees: rotationDegrees,
    );
    final faces = await _detector.processImage(inputImage);
    return FaceDetectionResult(
      faces: faces
          .map((face) => DetectedFace(boundingBox: face.boundingBox))
          .toList(growable: false),
      processedAt: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _detector.close();
  }
}
