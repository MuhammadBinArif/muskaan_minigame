import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_state_machine.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';

class MockCameraService implements CameraService {
  final _stateCtrl = StreamController<CameraState>.broadcast();
  CameraState _state = const CameraState.idle();
  bool _streaming = false;
  FrameCallback? callback;
  bool shouldFailInit = false;
  bool isDisposed = false;

  @override
  Stream<CameraState> get stateStream => _stateCtrl.stream;

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

  @override
  Future<void> initialize() async {
    if (shouldFailInit) {
      _state = const CameraState(
        status: CameraStatus.failed,
        errorMessage: 'Camera init failed',
      );
      return;
    }
    _state = const CameraState(status: CameraStatus.ready);
    _stateCtrl.add(_state);
  }

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    callback = onFrame;
    _streaming = true;
    _state = const CameraState(status: CameraStatus.streaming);
    _stateCtrl.add(_state);
  }

  @override
  Future<void> stopStream() async {
    _streaming = false;
    _state = const CameraState(status: CameraStatus.ready);
    _stateCtrl.add(_state);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _streaming = false;
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  @override
  Future<bool> shouldOpenSettings() async => false;
}

class MockVisionService implements VisionService {
  VisionFrame nextFrame = VisionFrame.noFace();
  Completer<VisionFrame>? pendingFrame;
  bool isDisposed = false;

  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    if (pendingFrame case final pending?) return pending.future;
    return nextFrame;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}

class FakeCameraImage extends Fake implements CameraImage {}

class ReusableMockCamera extends MockCameraService {
  @override
  Future<void> dispose() async {
    _streaming = false;
    _state = const CameraState.idle();
  }
}

void main() {
  group('MouthStateMachine unit tests', () {
    late CalibrationConfig config;
    late MouthStateMachine machine;

    setUp(() {
      config = const CalibrationConfig(
        closedBaseline: 0.05,
        openThreshold: 0.15,
        calibrated: true,
      );
      machine = MouthStateMachine(
        config: config,
        smoothingAlpha: 1.0, // Snap directly for deterministic unit tests
        minimumOpenDuration: const Duration(milliseconds: 100),
        minimumEvidenceDuration: Duration.zero,
      );
    });

    test('initial state is idle and closed', () {
      expect(machine.isOpen, isFalse);
    });

    test('transitions from closed to open when exceeding threshold', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final t1 = machine.update(0.18, now: now);

      expect(t1.isOpen, isTrue);
      expect(t1.justOpened, isTrue);
      expect(t1.justClosed, isFalse);
      expect(machine.isOpen, isTrue);

      // Next frame with same openness should NOT trigger justOpened again
      final t2 = machine.update(
        0.20,
        now: now.add(const Duration(milliseconds: 50)),
      );
      expect(t2.isOpen, isTrue);
      expect(t2.justOpened, isFalse);
      expect(t2.justClosed, isFalse);
    });

    test('transitions to closed only after minimumOpenDuration', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      machine.update(0.20, now: now);

      // Attempt to close before 100ms
      final fastClose = machine.update(
        0.02,
        now: now.add(const Duration(milliseconds: 50)),
      );
      expect(fastClose.isOpen, isTrue); // Held open by minimumOpenDuration
      expect(fastClose.justClosed, isFalse);

      // Attempt to close after 150ms
      final normalClose = machine.update(
        0.02,
        now: now.add(const Duration(milliseconds: 150)),
      );
      expect(normalClose.isOpen, isFalse);
      expect(normalClose.justClosed, isTrue);
      expect(machine.isOpen, isFalse);
    });

    test('reset clears state and open flag', () {
      machine.update(0.25);
      expect(machine.isOpen, isTrue);

      machine.reset();
      expect(machine.isOpen, isFalse);
    });

    test('one noisy frame cannot open the mouth state', () {
      final guarded = MouthStateMachine(
        config: config,
        smoothingAlpha: 1,
        minimumEvidenceDuration: const Duration(milliseconds: 70),
      );
      final now = DateTime(2026);
      expect(guarded.update(.2, now: now).isOpen, isFalse);
      expect(
        guarded
            .update(.02, now: now.add(const Duration(milliseconds: 70)))
            .isOpen,
        isFalse,
      );
    });
  });

  group('MouthTrackingController integration tests', () {
    late MockCameraService mockCamera;
    late MockVisionService mockVision;
    late ProviderContainer container;

    setUp(() {
      mockCamera = MockCameraService();
      mockVision = MockVisionService();
      container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(mockCamera),
          visionServiceProvider.overrideWithValue(mockVision),
          calibrationConfigProvider.overrideWith(
            (ref) => const CalibrationConfig(
              closedBaseline: 0.05,
              openThreshold: 0.15,
              calibrated: true,
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state matches configuration', () {
      final state = container.read(mouthTrackingProvider);
      expect(state.isCalibrated, isTrue);
      expect(state.isStreaming, isFalse);
      expect(state.isFaceDetected, isFalse);
      expect(state.latestResult.faceDetected, isFalse);
    });

    test('startTracking handles camera failure cleanly', () async {
      mockCamera.shouldFailInit = true;
      final controller = container.read(mouthTrackingProvider.notifier);

      await controller.startTracking();

      final state = container.read(mouthTrackingProvider);
      expect(state.isStreaming, isFalse);
      expect(state.error, contains('Camera init failed'));
    });

    test('frame pipeline updates state and detects mouth opening', () async {
      final controller = container.read(mouthTrackingProvider.notifier);
      await controller.startTracking();

      expect(mockCamera.isStreaming, isTrue);
      expect(container.read(mouthTrackingProvider).isStreaming, isTrue);

      // Deliver frame with face detected and open mouth
      final capturedAt = DateTime.now();
      mockVision.nextFrame = VisionFrame(
        observation: FaceTrackingObservation(
          faceDetected: true,
          faceCount: 1,
          facePosition: const Offset(0.5, 0.5),
          faceSize: 0.4,
          mouthPosition: const Offset(0.5, 0.6),
          mouthOpenness: 0.20,
          capturedAt: capturedAt,
        ),
      );

      mockCamera.callback?.call(FakeCameraImage());
      await Future<void>.delayed(const Duration(milliseconds: 80));
      mockVision.nextFrame = VisionFrame(
        observation: FaceTrackingObservation(
          faceDetected: true,
          faceCount: 1,
          facePosition: const Offset(0.5, 0.5),
          faceSize: 0.4,
          mouthPosition: const Offset(0.5, 0.6),
          mouthOpenness: 0.20,
          capturedAt: capturedAt.add(const Duration(milliseconds: 80)),
        ),
      );
      mockCamera.callback?.call(FakeCameraImage());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updatedState = container.read(mouthTrackingProvider);
      expect(updatedState.isFaceDetected, isTrue);
      expect(updatedState.latestResult.faceDetected, isTrue);
      expect(
        updatedState.latestResult.normalizedPosition,
        const Offset(0.5, 0.6),
      );
      expect(updatedState.latestResult.openness, greaterThan(0.0));
      expect(updatedState.latestTransition.isOpen, isTrue);
      expect(updatedState.latestTransition.justOpened, isTrue);

      // Stop tracking
      await controller.stopTracking();
      expect(container.read(mouthTrackingProvider).isStreaming, isFalse);
      expect(mockCamera.isStreaming, isFalse);
    });

    test('updateCalibration changes calibrated status', () {
      final controller = container.read(mouthTrackingProvider.notifier);
      controller.updateCalibration(
        const CalibrationConfig(
          closedBaseline: 0.04,
          openThreshold: 0.12,
          calibrated: false,
        ),
      );

      expect(container.read(mouthTrackingProvider).isCalibrated, isFalse);
    });

    test('stale and future frames cannot update face tracking', () async {
      final controller = container.read(mouthTrackingProvider.notifier);
      await controller.startTracking();
      for (final timestamp in [
        DateTime.now().subtract(const Duration(seconds: 10)),
        DateTime.now().add(const Duration(seconds: 10)),
      ]) {
        mockVision.nextFrame = VisionFrame(
          observation: FaceTrackingObservation(
            faceDetected: true,
            faceCount: 1,
            facePosition: const Offset(.5, .5),
            faceSize: .4,
            mouthPosition: const Offset(.5, .6),
            mouthOpenness: .2,
            smileProbability: .9,
            capturedAt: timestamp,
          ),
        );
        await mockCamera.callback!(FakeCameraImage());
        expect(container.read(mouthTrackingProvider).isFaceDetected, isFalse);
        expect(container.read(mouthTrackingProvider).smileProbability, isNull);
      }
    });

    test(
      'an in-flight frame cannot update state after tracking stops',
      () async {
        final controller = container.read(mouthTrackingProvider.notifier);
        await controller.startTracking();
        final pending = Completer<VisionFrame>();
        mockVision.pendingFrame = pending;

        mockCamera.callback?.call(FakeCameraImage());
        await Future<void>.delayed(Duration.zero);
        await controller.stopTracking();

        pending.complete(
          VisionFrame(
            observation: FaceTrackingObservation(
              faceDetected: true,
              faceCount: 1,
              facePosition: const Offset(0.5, 0.5),
              faceSize: 0.4,
              mouthPosition: const Offset(0.5, 0.6),
              mouthOpenness: 0.20,
              capturedAt: DateTime.now(),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final stopped = container.read(mouthTrackingProvider);
        expect(stopped.isStreaming, isFalse);
        expect(stopped.tracking.status, FaceTrackingStatus.searching);
        expect(stopped.latestResult.faceDetected, isFalse);
      },
    );
  });

  test(
    'old camera callback cannot replace restarted tracking observation',
    () async {
      final camera = ReusableMockCamera();
      final vision = MockVisionService();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWithValue(vision),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(mouthTrackingProvider.notifier);
      VisionFrame frame(double smile) => VisionFrame(
        observation: FaceTrackingObservation(
          faceDetected: true,
          faceCount: 1,
          facePosition: const Offset(.5, .5),
          faceSize: .4,
          mouthPosition: const Offset(.5, .6),
          mouthOpenness: .1,
          smileProbability: smile,
          capturedAt: DateTime.now(),
        ),
      );
      await controller.startTracking();
      final pending = Completer<VisionFrame>();
      vision.pendingFrame = pending;
      final oldResult = camera.callback!(FakeCameraImage());
      await controller.stopTracking();
      vision.pendingFrame = null;
      await controller.startTracking();
      vision.nextFrame = frame(.2);
      await camera.callback!(FakeCameraImage());
      expect(container.read(mouthTrackingProvider).smileProbability, .2);
      pending.complete(frame(.9));
      await oldResult;
      expect(container.read(mouthTrackingProvider).smileProbability, .2);
      vision.nextFrame = frame(.3);
      await camera.callback!(FakeCameraImage());
      expect(container.read(mouthTrackingProvider).smileProbability, .3);
    },
  );

  group('GameSessionNotifier continuous mouth tracking integration', () {
    test(
      'open mouth catches edible food in mouth zone and increases score and combo',
      () {
        final notifier = GameSessionNotifier();
        addTearDown(notifier.dispose);
        notifier.startGame();

        // Seed an edible food right in the mouth zone (0.5, 0.52)
        final food = const FoodItem(
          type: FoodItemType.gold,
          positionX: 0.5,
          positionY: 0.52,
          velocityX: 0,
          velocityY: 0.01,
          size: 0.08,
          creationTime: 0,
        );
        notifier.state = notifier.state.copyWith(activeFoods: [food]);

        expect(notifier.state.stats.score, 0);
        expect(notifier.state.stats.combo, 0);

        // Trigger continuous mouth tracking while mouth is open
        notifier.updateMouthTracking(
          isOpen: true,
          isActionable: true,
          mouthX: 0.5,
          mouthY: 0.52,
        );

        expect(notifier.state.stats.score, 100);
        expect(notifier.state.stats.combo, 1);
        expect(notifier.state.stats.catches, 1);
        expect(notifier.state.activeFoods, isEmpty);
        expect(notifier.state.stats.lives, 3);
      },
    );

    test(
      'open mouth catching hot tea hazard costs a life and resets combo',
      () {
        final notifier = GameSessionNotifier();
        addTearDown(notifier.dispose);
        notifier.startGame();

        // First score a combo
        final gold = const FoodItem(
          type: FoodItemType.gold,
          positionX: 0.5,
          positionY: 0.52,
          velocityX: 0,
          velocityY: 0.01,
          size: 0.08,
          creationTime: 0,
        );
        notifier.state = notifier.state.copyWith(activeFoods: [gold]);
        notifier.updateMouthTracking(isOpen: true, isActionable: true);
        expect(notifier.state.stats.combo, 1);

        notifier.updateMouthTracking(isOpen: false, isActionable: true);
        // Now hit a tea hazard
        final tea = const FoodItem(
          type: FoodItemType.tea,
          positionX: 0.5,
          positionY: 0.52,
          velocityX: 0,
          velocityY: 0.01,
          size: 0.08,
          creationTime: 0,
        );
        notifier.state = notifier.state.copyWith(activeFoods: [tea]);
        notifier.updateMouthTracking(isOpen: true, isActionable: true);

        expect(notifier.state.stats.lives, 2);
        expect(notifier.state.stats.combo, 0);
        expect(notifier.state.activeFoods, isEmpty);
      },
    );

    test('closed mouth does not catch food in mouth zone', () {
      final notifier = GameSessionNotifier();
      addTearDown(notifier.dispose);
      notifier.startGame();

      final food = const FoodItem(
        type: FoodItemType.gold,
        positionX: 0.5,
        positionY: 0.52,
        velocityX: 0,
        velocityY: 0.01,
        size: 0.08,
        creationTime: 0,
      );
      notifier.state = notifier.state.copyWith(activeFoods: [food]);

      notifier.updateMouthTracking(
        isOpen: false,
        isActionable: true,
        mouthX: 0.5,
        mouthY: 0.52,
      );

      expect(notifier.state.stats.score, 0);
      expect(notifier.state.activeFoods.length, 1);
    });

    test('non-actionable or invalid tracking is safely ignored', () {
      final notifier = GameSessionNotifier();
      addTearDown(notifier.dispose);
      notifier.startGame();

      final food = const FoodItem(
        type: FoodItemType.gold,
        positionX: 0.5,
        positionY: 0.52,
        velocityX: 0,
        velocityY: 0.01,
        size: 0.08,
        creationTime: 0,
      );
      notifier.state = notifier.state.copyWith(activeFoods: [food]);

      notifier.updateMouthTracking(
        isOpen: true,
        isActionable: false,
        mouthX: 0.5,
        mouthY: 0.52,
      );

      expect(notifier.state.stats.score, 0);
      expect(notifier.state.activeFoods.length, 1);
    });
  });
}
