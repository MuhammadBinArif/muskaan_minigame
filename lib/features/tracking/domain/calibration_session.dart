import 'dart:ui' show Offset;

import 'calibration_config.dart';

enum CalibrationStep { closed, open, closeAgain, complete }

/// Calibration advances only on fresh, usable measurements, never on timers.
class CalibrationSession {
  CalibrationStep step = CalibrationStep.closed;
  final List<double> _closed = [];
  final List<double> _open = [];
  final List<Offset> _neutralPositions = [];
  final List<double> _neutralSizes = [];
  int _closingSamples = 0;
  CalibrationConfig? result;
  DateTime? _lastSample;
  static const baselineSamples = 15;
  static const openSamples = 8;
  static const closingSamples = 8;

  double get progress => switch (step) {
    CalibrationStep.closed => _closed.length / baselineSamples / 3,
    CalibrationStep.open => (1 + _open.length / openSamples) / 3,
    CalibrationStep.closeAgain => (2 + _closingSamples / closingSamples) / 3,
    CalibrationStep.complete => 1,
  };

  String get instruction => switch (step) {
    CalibrationStep.closed => 'Keep your mouth closed and hold still',
    CalibrationStep.open => 'Now open your mouth wide and hold it',
    CalibrationStep.closeAgain => 'Close your mouth again to confirm',
    CalibrationStep.complete => 'Mouth calibration complete',
  };

  void reset() {
    step = CalibrationStep.closed;
    _closed.clear();
    _open.clear();
    _neutralPositions.clear();
    _neutralSizes.clear();
    _closingSamples = 0;
    result = null;
    _lastSample = null;
  }

  void add(
    double value, {
    required DateTime capturedAt,
    Offset? facePosition,
    double? faceSize,
  }) {
    if (!value.isFinite ||
        value < 0 ||
        value > 0.5 ||
        step == CalibrationStep.complete ||
        (_lastSample != null && !capturedAt.isAfter(_lastSample!))) {
      return;
    }
    _lastSample = capturedAt;
    switch (step) {
      case CalibrationStep.closed:
        _closed.add(value);
        if (facePosition != null &&
            facePosition.dx.isFinite &&
            facePosition.dy.isFinite) {
          _neutralPositions.add(facePosition);
        }
        if (faceSize != null && faceSize.isFinite && faceSize > 0) {
          _neutralSizes.add(faceSize);
        }
        if (_closed.length < baselineSamples) return;
        final sorted = [..._closed]..sort();
        if (sorted.last - sorted.first > 0.015) {
          _closed.removeAt(0); // Wait for a stable window.
          return;
        }
        step = CalibrationStep.open;
        return;
      case CalibrationStep.open:
        final baseline = _closed.reduce((a, b) => a + b) / _closed.length;
        if (value < baseline + 0.025) {
          _open.clear();
          return;
        }
        _open.add(value);
        if (_open.length >= openSamples) step = CalibrationStep.closeAgain;
        return;
      case CalibrationStep.closeAgain:
        final baseline = _closed.reduce((a, b) => a + b) / _closed.length;
        final opened = _open.reduce((a, b) => a + b) / _open.length;
        final gap = opened - baseline;
        if (value > baseline + gap * 0.2) {
          _closingSamples = 0;
          return;
        }
        if (++_closingSamples < closingSamples) return;
        final config = CalibrationConfig(
          closedBaseline: baseline + gap * 0.2,
          openThreshold: baseline + gap * 0.6,
          neutralFacePosition: _meanPosition(),
          neutralFaceSize: _mean(_neutralSizes),
          calibrated: true,
        );
        if (!config.isValid) {
          reset();
          return;
        }
        result = config;
        step = CalibrationStep.complete;
        return;
      case CalibrationStep.complete:
        return;
    }
  }

  Offset _meanPosition() {
    if (_neutralPositions.isEmpty) return const Offset(0.5, 0.5);
    final x = _neutralPositions.fold<double>(0, (sum, p) => sum + p.dx);
    final y = _neutralPositions.fold<double>(0, (sum, p) => sum + p.dy);
    return Offset(x / _neutralPositions.length, y / _neutralPositions.length);
  }

  double _mean(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
