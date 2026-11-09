import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Reports gravity-derived roll in degrees. The caller owns calibration and
/// smoothing; stopping this service releases its sole sensor subscription.
class TiltSensor {
  StreamSubscription<AccelerometerEvent>? _subscription;

  void start({
    required void Function(double) onAngle,
    required void Function(Object) onError,
  }) {
    if (_subscription != null) return;
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) return;
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude < 1) return;
      onAngle(
        math.atan2(-event.x, math.sqrt(event.y * event.y + event.z * event.z)) *
            180 /
            math.pi,
      );
    }, onError: onError);
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
