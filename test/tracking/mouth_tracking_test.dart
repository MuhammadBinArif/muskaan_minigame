import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_geometry.dart';

void main() {
  group('MouthGeometry.computeRaw', () {
    test('closed mouth has near-zero opening', () {
      final m = MouthGeometry.computeRaw(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 200,
        rightMouthY: 200,
        bottomMouthY: 202,
      );
      expect(m, isNotNull);
      expect(m!.openingPx, closeTo(2.0, 0.01));
      expect(m.mouthWidthPx, closeTo(100.0, 0.01));
    });

    test('open mouth has larger opening', () {
      final m = MouthGeometry.computeRaw(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 200,
        rightMouthY: 200,
        bottomMouthY: 220,
      );
      expect(m, isNotNull);
      expect(m!.openingPx, closeTo(20.0, 0.01));
    });

    test('rejects degenerate mouth width', () {
      final m = MouthGeometry.computeRaw(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 101,
        rightMouthY: 200,
        bottomMouthY: 205,
      );
      expect(m, isNull);
    });

    test('rejects impossible inverted opening', () {
      final m = MouthGeometry.computeRaw(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 200,
        rightMouthY: 200,
        bottomMouthY: 180, // bottom above corners → bad
      );
      expect(m, isNull);
    });
  });

  group('MouthGeometry.normalize', () {
    test('divides opening by face height', () {
      final m =
          MouthGeometry.computeRaw(
            leftMouthX: 100,
            leftMouthY: 200,
            rightMouthX: 200,
            rightMouthY: 200,
            bottomMouthY: 220,
          )!;
      final n = MouthGeometry.normalize(raw: m, faceHeightPx: 200);
      expect(n, closeTo(0.1, 0.001));
    });

    test('rejects undersized faces', () {
      final m =
          MouthGeometry.computeRaw(
            leftMouthX: 100,
            leftMouthY: 200,
            rightMouthX: 200,
            rightMouthY: 200,
            bottomMouthY: 220,
          )!;
      final n = MouthGeometry.normalize(raw: m, faceHeightPx: 5);
      expect(n, isNull);
    });
  });

  group('MouthGeometry.openness (end-to-end math)', () {
    test('closed vs open mouth scale correctly', () {
      final closed = MouthGeometry.openness(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 200,
        rightMouthY: 200,
        bottomMouthY: 202,
        faceHeightPx: 200,
      );
      final open = MouthGeometry.openness(
        leftMouthX: 100,
        leftMouthY: 200,
        rightMouthX: 200,
        rightMouthY: 200,
        bottomMouthY: 220,
        faceHeightPx: 200,
      );
      expect(closed, isNotNull);
      expect(open, isNotNull);
      expect(open! > closed!, isTrue);
      expect(closed, lessThan(0.02));
      expect(open, greaterThan(0.08));
    });
  });

  group('MouthGeometry.isHeadPoseUsable', () {
    test('accepts small tilt', () {
      expect(MouthGeometry.isHeadPoseUsable(eulerX: 10, eulerY: -15), isTrue);
    });
    test('rejects excessive tilt', () {
      expect(MouthGeometry.isHeadPoseUsable(eulerX: 45, eulerY: 0), isFalse);
      expect(MouthGeometry.isHeadPoseUsable(eulerX: 0, eulerY: -35), isFalse);
    });
  });

  group('MouthGeometry.ema', () {
    test('blends toward the new value', () {
      final s = MouthGeometry.ema(previous: 0.0, next: 1.0, alpha: 0.5);
      expect(s, closeTo(0.5, 0.001));
    });
    test('alpha=1 snaps to new value', () {
      final s = MouthGeometry.ema(previous: 0.0, next: 1.0, alpha: 1.0);
      expect(s, closeTo(1.0, 0.001));
    });
  });
}
