import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muskaan_minigame/core/domain/mouth_tracking_result.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/camera/data/camera_service_impl.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_state_machine.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'package:muskaan_minigame/features/tracking/data/vision_sevice_impl.dart';

/// Provider for CameraService abstraction.
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraServiceImpl();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Provider for VisionService abstraction.
final visionServiceProvider = Provider<VisionService>((ref) {
  final service = VisionServiceImpl();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Player's active calibration configuration.
final calibrationConfigProvider =
    StateProvider<CalibrationConfig>((ref) => CalibrationConfig.defaults());

/// Combined mouth tracking state.
class MouthTrackingState {
  final MouthTrackingResult latestResult;
  final MouthTransition latestTransition;
  final bool isFaceDetected;
  final bool isCalibrated;
  final bool isStreaming;
  final CameraStatus cameraStatus;
  final dynamic cameraController;
  final String? error;
  final double fps;
  final double rawOpenness;
  final DateTime? lastEventTime;

  const MouthTrackingState({
    required this.latestResult,
    required this.latestTransition,
    required this.isFaceDetected,
    required this.isCalibrated,
    required this.isStreaming,
    required this.cameraStatus,
    this.cameraController,
    this.error,
    this.fps = 0.0,
    this.rawOpenness = 0.0,
    this.lastEventTime,
  });

  bool get isCameraReady =>
      cameraStatus == CameraStatus.ready ||
      cameraStatus == CameraStatus.streaming;

  bool get hasCameraError =>
      cameraStatus == CameraStatus.failed ||
      cameraStatus == CameraStatus.noFrontCamera ||
      cameraStatus == CameraStatus.permissionDenied ||
      cameraStatus == CameraStatus.permissionPermanentlyDenied;

  factory MouthTrackingState.initial(CalibrationConfig config) =>
      MouthTrackingState(
        latestResult: MouthTrackingResult.empty(),
        latestTransition: MouthTransition.idle,
        isFaceDetected: false,
        isCalibrated: config.calibrated,
        isStreaming: false,
        cameraStatus: CameraStatus.idle,
        cameraController: null,
      );

  MouthTrackingState copyWith({
    MouthTrackingResult? latestResult,
    MouthTransition? latestTransition,
    bool? isFaceDetected,
    bool? isCalibrated,
    bool? isStreaming,
    CameraStatus? cameraStatus,
    dynamic cameraController,
    String? error,
    double? fps,
    double? rawOpenness,
    DateTime? lastEventTime,
  }) =>
      MouthTrackingState(
        latestResult: latestResult ?? this.latestResult,
        latestTransition: latestTransition ?? this.latestTransition,
        isFaceDetected: isFaceDetected ?? this.isFaceDetected,
        isCalibrated: isCalibrated ?? this.isCalibrated,
        isStreaming: isStreaming ?? this.isStreaming,
        cameraStatus: cameraStatus ?? this.cameraStatus,
        cameraController: cameraController ?? this.cameraController,
        error: error ?? this.error,
        fps: fps ?? this.fps,
        rawOpenness: rawOpenness ?? this.rawOpenness,
        lastEventTime: lastEventTime ?? this.lastEventTime,
      );
}

/// Controller that binds CameraService + VisionService + MouthStateMachine.
class MouthTrackingController extends StateNotifier<MouthTrackingState> {
  final CameraService _camera;
  final VisionService _vision;
  final MouthStateMachine _stateMachine;
  final Ref _ref;
  StreamSubscription<CameraState>? _cameraSub;
  DateTime? _lastFrameTime;
  double _calculatedFps = 0.0;

  CameraService get camera => _camera;

  MouthTrackingController({
    required CameraService camera,
    required VisionService vision,
    required CalibrationConfig config,
    required Ref ref,
  })  : _camera = camera,
        _vision = vision,
        _ref = ref,
        _stateMachine = MouthStateMachine(config: config),
        super(MouthTrackingState.initial(config)) {
    _cameraSub = _camera.stateStream.listen((camState) {
      if (mounted) {
        state = state.copyWith(
          cameraStatus: camState.status,
          cameraController: _camera.controller,
          error: camState.errorMessage,
        );
      }
    });
  }

  /// Initialize camera and start tracking stream.
  Future<void> startTracking({int maxFps = 15}) async {
    try {
      await _camera.initialize();
      if (mounted) {
        state = state.copyWith(
          cameraStatus: _camera.state.status,
          cameraController: _camera.controller,
        );
      }
      if (_camera.state.isFailed ||
          _camera.state.hasPermissionError ||
          _camera.state.status == CameraStatus.noFrontCamera) {
        state = state.copyWith(error: _camera.state.errorMessage);
        return;
      }

      final config = _ref.read(calibrationConfigProvider);
      _stateMachine.updateConfig(config);

      await _camera.startStream(
        maxFps: maxFps,
        onFrame: (cameraImage) async {
          final now = DateTime.now();
          if (_lastFrameTime != null) {
            final dtMs = now.difference(_lastFrameTime!).inMilliseconds;
            if (dtMs > 0) {
              final instantFps = 1000.0 / dtMs;
              _calculatedFps = _calculatedFps == 0
                  ? instantFps
                  : (_calculatedFps * 0.8 + instantFps * 0.2);
            }
          }
          _lastFrameTime = now;

          final frame = await _vision.process(
            cameraImage,
            rotationDegrees: _camera.sensorOrientation,
          );

          final transition = frame.faceDetected && frame.rawOpenness != null
              ? _stateMachine.update(frame.rawOpenness!)
              : MouthTransition.idle;

          DateTime? newEventTime = state.lastEventTime;
          if (transition.justOpened || transition.justClosed) {
            newEventTime = now;
          }

          // Normalized openness between 0.0 and 1.0 based on calibration
          final double normalizedOpenness;
          if (frame.rawOpenness != null && config.deadband > 0) {
            normalizedOpenness = ((frame.rawOpenness! - config.closedBaseline) /
                    config.deadband)
                .clamp(0.0, 1.0);
          } else {
            normalizedOpenness = transition.isOpen ? 1.0 : 0.0;
          }

          final result = MouthTrackingResult(
            normalizedPosition: frame.mouthCenter ?? const Offset(0.5, 0.5),
            openness: normalizedOpenness,
            confidence: frame.confidence,
            faceDetected: frame.faceDetected,
            isFresh: true,
            capturedAt: frame.capturedAt,
          );

          if (mounted) {
            state = state.copyWith(
              latestResult: result,
              latestTransition: transition,
              isFaceDetected: frame.faceDetected,
              isStreaming: true,
              fps: _calculatedFps,
              rawOpenness: frame.rawOpenness ?? 0.0,
              lastEventTime: newEventTime,
            );
          }
        },
      );

      state = state.copyWith(isStreaming: true);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// Stop streaming camera frames.
  Future<void> stopTracking() async {
    await _camera.stopStream();
    if (mounted) {
      state = state.copyWith(isStreaming: false);
    }
  }

  /// Update calibration configuration.
  void updateCalibration(CalibrationConfig newConfig) {
    _stateMachine.updateConfig(newConfig);
    state = state.copyWith(isCalibrated: newConfig.calibrated);
  }

  @override
  void dispose() {
    _cameraSub?.cancel();
    _camera.stopStream();
    super.dispose();
  }
}

/// Global provider for MouthTrackingController.
final mouthTrackingProvider =
    StateNotifierProvider<MouthTrackingController, MouthTrackingState>((ref) {
  final camera = ref.watch(cameraServiceProvider);
  final vision = ref.watch(visionServiceProvider);
  final config = ref.watch(calibrationConfigProvider);

  return MouthTrackingController(
    camera: camera,
    vision: vision,
    config: config,
    ref: ref,
  );
});
