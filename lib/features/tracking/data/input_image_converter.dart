// Converts a `CameraImage` (from the `camera` plugin) into an
// `InputImage` for ML Kit.
//
// Kept as a standalone pure function so it can be unit-tested
// without launching ML Kit.

import 'dart:typed_data';
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
  final rotation =
      InputImageRotationValue.fromRawValue(rotationDegrees) ??
      InputImageRotation.rotation0deg;

  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: _formatFor(image),
    bytesPerRow: image.planes.first.bytesPerRow,
  );

  // Concatenate all planes — needed for YUV layouts where ML Kit
  // expects a single NV21-style buffer.
  final bytes = _concatenatePlanes(image);

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}

InputImageFormat _formatFor(CameraImage image) {
  // `CameraImage.format.group` distinguishes the layout the camera
  // plugin handed us.
  switch (image.format.group) {
    case ImageFormatGroup.nv21:
      return InputImageFormat.nv21;
    case ImageFormatGroup.yuv420:
      return InputImageFormat.yuv420;
    case ImageFormatGroup.bgra8888:
      return InputImageFormat.bgra8888;
    case ImageFormatGroup.jpeg:
      throw ArgumentError('JPEG frames are not supported by ML Kit.');
    case ImageFormatGroup.unknown:
      throw ArgumentError('Unknown CameraImage format.');
  }
}

/// Concatenate the image planes into a single contiguous buffer.
///
/// For NV21 there is a single plane so this is a no-op. For YUV420
/// and BGRA8888 we join the planes end-to-end.
Uint8List _concatenatePlanes(CameraImage image) {
  if (image.planes.length == 1) {
    return image.planes[0].bytes;
  }
  final total = image.planes.fold<int>(0, (sum, p) => sum + p.bytes.length);
  final buffer = Uint8List(total);
  var offset = 0;
  for (final plane in image.planes) {
    buffer.setRange(offset, offset + plane.bytes.length, plane.bytes);
    offset += plane.bytes.length;
  }
  return buffer;
}
