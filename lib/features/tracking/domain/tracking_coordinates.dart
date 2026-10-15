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
    final quarterTurn = rotationDegrees % 180 != 0;
    final width = quarterTurn ? imageHeight : imageWidth;
    final height = quarterTurn ? imageWidth : imageHeight;
    if (width <= 0 || height <= 0 || !x.isFinite || !y.isFinite) {
      throw ArgumentError('Invalid tracking coordinates');
    }
    final nx = x / width;
    return (
      x: (mirrored ? 1 - nx : nx).clamp(0.0, 1.0),
      y: (y / height).clamp(0.0, 1.0),
    );
  }
}
