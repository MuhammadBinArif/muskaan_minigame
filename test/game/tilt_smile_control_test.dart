import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/game/domain/smile_trigger.dart';
import 'package:muskaan_minigame/features/game/domain/tilt_movement.dart';

void main() {
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
