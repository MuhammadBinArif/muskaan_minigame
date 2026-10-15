import 'dart:ui' show Rect;

class DetectedFace {
  final Rect boundingBox;

  const DetectedFace({required this.boundingBox});
}

class FaceDetectionResult {
  final List<DetectedFace> faces;
  final DateTime processedAt;

  const FaceDetectionResult({required this.faces, required this.processedAt});

  int get faceCount => faces.length;

  factory FaceDetectionResult.empty({DateTime? now}) =>
      FaceDetectionResult(faces: const [], processedAt: now ?? DateTime.now());
}
