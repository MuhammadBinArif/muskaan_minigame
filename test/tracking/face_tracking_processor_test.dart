import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking_processor.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_geometry.dart';
import 'package:muskaan_minigame/features/tracking/domain/tracking_coordinates.dart';

FaceTrackingObservation observation(
  DateTime at, {
  Offset position = const Offset(.2, .4),
}) => FaceTrackingObservation(
  faceDetected: true,
  faceCount: 1,
  facePosition: position,
  faceSize: .3,
  mouthPosition: Offset(position.dx, position.dy + .1),
  mouthOpenness: .04,
  capturedAt: at,
);

void main() {
  test('smooths valid position without changing coordinate direction', () {
    final processor = FaceTrackingProcessor(positionAlpha: .5);
    final start = DateTime(2026);
    final first = processor.update(observation(start));
    final next = processor.update(
      observation(
        start.add(const Duration(milliseconds: 70)),
        position: const Offset(.8, .6),
      ),
    );
    expect(first.position, const Offset(.2, .4));
    expect(next.position!.dx, closeTo(.5, .001));
    expect(next.position!.dy, closeTo(.5, .001));
    expect(next.status, FaceTrackingStatus.tracking);
  });

  test('holds short dropout, expires it, and resets after a long gap', () {
    final processor = FaceTrackingProcessor(
      positionAlpha: .5,
      lostTimeout: const Duration(milliseconds: 600),
      resetAfter: const Duration(milliseconds: 900),
    );
    final start = DateTime(2026);
    processor.update(observation(start));
    final temporary = processor.update(
      FaceTrackingObservation.missing(
        capturedAt: start.add(const Duration(milliseconds: 200)),
      ),
    );
    expect(temporary.status, FaceTrackingStatus.temporarilyLost);
    expect(temporary.position, isNotNull);
    expect(temporary.hasFreshCoordinates, isFalse);

    final lostAt = start.add(const Duration(milliseconds: 700));
    final lost = processor.update(
      FaceTrackingObservation.missing(capturedAt: lostAt),
    );
    expect(lost.status, FaceTrackingStatus.lost);
    expect(lost.position, isNull);

    final reacquired = processor.update(
      observation(
        start.add(const Duration(milliseconds: 1200)),
        position: const Offset(.9, .1),
      ),
    );
    expect(reacquired.position, const Offset(.9, .1));
  });

  test('multiple faces are invalid and reported to UI', () {
    final processor = FaceTrackingProcessor();
    final result = processor.update(
      FaceTrackingObservation.missing(capturedAt: DateTime(2026), faceCount: 2),
    );
    expect(result.status, FaceTrackingStatus.searching);
    expect(result.faceCount, 2);
  });

  test('normalization clamps edges, mirrors x, and validates rotation', () {
    final point = TrackingCoordinates.normalize(
      x: 0,
      y: 640,
      imageWidth: 640,
      imageHeight: 480,
      rotationDegrees: 90,
    );
    expect(point.x, 1);
    expect(point.y, 1);
    expect(
      () => TrackingCoordinates.normalize(
        x: 1,
        y: 1,
        imageWidth: 640,
        imageHeight: 480,
        rotationDegrees: 45,
      ),
      throwsArgumentError,
    );
  });

  test('BoxFit.cover mapping accounts for centered preview crop', () {
    final center = TrackingCoordinates.mapToCover(
      position: const Offset(.5, .5),
      sourceWidth: 400,
      sourceHeight: 800,
      viewportWidth: 200,
      viewportHeight: 200,
    );
    expect(center, const Offset(100, 100));
    final topLeft = TrackingCoordinates.mapToCover(
      position: Offset.zero,
      sourceWidth: 400,
      sourceHeight: 800,
      viewportWidth: 200,
      viewportHeight: 200,
    );
    expect(topLeft.dx, 0);
    expect(topLeft.dy, -100);
  });

  test('lip contour aperture is measured without using smile probability', () {
    final closed = MouthGeometry.contourOpenness(
      upperLipBottomY: const [100, 100, 100, 100, 100, 100],
      lowerLipTopY: const [100, 101, 101, 101, 101, 100],
      faceHeightPx: 200,
    );
    final open = MouthGeometry.contourOpenness(
      upperLipBottomY: const [100, 100, 100, 100, 100, 100],
      lowerLipTopY: const [100, 108, 112, 112, 108, 100],
      faceHeightPx: 200,
    );
    expect(closed, closeTo(.005, .001));
    expect(open, closeTo(.06, .001));
    expect(open! > closed!, isTrue);
  });
}
