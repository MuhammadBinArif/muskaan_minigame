import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/game/domain/smile_trigger.dart';
import 'package:muskaan_minigame/features/game/domain/tilt_movement.dart';
import 'package:muskaan_minigame/features/game/domain/smile_calibration.dart';
import 'package:muskaan_minigame/features/game/data/smile_calibration_store.dart';
import 'package:muskaan_minigame/features/game/data/tilt_sensor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

void main() {
  test('interrupted smile requires fresh neutral before another trigger', () {
    final trigger = SmileTrigger();
    final now = DateTime.utc(2026);
    expect(trigger.update(.8, now), isFalse);
    expect(
      trigger.update(.8, now.add(const Duration(milliseconds: 200))),
      isTrue,
    );
    trigger.requireNeutral();
    expect(trigger.update(null, now), isFalse);
    expect(trigger.update(.8, now.add(const Duration(seconds: 1))), isFalse);
    expect(trigger.update(.8, now.add(const Duration(seconds: 2))), isFalse);
    expect(trigger.update(.1, now.add(const Duration(seconds: 3))), isFalse);
    expect(trigger.update(.8, now.add(const Duration(seconds: 4))), isFalse);
    expect(
      trigger.update(.8, now.add(const Duration(milliseconds: 4200))),
      isTrue,
    );
    expect(trigger.update(.8, now.add(const Duration(seconds: 5))), isFalse);
  });
  test(
    'derived thresholds persist and invalid stored data is rejected',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SmileCalibrationStore();
      expect(await store.load(), isNull);
      await store.save(const SmileCalibration(enter: .6, exit: .3));
      final restored = await SmileCalibrationStore().load();
      expect(restored!.enter, .6);
      final trigger = SmileTrigger(
        threshold: restored.enter,
        neutralThreshold: restored.exit,
      );
      final now = DateTime.utc(2026);
      expect(trigger.update(.61, now), isFalse);
      expect(
        trigger.update(.61, now.add(const Duration(milliseconds: 160))),
        isTrue,
      );
      SharedPreferences.setMockInitialValues({
        'smile_calibration_v1': ['0.2', '0.8'],
      });
      expect(await store.load(), isNull);
    },
  );

  test(
    'sensor adapter avoids duplicate subscriptions and stops callbacks',
    () async {
      final source = StreamController<AccelerometerEvent>.broadcast(sync: true);
      final sensor = TiltSensor(events: () => source.stream);
      final angles = <double>[];
      sensor.start(onAngle: angles.add, onError: (_) {});
      sensor.start(onAngle: angles.add, onError: (_) {});
      source.add(AccelerometerEvent(0, 9.8, 0, DateTime.utc(2026)));
      source.add(AccelerometerEvent(double.nan, 9.8, 0, DateTime.utc(2026)));
      expect(angles, hasLength(1));
      await sensor.stop();
      source.add(AccelerometerEvent(1, 9.8, 0, DateTime.utc(2026)));
      expect(angles, hasLength(1));
      expect(source.hasListener, isFalse);
      await source.close();
    },
  );
  test(
    'smile calibration uses medians and rejects weak or invalid samples',
    () {
      expect(
        SmileCalibration.fromSamples(neutral: [double.nan], smile: [.9]),
        isNull,
      );
      expect(
        SmileCalibration.fromSamples(
          neutral: List.filled(8, .4),
          smile: List.filled(8, .5),
        ),
        isNull,
      );
      final calibration = SmileCalibration.fromSamples(
        neutral: [.1, .1, .1, .1, .1, .1, .1, .9],
        smile: [.1, .7, .7, .7, .7, .7, .7, .7],
      );
      expect(calibration, isNotNull);
      expect(calibration!.enter, closeTo(.49, .001));
      expect(calibration.exit, closeTo(.28, .001));
    },
  );
  test('calibration rejects insufficient, invalid and unstable readings', () {
    final control = TiltMovement();
    expect(control.calibrateStable([1, double.nan]), isFalse);
    expect(
      control.calibrateStable(List.generate(12, (i) => i.toDouble())),
      isFalse,
    );
    expect(control.calibrateStable(List.filled(12, 8)), isTrue);
    expect(control.neutralDegrees, 8);
  });

  test(
    'missing observations interrupt candidates and do not rearm held smile',
    () {
      final trigger = SmileTrigger();
      final start = DateTime.utc(2026);
      expect(trigger.update(.8, start), isFalse);
      expect(
        trigger.update(null, start.add(const Duration(milliseconds: 100))),
        isFalse,
      );
      expect(
        trigger.update(.8, start.add(const Duration(milliseconds: 200))),
        isFalse,
      );
      expect(
        trigger.update(.8, start.add(const Duration(milliseconds: 360))),
        isTrue,
      );
      expect(
        trigger.update(null, start.add(const Duration(milliseconds: 400))),
        isFalse,
      );
      expect(
        trigger.update(.8, start.add(const Duration(seconds: 1))),
        isFalse,
      );
    },
  );
  test('tilt calibrates, respects dead zone and clamps movement', () {
    final control = TiltMovement()..calibrate([10, 10, 10]);
    for (var i = 0; i < 100; i++) {
      control.update(12, .02);
    }
    expect(control.position, .5);
    for (var i = 0; i < 100; i++) {
      control.update(35, .02);
    }
    expect(control.position, .9);
    for (var i = 0; i < 200; i++) {
      control.update(-15, .02);
    }
    expect(control.position, .1);
  });

  test('one confirmed smile requires neutral before retriggering', () {
    final trigger = SmileTrigger();
    final start = DateTime.utc(2026);
    expect(trigger.update(.8, start), isFalse);
    expect(
      trigger.update(.8, start.add(const Duration(milliseconds: 160))),
      isTrue,
    );
    expect(trigger.update(.8, start.add(const Duration(seconds: 1))), isFalse);
    expect(trigger.update(.2, start.add(const Duration(seconds: 2))), isFalse);
    expect(trigger.update(.8, start.add(const Duration(seconds: 3))), isFalse);
    expect(
      trigger.update(.8, start.add(const Duration(milliseconds: 3160))),
      isTrue,
    );
  });
}
