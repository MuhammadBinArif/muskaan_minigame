import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';

void main() {
  const config = FaceGameControlConfig(
    neutralX: 0.5,
    horizontalRange: 0.2,
    sensitivity: 1,
    responsePerSecond: 10,
    minimumTargetX: 0.1,
    maximumTargetX: 0.9,
  );

  FaceGameControlSample tracked(double x, DateTime at) => FaceGameControlSample(
    normalizedX: x,
    status: FaceGameControlStatus.tracking,
    observedAt: at,
  );

  test('maps neutral and calibrated face range into the playable area', () {
    final control = FaceGameControl(config: config);
    expect(control.mapNormalizedX(0.5), 0.5);
    expect(control.mapNormalizedX(0.3), closeTo(0.1, 1e-9));
    expect(control.mapNormalizedX(0.7), closeTo(0.9, 1e-9));
  });

  test('clamps left and right edges including the target radius', () {
    final control = FaceGameControl(config: config);
    expect(control.mapNormalizedX(-2), 0.1);
    expect(control.mapNormalizedX(2), 0.9);
    expect(
      control.worldX(worldWidth: 320, targetRadius: 48),
      inInclusiveRange(48, 272),
    );
  });

  test('preserves mirrored screen direction', () {
    final control = FaceGameControl(config: config);
    final left = control.mapNormalizedX(0.42);
    final right = control.mapNormalizedX(0.58);
    expect(left, lessThan(0.5));
    expect(right, greaterThan(0.5));
    expect(right, greaterThan(left));
  });

  test('sensitivity is configurable', () {
    final normal = FaceGameControl(config: config);
    final sensitive = FaceGameControl(
      config: const FaceGameControlConfig(
        neutralX: 0.5,
        horizontalRange: 0.2,
        sensitivity: 1.5,
      ),
    );
    expect(
      sensitive.mapNormalizedX(0.56) - 0.5,
      greaterThan(normal.mapNormalizedX(0.56) - 0.5),
    );
  });

  test('exponential smoothing is independent of update frame rate', () {
    final start = DateTime(2026);
    const smoothingConfig = FaceGameControlConfig(
      neutralX: 0.5,
      horizontalRange: 0.2,
      responsePerSecond: 10,
      staleAfter: Duration(seconds: 2),
      lostAfter: Duration(seconds: 3),
    );
    final at60 = FaceGameControl(config: smoothingConfig)
      ..ingest(tracked(0.7, start), now: start);
    final at30 = FaceGameControl(config: smoothingConfig)
      ..ingest(tracked(0.7, start), now: start);

    for (var i = 1; i <= 60; i++) {
      at60.update(1 / 60, now: start.add(Duration(milliseconds: i * 16)));
    }
    for (var i = 1; i <= 30; i++) {
      at30.update(1 / 30, now: start.add(Duration(milliseconds: i * 33)));
    }

    expect(at60.currentX, closeTo(at30.currentX, 0.002));
  });

  test('stale tracking freezes, expires, and recovers without a jump', () {
    final start = DateTime(2026);
    final control = FaceGameControl(config: config);
    control.ingest(tracked(0.7, start), now: start);
    control.update(0.05, now: start.add(const Duration(milliseconds: 50)));
    final beforeLoss = control.currentX;

    control.update(0.1, now: start.add(const Duration(milliseconds: 300)));
    expect(control.status, FaceGameControlStatus.temporarilyLost);
    expect(control.currentX, beforeLoss);
    control.update(0.5, now: start.add(const Duration(milliseconds: 700)));
    expect(control.status, FaceGameControlStatus.lost);
    expect(control.currentX, beforeLoss);

    final recoveredAt = start.add(const Duration(milliseconds: 710));
    control.ingest(tracked(0.3, recoveredAt), now: recoveredAt);
    expect(control.currentX, beforeLoss);
    control.update(
      1 / 60,
      now: recoveredAt.add(const Duration(milliseconds: 16)),
    );
    expect(control.currentX, lessThan(beforeLoss));
    expect(control.currentX, greaterThan(0.1));
  });

  test('pause invalidates input and restart clears stale position', () {
    final start = DateTime(2026);
    final control = FaceGameControl(config: config);
    control.ingest(tracked(0.7, start), now: start);
    control.update(0.1, now: start.add(const Duration(milliseconds: 100)));
    expect(control.currentX, greaterThan(0.5));

    control.pause();
    final pausedAt = start.add(const Duration(milliseconds: 120));
    control.ingest(tracked(0.3, pausedAt), now: pausedAt);
    control.update(0.2, now: start.add(const Duration(milliseconds: 320)));
    expect(control.status, FaceGameControlStatus.paused);

    control.resume();
    expect(control.status, FaceGameControlStatus.searching);
    expect(control.isActionable, isFalse);
    control.reset();
    expect(control.currentX, 0.5);
    expect(control.targetX, 0.5);
  });

  test('invalid and future observations never become actionable', () {
    final now = DateTime(2026);
    final control = FaceGameControl(config: config);
    control.ingest(
      FaceGameControlSample(
        normalizedX: double.nan,
        status: FaceGameControlStatus.tracking,
        observedAt: now,
      ),
      now: now,
    );
    expect(control.isActionable, isFalse);
    control.ingest(tracked(0.6, now.add(const Duration(seconds: 1))), now: now);
    expect(control.isActionable, isFalse);
  });
}
