import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_provider.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_result.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_service.dart';

class FakeCamera extends Fake implements CameraService {
  final states = StreamController<CameraState>.broadcast();
  CameraState current = const CameraState.idle();
  FrameCallback? callback;
  bool streaming = false;
  int stopCalls = 0;

  @override
  Stream<CameraState> get stateStream => states.stream;
  @override
  CameraState get state => current;
  @override
  Object? get controller => null;
  @override
  int get sensorOrientation => 90;
  @override
  int get imageRotationDegrees => 270;
  @override
  bool get isStreaming => streaming;

  @override
  Future<void> initialize() async {
    current = const CameraState(status: CameraStatus.ready);
    states.add(current);
  }

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    callback = onFrame;
    streaming = true;
    current = const CameraState(status: CameraStatus.streaming);
    states.add(current);
  }

  Future<void> send(CameraImage image) async {
    await callback?.call(image);
  }

  @override
  Future<void> stopStream() async {
    stopCalls++;
    streaming = false;
    current = const CameraState(status: CameraStatus.ready);
    states.add(current);
  }

  @override
  Future<void> dispose() async => states.close();
  @override
  Future<bool> shouldOpenSettings() async => false;
}

class FakeDetector implements FaceDetectionService {
  FaceDetectionResult next = FaceDetectionResult.empty();
  Completer<FaceDetectionResult>? pending;
  Object? error;
  int calls = 0;
  int? receivedRotation;
  bool disposed = false;

  @override
  Future<FaceDetectionResult> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    calls++;
    receivedRotation = rotationDegrees;
    final currentError = error;
    if (currentError != null) throw currentError;
    final currentPending = pending;
    if (currentPending != null) return currentPending.future;
    return next;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeCameraImage extends Fake implements CameraImage {}

FaceDetectionResult resultWithFaces(int count) => FaceDetectionResult(
  faces: List.generate(
    count,
    (index) => DetectedFace(boundingBox: Rect.fromLTWH(index * 10, 0, 50, 50)),
  ),
  processedAt: DateTime(2026),
);

void main() {
  late FakeCamera camera;
  late FakeDetector detector;
  late FaceDetectionController controller;

  setUp(() {
    camera = FakeCamera();
    detector = FakeDetector();
    controller = FaceDetectionController(camera: camera, detector: detector);
  });

  tearDown(() async {
    await controller.close();
    controller.dispose();
    await camera.dispose();
  });

  test('maps zero, one, and multiple faces to distinct states', () async {
    await controller.start();
    expect(controller.state.status, FaceDetectionStatus.searching);

    detector.next = resultWithFaces(1);
    await camera.send(FakeCameraImage());
    expect(controller.state.status, FaceDetectionStatus.detected);
    expect(controller.state.faceCount, 1);

    detector.next = resultWithFaces(2);
    await camera.send(FakeCameraImage());
    expect(controller.state.status, FaceDetectionStatus.multipleFaces);
    expect(controller.state.faceCount, 2);

    detector.next = resultWithFaces(0);
    await camera.send(FakeCameraImage());
    expect(controller.state.status, FaceDetectionStatus.searching);
    expect(controller.state.faceCount, 0);
    expect(detector.receivedRotation, 270);
  });

  test('drops a frame while inference is already running', () async {
    await controller.start();
    detector.pending = Completer<FaceDetectionResult>();

    final first = camera.send(FakeCameraImage());
    await Future<void>.delayed(Duration.zero);
    final second = camera.send(FakeCameraImage());
    await Future<void>.delayed(Duration.zero);

    expect(detector.calls, 1);
    detector.pending!.complete(resultWithFaces(1));
    await first;
    await second;
    expect(controller.state.status, FaceDetectionStatus.detected);
  });

  test('reports inference errors separately from no-face results', () async {
    await controller.start();
    detector.error = StateError('native detector unavailable');

    await camera.send(FakeCameraImage());

    expect(controller.state.status, FaceDetectionStatus.error);
    expect(controller.state.error, 'Face detection failed. Please try again.');
    expect(
      controller.state.error,
      isNot(contains('native detector unavailable')),
    );
  });

  test(
    'stop invalidates pending results and close disposes detector',
    () async {
      await controller.start();
      detector.pending = Completer<FaceDetectionResult>();
      final processing = camera.send(FakeCameraImage());
      await Future<void>.delayed(Duration.zero);

      await controller.stop();
      detector.pending!.complete(resultWithFaces(1));
      await processing;

      expect(controller.state.status, FaceDetectionStatus.paused);
      expect(controller.state.faceCount, 0);
      await controller.close();
      expect(detector.disposed, isTrue);
      expect(camera.stopCalls, greaterThanOrEqualTo(1));
    },
  );
}
