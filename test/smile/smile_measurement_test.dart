import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/smile/domain/smile_measurement.dart';

void main() {
  final time = DateTime.utc(2026, 11, 9);
  const calibration = SmileCalibration(
    neutralProbability: .2,
    naturalSmileProbability: .8,
  );

  group('probability validation', () {
    test('accepts boundaries and typical genuine probabilities', () {
      for (final probability in [0.0, .18, .47, .83, 1.0]) {
        final result =
            SmileMeasurementEngine().observe(
              probability,
              capturedAt: time,
              now: time,
            )!;
        expect(result.rawProbability, probability);
        expect(
          result.intensityUnavailableReason,
          SmileUnavailableReason.missingCalibration,
        );
      }
    });

    test('rejects missing, nonfinite and out-of-range probabilities', () {
      for (final probability in [
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -.01,
        1.01,
      ]) {
        final engine = SmileMeasurementEngine();
        expect(
          engine.observe(probability, capturedAt: time, now: time),
          isNull,
        );
        expect(engine.current, isNull);
      }
    });
  });

  group('calibration normalization', () {
    test('normalizes, clamps and exposes raw 0-100 intensity', () {
      for (final entry
          in {-.0: 0.0, .2: 0.0, .5: 50.0, .8: 100.0, 1.0: 100.0}.entries) {
        final engine = SmileMeasurementEngine(calibration: calibration);
        final result = engine.observe(entry.key, capturedAt: time, now: time)!;
        expect(result.rawCalibratedIntensity, closeTo(entry.value, .0001));
        expect(result.smoothedCalibratedIntensity, closeTo(entry.value, .0001));
      }
    });

    test('missing and invalid calibration report unavailable intensity', () {
      final missing =
          SmileMeasurementEngine().observe(.5, capturedAt: time, now: time)!;
      expect(missing.calibratedIntensity, isNull);
      expect(
        missing.intensityUnavailableReason,
        SmileUnavailableReason.missingCalibration,
      );
      for (final invalid in [
        const SmileCalibration(
          neutralProbability: .2,
          naturalSmileProbability: .2,
        ),
        const SmileCalibration(
          neutralProbability: .2,
          naturalSmileProbability: .24,
        ),
        const SmileCalibration(
          neutralProbability: .8,
          naturalSmileProbability: .2,
        ),
        const SmileCalibration(
          neutralProbability: double.nan,
          naturalSmileProbability: 1,
        ),
        const SmileCalibration(
          neutralProbability: .2,
          naturalSmileProbability: double.infinity,
        ),
      ]) {
        final value =
            SmileMeasurementEngine(
              calibration: invalid,
            ).observe(.5, capturedAt: time, now: time)!;
        expect(value.calibratedIntensity, isNull);
        expect(
          value.intensityUnavailableReason,
          SmileUnavailableReason.invalidCalibration,
        );
      }
    });

    test(
      'calibration update resets smoothing and takes effect immediately',
      () {
        final engine = SmileMeasurementEngine(
          alpha: .5,
          calibration: calibration,
        );
        engine.observe(.2, capturedAt: time, now: time);
        engine.observe(
          .8,
          capturedAt: time.add(const Duration(milliseconds: 10)),
          now: time.add(const Duration(milliseconds: 10)),
        );
        engine.updateCalibration(
          const SmileCalibration(
            neutralProbability: .4,
            naturalSmileProbability: .9,
          ),
        );
        expect(engine.current, isNull);
        final after = engine.observe(.65, capturedAt: time, now: time)!;
        expect(after.rawCalibratedIntensity, closeTo(50, .0001));
        expect(after.smoothedCalibratedIntensity, closeTo(50, .0001));
      },
    );
  });

  group('time, smoothing and lifecycle', () {
    test('EMA smooths calibrated intensity with configurable alpha', () {
      final engine = SmileMeasurementEngine(
        alpha: .5,
        calibration: calibration,
      );
      final first = engine.observe(.2, capturedAt: time, now: time)!;
      final nextTime = time.add(const Duration(milliseconds: 100));
      final second = engine.observe(.8, capturedAt: nextTime, now: nextTime)!;
      expect(first.smoothedCalibratedIntensity, 0);
      expect(second.rawCalibratedIntensity, 100);
      expect(second.smoothedCalibratedIntensity, closeTo(50, .0001));
    });

    test('invalid input never enters or survives smoothing', () {
      final engine = SmileMeasurementEngine(
        alpha: .5,
        calibration: calibration,
      );
      engine.observe(.2, capturedAt: time, now: time);
      expect(
        engine.observe(
          double.nan,
          capturedAt: time.add(const Duration(milliseconds: 1)),
          now: time.add(const Duration(milliseconds: 1)),
        ),
        isNull,
      );
      final next = time.add(const Duration(milliseconds: 2));
      expect(
        engine
            .observe(.8, capturedAt: next, now: next)!
            .smoothedCalibratedIntensity,
        100,
      );
    });

    test('stale, future, duplicate and out-of-order samples are rejected', () {
      final engine = SmileMeasurementEngine(calibration: calibration);
      engine.observe(.5, capturedAt: time, now: time);
      expect(engine.observe(.6, capturedAt: time, now: time), isNull);
      expect(
        engine.lastUnavailableReason,
        SmileUnavailableReason.duplicateObservation,
      );
      expect(
        engine.observe(
          .6,
          capturedAt: time.subtract(const Duration(milliseconds: 1)),
          now: time,
        ),
        isNull,
      );
      expect(
        engine.lastUnavailableReason,
        SmileUnavailableReason.outOfOrderObservation,
      );
      engine.reset();
      expect(
        engine.observe(
          .6,
          capturedAt: time,
          now: time.add(const Duration(milliseconds: 501)),
        ),
        isNull,
      );
      expect(
        engine.lastUnavailableReason,
        SmileUnavailableReason.staleObservation,
      );
      expect(
        engine.observe(
          .6,
          capturedAt: time.add(const Duration(milliseconds: 1)),
          now: time,
        ),
        isNull,
      );
      expect(
        engine.lastUnavailableReason,
        SmileUnavailableReason.futureObservation,
      );
    });

    test('reset boundaries remove live value, EMA and ordering state', () {
      for (final boundary in ['pause', 'camera interruption', 'mode switch']) {
        final engine = SmileMeasurementEngine(
          alpha: .5,
          calibration: calibration,
        );
        engine.observe(.2, capturedAt: time, now: time);
        engine.reset();
        expect(engine.current, isNull, reason: boundary);
        final after = engine.observe(.8, capturedAt: time, now: time)!;
        expect(after.smoothedCalibratedIntensity, 100, reason: boundary);
      }
    });

    test('fresh sample after a tracking gap starts a new EMA', () {
      final engine = SmileMeasurementEngine(
        alpha: .5,
        calibration: calibration,
      );
      engine.observe(.2, capturedAt: time, now: time);
      final afterGap = time.add(const Duration(milliseconds: 501));
      final result = engine.observe(.8, capturedAt: afterGap, now: afterGap)!;
      expect(result.smoothedCalibratedIntensity, 100);
      expect(result.smoothedProbability, .8);
    });
  });

  group('round statistics', () {
    SmileMeasurement measurement(double probability, DateTime at) =>
        SmileMeasurementEngine(
          calibration: calibration,
        ).observe(probability, capturedAt: at, now: at)!;

    test('collects valid raw calibrated average, peak and span', () {
      final collector = SmileRoundStatisticsCollector(
        playerId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        roundId: 1,
      );
      expect(collector.add(measurement(.2, time), now: time), isTrue);
      final next = time.add(const Duration(milliseconds: 100));
      expect(collector.add(measurement(.5, next), now: next), isTrue);
      final last = time.add(const Duration(milliseconds: 200));
      expect(collector.add(measurement(.8, last), now: last), isTrue);
      final stats = collector.statistics;
      expect(stats.validObservationCount, 3);
      expect(stats.averageCalibratedIntensity, closeTo(50, .0001));
      expect(stats.peakCalibratedIntensity, 100);
      expect(stats.observationSpan, const Duration(milliseconds: 200));
    });

    test('empty, unavailable, stale and duplicate samples are excluded', () {
      final collector = SmileRoundStatisticsCollector(
        playerId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        roundId: 1,
      );
      expect(collector.statistics.averageCalibratedIntensity, isNull);
      final uncalibrated =
          SmileMeasurementEngine().observe(.5, capturedAt: time, now: time)!;
      expect(collector.add(uncalibrated, now: time), isFalse);
      final valid = measurement(.5, time);
      expect(
        collector.add(valid, now: time.add(const Duration(milliseconds: 501))),
        isFalse,
      );
      expect(collector.add(valid, now: time), isTrue);
      expect(collector.add(valid, now: time), isFalse);
      expect(collector.statistics.validObservationCount, 1);
    });

    test('new rounds and players require distinct collectors', () {
      final first = SmileRoundStatisticsCollector(
        playerId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        roundId: 1,
      );
      first.add(measurement(.8, time), now: time);
      final next = SmileRoundStatisticsCollector(
        playerId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        roundId: 2,
      );
      expect(next.statistics.validObservationCount, 0);
      expect(next.statistics.averageCalibratedIntensity, isNull);
      expect(next.playerId, isNot(first.playerId));
      expect(
        () => SmileRoundStatisticsCollector(playerId: '', roundId: 3),
        throwsArgumentError,
      );
    });
  });
}
