import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';

// -----------------------------------------------------------------
// A minimal fake that satisfies the interface without touching the
// camera plugin. Each test drives state manually.
// -----------------------------------------------------------------
class FakeCameraService implements CameraService {
  final _stateCtrl = StreamController<CameraState>.broadcast();
  CameraState _state = const CameraState.idle();
  bool _streaming = false;
  FrameCallback? _callback;

  @override
  Stream<CameraState> get stateStream => _stateCtrl.stream;

  @override
  CameraState get state => _state;

  @override
  int get sensorOrientation => 0;

  @override
  int get imageRotationDegrees => 0;

  @override
  dynamic get controller => null;

  @override
  bool get isStreaming => _streaming;

  @override
  Future<void> initialize() async {
    _emit(_state.copyWith(status: CameraStatus.ready));
  }

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    _callback = onFrame;
    _streaming = true;
    _emit(_state.copyWith(status: CameraStatus.streaming));
    await onFrame(FakeCameraFrame());
  }

  @override
  Future<void> stopStream() async {
    _streaming = false;
    _emit(_state.copyWith(status: CameraStatus.ready));
  }

  @override
  Future<void> dispose() async {
    _streaming = false;
    await _stateCtrl.close();
  }

  @override
  Future<bool> shouldOpenSettings() async => false;

  void _emit(CameraState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  /// Test hook: simulate the platform delivering a frame.
  void simulateFrame(CameraImage image) => _callback?.call(image);
}

class FakeCameraFrame extends Fake implements CameraImage {}

void main() {
  group('CameraService contract', () {
    late FakeCameraService service;

    setUp(() {
      service = FakeCameraService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('initial state is idle', () {
      expect(service.state.status, CameraStatus.idle);
      expect(service.isStreaming, isFalse);
    });

    test('initialize transitions to ready', () async {
      await service.initialize();
      expect(service.state.status, CameraStatus.ready);
    });

    test('startStream transitions to streaming', () async {
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      expect(service.state.status, CameraStatus.streaming);
      expect(service.isStreaming, isTrue);
    });

    test('stopStream returns to ready', () async {
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      await service.stopStream();
      expect(service.state.status, CameraStatus.ready);
      expect(service.isStreaming, isFalse);
    });

    test('state stream emits each transition', () async {
      final events = <CameraStatus>[];
      final sub = service.stateStream.listen((s) => events.add(s.status));

      await service.initialize();
      await service.startStream(onFrame: (_) {});
      await service.stopStream();
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        CameraStatus.ready,
        CameraStatus.streaming,
        CameraStatus.ready,
      ]);

      await sub.cancel();
    });

    test('initialize is idempotent when already ready', () async {
      await service.initialize();
      expect(service.state.status, CameraStatus.ready);

      // Calling again should keep it ready without re-running or error
      await service.initialize();
      expect(service.state.status, CameraStatus.ready);
    });

    test('CameraState helper properties report correctly', () {
      const idleState = CameraState.idle();
      expect(idleState.isFailed, isFalse);
      expect(idleState.isReadyOrStreaming, isFalse);
      expect(idleState.hasPermissionError, isFalse);

      const readyState = CameraState(status: CameraStatus.ready);
      expect(readyState.isReadyOrStreaming, isTrue);

      const streamingState = CameraState(status: CameraStatus.streaming);
      expect(streamingState.isReadyOrStreaming, isTrue);

      const deniedState = CameraState(status: CameraStatus.permissionDenied);
      expect(deniedState.hasPermissionError, isTrue);

      const permDeniedState = CameraState(
        status: CameraStatus.permissionPermanentlyDenied,
      );
      expect(permDeniedState.hasPermissionError, isTrue);

      const failedState = CameraState(status: CameraStatus.failed);
      expect(failedState.isFailed, isTrue);
    });

    test('re-initialization after stopStream succeeds cleanly', () async {
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      expect(service.isStreaming, isTrue);

      await service.stopStream();
      expect(service.isStreaming, isFalse);
      expect(service.state.status, CameraStatus.ready);

      // Can start stream again
      await service.startStream(onFrame: (_) {});
      expect(service.isStreaming, isTrue);
      expect(service.state.status, CameraStatus.streaming);
    });
  });
}
