import 'dart:async';

import 'package:camera/camera.dart' show CameraImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/domain/camera_provider.dart';
import '../../camera/domain/camera_service.dart';
import '../../camera/domain/camera_state.dart';
import '../data/ml_kit_face_detection_service.dart';
import 'face_detection_result.dart';
import 'face_detection_service.dart';

enum FaceDetectionStatus {
  idle,
  initializing,
  searching,
  detected,
  multipleFaces,
  error,
  paused,
}

class FaceDetectionState {
  final FaceDetectionStatus status;
  final CameraStatus cameraStatus;
  final Object? cameraController;
  final FaceDetectionResult result;
  final String? error;
  final bool isProcessing;

  const FaceDetectionState({
    required this.status,
    required this.cameraStatus,
    required this.cameraController,
    required this.result,
    required this.error,
    required this.isProcessing,
  });

  factory FaceDetectionState.initial() => FaceDetectionState(
    status: FaceDetectionStatus.idle,
    cameraStatus: CameraStatus.idle,
    cameraController: null,
    result: FaceDetectionResult.empty(),
    error: null,
    isProcessing: false,
  );

  int get faceCount => result.faceCount;
  bool get isFaceDetected => faceCount == 1;
  bool get hasMultipleFaces => faceCount > 1;
  bool get isCameraReady =>
      cameraStatus == CameraStatus.ready ||
      cameraStatus == CameraStatus.streaming;
  bool get hasCameraError =>
      cameraStatus == CameraStatus.failed ||
      cameraStatus == CameraStatus.noFrontCamera ||
      cameraStatus == CameraStatus.permissionDenied ||
      cameraStatus == CameraStatus.permissionPermanentlyDenied;

  FaceDetectionState copyWith({
    FaceDetectionStatus? status,
    CameraStatus? cameraStatus,
    Object? cameraController,
    bool clearCameraController = false,
    FaceDetectionResult? result,
    String? error,
    bool clearError = false,
    bool? isProcessing,
  }) {
    return FaceDetectionState(
      status: status ?? this.status,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      cameraController:
          clearCameraController
              ? null
              : cameraController ?? this.cameraController,
      result: result ?? this.result,
      error: clearError ? null : error ?? this.error,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class FaceDetectionController extends StateNotifier<FaceDetectionState> {
  FaceDetectionController({
    required CameraService camera,
    required FaceDetectionService detector,
  }) : _camera = camera,
       _detector = detector,
       super(FaceDetectionState.initial()) {
    _cameraSubscription = _camera.stateStream.listen(_onCameraState);
  }

  final CameraService _camera;
  final FaceDetectionService _detector;
  StreamSubscription<CameraState>? _cameraSubscription;
  bool _processing = false;
  bool _starting = false;
  bool _closed = false;
  int _generation = 0;

  void _onCameraState(CameraState cameraState) {
    if (!mounted || _closed) return;
    state = state.copyWith(
      cameraStatus: cameraState.status,
      cameraController: _camera.controller,
      clearCameraController: _camera.controller == null,
      error: cameraState.errorMessage,
      clearError: cameraState.errorMessage == null,
    );
  }

  Future<void> start({int maxFps = 10}) async {
    if (_closed || _starting || _camera.isStreaming) return;
    _starting = true;
    final generation = ++_generation;
    state = state.copyWith(
      status: FaceDetectionStatus.initializing,
      clearError: true,
      result: FaceDetectionResult.empty(),
    );

    try {
      await _camera.initialize().timeout(const Duration(seconds: 12));
      if (_isStale(generation)) return;
      state = state.copyWith(
        cameraStatus: _camera.state.status,
        cameraController: _camera.controller,
        clearCameraController: _camera.controller == null,
        error: _camera.state.errorMessage,
        clearError: _camera.state.errorMessage == null,
      );
      if (_camera.state.isFailed ||
          _camera.state.hasPermissionError ||
          _camera.state.status == CameraStatus.noFrontCamera) {
        state = state.copyWith(status: FaceDetectionStatus.error);
        return;
      }

      await _camera
          .startStream(
            maxFps: maxFps,
            onFrame: (image) => _processFrame(image, generation),
          )
          .timeout(const Duration(seconds: 8));
      if (_isStale(generation)) return;
      state = state.copyWith(
        status: FaceDetectionStatus.searching,
        cameraStatus: _camera.state.status,
        cameraController: _camera.controller,
        clearError: true,
      );
    } catch (error) {
      if (!_isStale(generation)) {
        state = state.copyWith(
          status: FaceDetectionStatus.error,
          error: 'Unable to start face detection. Please try again.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _processFrame(CameraImage image, int generation) async {
    if (_processing || _isStale(generation)) return;
    _processing = true;
    if (mounted) state = state.copyWith(isProcessing: true);
    try {
      final result = await _detector.process(
        image,
        rotationDegrees: _camera.imageRotationDegrees,
      );
      if (_isStale(generation)) return;
      final status = switch (result.faceCount) {
        0 => FaceDetectionStatus.searching,
        1 => FaceDetectionStatus.detected,
        _ => FaceDetectionStatus.multipleFaces,
      };
      state = state.copyWith(status: status, result: result, clearError: true);
    } catch (error) {
      if (!_isStale(generation)) {
        state = state.copyWith(
          status: FaceDetectionStatus.error,
          error: 'Face detection failed. Please try again.',
        );
      }
    } finally {
      _processing = false;
      if (!_isStale(generation)) {
        state = state.copyWith(isProcessing: false);
      }
    }
  }

  Future<void> stop() async {
    if (_closed) return;
    ++_generation;
    await _camera.stopStream();
    _processing = false;
    if (mounted) {
      state = state.copyWith(
        status: FaceDetectionStatus.paused,
        isProcessing: false,
      );
    }
  }

  Future<void> retry() async {
    await stop();
    if (!_closed) await start();
  }

  bool _isStale(int generation) =>
      _closed || !mounted || generation != _generation;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    ++_generation;
    await _cameraSubscription?.cancel();
    _cameraSubscription = null;
    await _camera.stopStream();
    await _detector.dispose();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}

final faceDetectionServiceProvider = Provider.autoDispose<FaceDetectionService>(
  (ref) => MlKitFaceDetectionService(),
);

final faceDetectionProvider = StateNotifierProvider.autoDispose<
  FaceDetectionController,
  FaceDetectionState
>((ref) {
  return FaceDetectionController(
    camera: ref.watch(cameraServiceProvider),
    detector: ref.watch(faceDetectionServiceProvider),
  );
});
