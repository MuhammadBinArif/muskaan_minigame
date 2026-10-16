// Converts a `CameraImage` (from the `camera` plugin) into an
// `InputImage` for ML Kit.
//
// Kept as a standalone pure function so it can be unit-tested
// without launching ML Kit.

import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Build an ML Kit `InputImage` from a `CameraImage`.
///
/// Currently handles the NV21 layout (Android front camera with
/// `ImageFormatGroup.nv21`) and BGRA8888 (iOS).
///
/// Throws [ArgumentError] for unsupported image formats.
InputImage buildInputImage({
  required CameraImage image,
  required int rotationDegrees,
}) {
  final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
  if (rotation == null) {
    throw ArgumentError.value(
      rotationDegrees,
      'rotationDegrees',
      'must be one of 0, 90, 180, or 270',
    );
  }

  if (image.planes.length != 1) {
    throw ArgumentError(
      'ML Kit requires a single-plane NV21 buffer on Android or a '
      'single-plane BGRA8888 buffer on iOS; received '
      '${image.planes.length} planes.',
    );
  }

  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: _formatFor(image),
    bytesPerRow: image.planes.first.bytesPerRow,
  );

  return InputImage.fromBytes(
    bytes: image.planes.single.bytes,
    metadata: metadata,
  );
}

InputImageFormat _formatFor(CameraImage image) {
  // `CameraImage.format.group` distinguishes the layout the camera
  // plugin handed us.
  switch (image.format.group) {
    case ImageFormatGroup.nv21:
      return InputImageFormat.nv21;
    case ImageFormatGroup.yuv420:
      throw ArgumentError(
        'Multi-plane YUV420 is not accepted by ML Kit. Configure the Android '
        'camera controller with ImageFormatGroup.nv21.',
      );
    case ImageFormatGroup.bgra8888:
      return InputImageFormat.bgra8888;
    case ImageFormatGroup.jpeg:
      throw ArgumentError('JPEG frames are not supported by ML Kit.');
    case ImageFormatGroup.unknown:
      throw ArgumentError('Unknown CameraImage format.');
  }
}
