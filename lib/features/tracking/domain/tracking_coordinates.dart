import 'dart:ui' show Offset;
import 'dart:math' as math;

/// Coordinates returned by ML Kit are already rotated into upright image space.
/// Normalize using the rotated dimensions, then mirror once for the front view.
class TrackingCoordinates {
  static ({double x, double y}) normalize({
    required double x,
    required double y,
    required double imageWidth,
    required double imageHeight,
    required int rotationDegrees,
    bool mirrored = true,
  }) {
    final dimensions = uprightDimensions(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      rotationDegrees: rotationDegrees,
    );
    final width = dimensions.width;
    final height = dimensions.height;
    if (width <= 0 || height <= 0 || !x.isFinite || !y.isFinite) {
      throw ArgumentError('Invalid tracking coordinates');
    }
    final nx = x / width;
    return (
      x: (mirrored ? 1 - nx : nx).clamp(0.0, 1.0),
      y: (y / height).clamp(0.0, 1.0),
    );
  }

  static ({double width, double height}) uprightDimensions({
    required double imageWidth,
    required double imageHeight,
    required int rotationDegrees,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('Image dimensions must be positive');
    }
    final normalizedRotation = rotationDegrees % 360;
    if (normalizedRotation != 0 &&
        normalizedRotation != 90 &&
        normalizedRotation != 180 &&
        normalizedRotation != 270) {
      throw ArgumentError('Rotation must be 0, 90, 180, or 270 degrees');
    }
    final quarterTurn = normalizedRotation % 180 != 0;
    return (
      width: quarterTurn ? imageHeight : imageWidth,
      height: quarterTurn ? imageWidth : imageHeight,
    );
  }

  /// Scale-independent face size: square root of face area / image area.
  static double normalizeFaceSize({
    required double faceWidth,
    required double faceHeight,
    required double imageWidth,
    required double imageHeight,
    required int rotationDegrees,
  }) {
    if (faceWidth < 0 || faceHeight < 0) {
      throw ArgumentError('Face dimensions cannot be negative');
    }
    final dimensions = uprightDimensions(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      rotationDegrees: rotationDegrees,
    );
    final ratio =
        (faceWidth * faceHeight) / (dimensions.width * dimensions.height);
    return math.sqrt(ratio).clamp(0.0, 1.0);
  }

  /// Maps normalized upright-image coordinates into a `BoxFit.cover` preview.
  /// Values can fall outside the viewport when the source is cropped.
  static Offset mapToCover({
    required Offset position,
    required double sourceWidth,
    required double sourceHeight,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        viewportWidth <= 0 ||
        viewportHeight <= 0) {
      throw ArgumentError('Preview dimensions must be positive');
    }
    final widthScale = viewportWidth / sourceWidth;
    final heightScale = viewportHeight / sourceHeight;
    final scale = widthScale > heightScale ? widthScale : heightScale;
    final renderedWidth = sourceWidth * scale;
    final renderedHeight = sourceHeight * scale;
    final cropX = (renderedWidth - viewportWidth) / 2;
    final cropY = (renderedHeight - viewportHeight) / 2;
    return Offset(
      position.dx * renderedWidth - cropX,
      position.dy * renderedHeight - cropY,
    );
  }
}
