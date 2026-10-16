import 'dart:ui' show Offset;

import 'face_tracking.dart';

/// Lightweight EMA smoothing with bounded dropout retention.
///
/// A short missing detection keeps the last coordinates only for UI continuity
/// and marks them `temporarilyLost`; consumers must only act on `tracking`.
/// Coordinates are cleared at [lostTimeout]. A detection after [resetAfter]
/// primes the filter from scratch instead of blending with stale history.
class FaceTrackingProcessor {
  FaceTrackingProcessor({
    this.positionAlpha = 0.35,
    this.sizeAlpha = 0.3,
    this.mouthAlpha = 0.4,
    this.lostTimeout = const Duration(milliseconds: 650),
    this.resetAfter = const Duration(milliseconds: 1000),
  }) : assert(positionAlpha > 0 && positionAlpha <= 1),
       assert(sizeAlpha > 0 && sizeAlpha <= 1),
       assert(mouthAlpha > 0 && mouthAlpha <= 1),
       assert(!lostTimeout.isNegative),
       assert(resetAfter >= lostTimeout);

  final double positionAlpha;
  final double sizeAlpha;
  final double mouthAlpha;
  final Duration lostTimeout;
  final Duration resetAfter;

  Offset? _position;
  double? _faceSize;
  Offset? _mouthPosition;
  double? _mouthOpenness;
  DateTime? _lastDetectedAt;
  int _faceCount = 0;

  StableFaceTracking update(
    FaceTrackingObservation observation, {
    DateTime? now,
  }) {
    final timestamp = now ?? observation.capturedAt;
    _faceCount = observation.faceCount;
    if (observation.isUsable) {
      final gap =
          _lastDetectedAt == null
              ? null
              : observation.capturedAt.difference(_lastDetectedAt!);
      final reset = gap == null || gap.isNegative || gap > resetAfter;
      _position = _smoothOffset(
        previous: reset ? null : _position,
        next: observation.facePosition!,
        alpha: positionAlpha,
      );
      _faceSize = _smoothValue(
        previous: reset ? null : _faceSize,
        next: observation.faceSize!,
        alpha: sizeAlpha,
      );
      _mouthPosition = _smoothNullableOffset(
        previous: reset ? null : _mouthPosition,
        next: observation.mouthPosition,
        alpha: positionAlpha,
      );
      _mouthOpenness = _smoothNullableValue(
        previous: reset ? null : _mouthOpenness,
        next: observation.mouthOpenness,
        alpha: mouthAlpha,
      );
      _lastDetectedAt = observation.capturedAt;
      return _snapshot(FaceTrackingStatus.tracking, timestamp);
    }

    final lastSeen = _lastDetectedAt;
    if (lastSeen == null) {
      return StableFaceTracking(
        status: FaceTrackingStatus.searching,
        faceCount: observation.faceCount,
        position: null,
        faceSize: null,
        mouthPosition: null,
        mouthOpenness: null,
        lastDetectedAt: null,
        updatedAt: timestamp,
      );
    }
    final missingFor = timestamp.difference(lastSeen);
    if (missingFor >= lostTimeout || missingFor.isNegative) {
      final lost = _snapshot(FaceTrackingStatus.lost, timestamp);
      reset();
      return StableFaceTracking(
        status: lost.status,
        faceCount: observation.faceCount,
        position: null,
        faceSize: null,
        mouthPosition: null,
        mouthOpenness: null,
        lastDetectedAt: lastSeen,
        updatedAt: timestamp,
      );
    }
    return _snapshot(FaceTrackingStatus.temporarilyLost, timestamp);
  }

  void reset() {
    _position = null;
    _faceSize = null;
    _mouthPosition = null;
    _mouthOpenness = null;
    _lastDetectedAt = null;
    _faceCount = 0;
  }

  StableFaceTracking _snapshot(FaceTrackingStatus status, DateTime now) =>
      StableFaceTracking(
        status: status,
        faceCount: _faceCount,
        position: _position,
        faceSize: _faceSize,
        mouthPosition: _mouthPosition,
        mouthOpenness: _mouthOpenness,
        lastDetectedAt: _lastDetectedAt,
        updatedAt: now,
      );

  static Offset _smoothOffset({
    required Offset? previous,
    required Offset next,
    required double alpha,
  }) => previous == null ? next : Offset.lerp(previous, next, alpha)!;

  static double _smoothValue({
    required double? previous,
    required double next,
    required double alpha,
  }) => previous == null ? next : previous * (1 - alpha) + next * alpha;

  static Offset? _smoothNullableOffset({
    required Offset? previous,
    required Offset? next,
    required double alpha,
  }) =>
      next == null
          ? null
          : _smoothOffset(previous: previous, next: next, alpha: alpha);

  static double? _smoothNullableValue({
    required double? previous,
    required double? next,
    required double alpha,
  }) =>
      next == null
          ? null
          : _smoothValue(previous: previous, next: next, alpha: alpha);
}
