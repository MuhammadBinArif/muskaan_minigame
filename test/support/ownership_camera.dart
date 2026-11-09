import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';

class OwnershipCameraService implements CameraService {
  final StreamController<CameraState> _states =
      StreamController<CameraState>.broadcast();
  CameraState _state = const CameraState.idle();
  bool failInitialization = false;
  bool _streaming = false;

  @override
  Stream<CameraState> get stateStream => _states.stream;
  @override
  CameraState get state => _state;
  @override
  dynamic get controller => null;
  @override
  int get sensorOrientation => 0;
  @override
  int get imageRotationDegrees => 0;
  @override
  bool get isStreaming => _streaming;

  void _emit(CameraState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  @override
  Future<void> initialize() async {
    if (failInitialization) {
      _emit(
        const CameraState(
          status: CameraStatus.failed,
          errorMessage: 'Simulated camera startup failure',
        ),
      );
      return;
    }
    _emit(const CameraState(status: CameraStatus.ready));
  }

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    _streaming = true;
    _emit(const CameraState(status: CameraStatus.streaming));
    await onFrame(_OwnershipCameraImage());
  }

  void interrupt() {
    _streaming = false;
    _emit(
      const CameraState(
        status: CameraStatus.failed,
        errorMessage: 'Simulated camera interruption',
      ),
    );
  }

  @override
  Future<void> stopStream() async {
    _streaming = false;
    _emit(const CameraState(status: CameraStatus.ready));
  }

  @override
  Future<void> dispose() async {
    _streaming = false;
    _emit(const CameraState.idle());
  }

  Future<void> close() => _states.close();

  @override
  Future<bool> shouldOpenSettings() async => false;
}

class _OwnershipCameraImage extends Fake implements CameraImage {}
