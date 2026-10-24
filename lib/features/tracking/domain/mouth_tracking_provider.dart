import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muskaan_minigame/core/domain/mouth_tracking_result.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking_processor.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_state_machine.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'package:muskaan_minigame/features/tracking/data/vision_sevice_impl.dart';

/// Provider for VisionService abstraction.
final visionServiceProvider = Provider<VisionService>((ref) {
  final service = VisionServiceImpl();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Player's active calibration configuration.
final calibrationConfigProvider = StateProvider<CalibrationConfig>(
  (ref) => CalibrationConfig.defaults(),
);

/// Combined mouth tracking state.
class MouthTrackingState {
  final MouthTrackingResult latestResult;
  final MouthTransition latestTransition;
  final StableFaceTracking tracking;
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
    required this.tracking,
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
        tracking: StableFaceTracking.searching(),
        isFaceDetected: false,
        isCalibrated: config.calibrated,
        isStreaming: false,
        cameraStatus: CameraStatus.idle,
        cameraController: null,
      );

  MouthTrackingState copyWith({
    MouthTrackingResult? latestResult,
    MouthTransition? latestTransition,
    StableFaceTracking? tracking,
    bool? isFaceDetected,
    bool? isCalibrated,
    bool? isStreaming,
    CameraStatus? cameraStatus,
    dynamic cameraController,
    bool clearController = false,
    String? error,
    bool clearError = false,
    double? fps,
    double? rawOpenness,
    DateTime? lastEventTime,
  }) => MouthTrackingState(
    latestResult: latestResult ?? this.latestResult,
    latestTransition: latestTransition ?? this.latestTransition,
    tracking: tracking ?? this.tracking,
    isFaceDetected: isFaceDetected ?? this.isFaceDetected,
    isCalibrated: isCalibrated ?? this.isCalibrated,
    isStreaming: isStreaming ?? this.isStreaming,
    cameraStatus: cameraStatus ?? this.cameraStatus,
    cameraController:
        clearController ? null : cameraController ?? this.cameraController,
    error: clearError ? null : error ?? this.error,
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
  final FaceTrackingProcessor _trackingProcessor;
  StreamSubscription<CameraState>? _cameraSub;
  DateTime? _lastFrameTime;
  double _calculatedFps = 0.0;
  int _generation = 0;
  Future<void> _operations = Future<void>.value();
  CalibrationConfig _config;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  CameraService get camera => _camera;

  MouthTrackingController({
    required CameraService camera,
    required VisionService vision,
    required CalibrationConfig config,
    required Ref ref,
    FaceTrackingProcessor? trackingProcessor,
  }) : _camera = camera,
       _vision = vision,
       _config = config,
       _stateMachine = MouthStateMachine(config: config),
       _trackingProcessor = trackingProcessor ?? FaceTrackingProcessor(),
       super(MouthTrackingState.initial(config)) {
    _cameraSub = _camera.stateStream.listen((camState) {
      if (mounted) {
        state = state.copyWith(
          cameraStatus: camState.status,
          cameraController: _camera.controller,
          clearController: _camera.controller == null,
          error: camState.errorMessage,
          clearError: camState.errorMessage == null,
        );
      }
    });
  }

  /// Camera operations are serialized across route changes and interruptions.
  Future<void> startTracking({int maxFps = 15}) {
    final generation = _generation;
    return _enqueue(() async {
      if (!mounted || generation != _generation) return;
      if (state.isStreaming &&
          _camera.isStreaming &&
          !state.hasCameraError &&
          state.error == null) {
        return;
      }
      try {
        if (state.hasCameraError || state.error != null) {
          await _camera.dispose();
        }
        if (!mounted || generation != _generation) return;
        state = state.copyWith(clearError: true);
        await _camera.initialize();
        if (!mounted || generation != _generation) return;
        state = state.copyWith(
          cameraStatus: _camera.state.status,
          cameraController: _camera.controller,
          clearController: _camera.controller == null,
          error: _camera.state.errorMessage,
          clearError: _camera.state.errorMessage == null,
        );
        if (!_camera.state.isReadyOrStreaming) return;
        _stateMachine.updateConfig(_config);
        await _camera.startStream(
          maxFps: maxFps,
          onFrame: (image) async {
            final capturedAt = DateTime.now();
            final frame = await _vision.process(
              image,
              rotationDegrees: _camera.imageRotationDegrees,
            );
            if (!mounted || generation != _generation) return;
            final processedAt = DateTime.now();
            final tracking = _trackingProcessor.update(
              frame.observation,
              now: processedAt,
            );
            final fresh =
                processedAt.difference(frame.capturedAt) <
                MouthTrackingResult.staleAfter;
            final usable =
                fresh &&
                tracking.isTracking &&
                tracking.mouthOpenness != null &&
                tracking.mouthOpenness!.isFinite;
            MouthTransition transition;
            if (usable) {
              transition = _stateMachine.update(
                tracking.mouthOpenness!,
                now: frame.capturedAt,
              );
            } else if (tracking.status == FaceTrackingStatus.lost) {
              _stateMachine.reset();
              transition = MouthTransition.idle;
            } else {
              transition = MouthTransition(
                isOpen: state.latestTransition.isOpen,
                justOpened: false,
                justClosed: false,
                currentStateDuration:
                    state.latestTransition.currentStateDuration,
                smoothedOpenness: state.latestTransition.smoothedOpenness,
              );
            }
            if (_lastFrameTime != null) {
              final dt = capturedAt.difference(_lastFrameTime!).inMicroseconds;
              if (dt > 0) _calculatedFps = 1000000 / dt;
            }
            _lastFrameTime = capturedAt;
            final normalizedOpenness =
                usable && _config.deadband > 0
                    ? ((tracking.mouthOpenness! - _config.closedBaseline) /
                            _config.deadband)
                        .clamp(0.0, 1.0)
                    : 0.0;
            final position =
                tracking.mouthPosition ??
                tracking.position ??
                const Offset(0.5, 0.5);
            state = state.copyWith(
              latestResult: MouthTrackingResult(
                normalizedPosition: position,
                openness: normalizedOpenness,
                faceDetected: tracking.isTracking,
                isFresh: fresh && tracking.isTracking,
                capturedAt: frame.capturedAt,
              ),
              latestTransition: transition,
              tracking: tracking,
              isFaceDetected: tracking.isTracking,
              isStreaming: true,
              rawOpenness: usable ? tracking.mouthOpenness! : 0,
              fps: _calculatedFps,
              lastEventTime:
                  transition.justOpened || transition.justClosed
                      ? capturedAt
                      : state.lastEventTime,
            );
          },
        );
        if (mounted && generation == _generation) {
          state = state.copyWith(isStreaming: _camera.isStreaming);
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          state = state.copyWith(
            error: 'Unable to track mouth movement. Please recalibrate.',
            isStreaming: false,
          );
        }
      }
    });
  }

  /// Invalidate pending frames immediately, then release the device camera.
  Future<void> stopTracking() {
    ++_generation;
    // Cancel an in-flight initialization now rather than after it finishes.
    final release = _camera.dispose();
    return _enqueue(() async {
      await release;
      if (mounted) state = MouthTrackingState.initial(_config);
      _stateMachine.reset();
      _trackingProcessor.reset();
      _lastFrameTime = null;
    });
  }

  void updateCalibration(CalibrationConfig config) {
    if (!config.isValid) throw ArgumentError('Invalid mouth calibration');
    _config = config;
    _stateMachine.updateConfig(config);
    state = state.copyWith(isCalibrated: config.calibrated);
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_cameraSub?.cancel());
    unawaited(_camera.dispose());
    super.dispose();
  }
}

/// Global provider for MouthTrackingController.
final mouthTrackingProvider =
    StateNotifierProvider<MouthTrackingController, MouthTrackingState>((ref) {
      final camera = ref.watch(cameraServiceProvider);
      final vision = ref.watch(visionServiceProvider);
      final config = ref.read(calibrationConfigProvider);

      return MouthTrackingController(
        camera: camera,
        vision: vision,
        config: config,
        ref: ref,
      );
    });
