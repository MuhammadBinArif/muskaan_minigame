import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_session.dart';
import 'package:muskaan_minigame/features/tracking/domain/tracking_coordinates.dart';

void main() {
  test('requires measured closed, open, and closed samples', () {
    final session = CalibrationSession();
    var t = DateTime(2026);
    void feed(double value, int count) {
      for (var i = 0; i < count; i++) {
        t = t.add(const Duration(milliseconds: 70));
        session.add(value, capturedAt: t);
      }
    }

    expect(session.result, isNull);
    feed(.02, 15);
    expect(session.step, CalibrationStep.open);
    expect(session.result, isNull);
    feed(.10, 8);
    expect(session.step, CalibrationStep.closeAgain);
    expect(session.result, isNull);
    feed(.02, 8);
    expect(session.result!.calibrated, isTrue);
    expect(session.result!.isValid, isTrue);
    expect(session.progress, 1);
    session.reset();
    expect(session.result, isNull);
    expect(session.progress, 0);
  });

  test('noise, duplicate frames, and unchanged mouth cannot calibrate', () {
    final session = CalibrationSession();
    final start = DateTime(2026);
    for (var i = 0; i < 50; i++) {
      session.add(
        i.isEven ? .02 : .08,
        capturedAt: start.add(Duration(milliseconds: 70 * i)),
      );
    }
    expect(session.step, CalibrationStep.closed);
    session.reset();
    for (var i = 0; i < 20; i++) {
      session.add(.02, capturedAt: start);
    }
    expect(session.progress, lessThan(1 / 3));
    session.reset();
    for (var i = 0; i < 100; i++) {
      session.add(.02, capturedAt: start.add(Duration(milliseconds: 70 * i)));
    }
    expect(session.step, CalibrationStep.open);
    expect(session.result, isNull);
  });

  test('upright dimensions and front mirroring are applied once', () {
    final point = TrackingCoordinates.normalize(
      x: 120,
      y: 320,
      imageWidth: 640,
      imageHeight: 480,
      rotationDegrees: 90,
    );
    expect(point.x, .75);
    expect(point.y, .5);
    final landscape = TrackingCoordinates.normalize(
      x: 160,
      y: 120,
      imageWidth: 640,
      imageHeight: 480,
      rotationDegrees: 0,
      mirrored: false,
    );
    expect(landscape.x, .25);
    expect(landscape.y, .25);
  });
}
