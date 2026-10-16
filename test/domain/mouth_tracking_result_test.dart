import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/mouth_tracking_result.dart';

void main() {
  group('MouthTrackingResult', () {
    test('empty() is never actionable', () {
      final r = MouthTrackingResult.empty();
      expect(r.isActionable, isFalse);
      expect(r.faceDetected, isFalse);
      expect(r.isFresh, isFalse);
    });

    test('a fresh detected result is actionable', () {
      final r = MouthTrackingResult(
        normalizedPosition: const Offset(0.5, 0.5),
        openness: 0.8,
        faceDetected: true,
        isFresh: true,
        capturedAt: DateTime.now(),
      );
      expect(r.isActionable, isTrue);
    });

    test('stale timestamp is not actionable even if flagged fresh', () {
      final r = MouthTrackingResult(
        normalizedPosition: const Offset(0.5, 0.5),
        openness: 0.8,
        faceDetected: true,
        isFresh: true,
        capturedAt: DateTime.now().subtract(MouthTrackingResult.staleAfter * 2),
      );
      expect(r.isActionable, isFalse);
    });

    test('face not detected is never actionable', () {
      final r = MouthTrackingResult(
        normalizedPosition: const Offset(0.5, 0.5),
        openness: 0.8,
        faceDetected: false,
        isFresh: true,
        capturedAt: DateTime.now(),
      );
      expect(r.isActionable, isFalse);
    });
  });
}
