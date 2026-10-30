import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/data/camera_service_impl.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/game/data/tilt_sensor.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/gameplay_screen.dart';
import 'package:muskaan_minigame/features/game/presentation/flame/muskaan_flame_game.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../camera/camera_sevice_imple_test.dart';
import '../camera/camera_service_regression_test.dart'
    show SessionFake, front, ImageFake;
import '../tracking/vision_service_disposal_test.dart' show ImageStub;

class GameplayDetector extends Fake implements FaceDetector {
  double smile = 0;
  int calls = 0;
  @override
  Future<List<Face>> processImage(InputImage image) async {
    calls++;
    return [
      Face(
        boundingBox: const Rect.fromLTWH(.4, .4, 1.2, 1.2),
        landmarks: const {},
        contours: const {},
        smilingProbability: smile,
      ),
    ];
  }

  @override
  Future<void> close() async {}
}

class HoldingVision implements VisionService {
  final started = Completer<void>();
  final result = Completer<VisionFrame>();
  VisionFrame? nextFrame;
  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) {
    if (!started.isCompleted) started.complete();
    return nextFrame == null ? result.future : Future.value(nextFrame);
  }

  @override
  Future<void> dispose() async {}
}

class CapturingTiltSensor extends TiltSensor {
  final callbacks = <void Function(double)>[];
  final errors = <void Function(Object)>[];
  bool active = false;
  int activeCount = 0;
  int maxActive = 0;

  @override
  void start({
    required void Function(double) onAngle,
    required void Function(Object) onError,
  }) {
    callbacks.add(onAngle);
    errors.add(onError);
    active = true;
    activeCount++;
    if (activeCount > maxActive) maxActive = activeCount;
  }

  @override
  Future<void> stop() async {
    if (active) activeCount--;
    active = false;
  }
}

class CountingSession extends GameSessionNotifier {
  int starts = 0;
  void putFoodAtMouth() {
    state = state.copyWith(
      activeFoods: [
        const FoodItem(
          type: FoodItemType.gold,
          positionX: .5,
          positionY: MuskaanFlameGame.targetY,
          velocityX: 0,
          velocityY: 0,
          size: .05,
          creationTime: 0,
        ),
      ],
    );
  }

  @override
  void startGame() {
    starts++;
    super.startGame();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('production smile pipeline rearms after camera restart', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    var requests = 0;
    final detector = GameplayDetector();
    final sessions = <SessionFake>[];
    final camera = CameraServiceImpl(
      clock: () => now,
      permissionStatus: () async => PermissionStatus.granted,
      discover: () async => [front],
      createSession: (_) {
        final session = SessionFake();
        sessions.add(session);
        return session;
      },
    );
    final container = ProviderContainer(
      overrides: [
        cameraServiceProvider.overrideWithValue(camera),
        faceDetectorFactoryProvider.overrideWithValue(() => detector),
        trackingClockProvider.overrideWithValue(() => now),
        gameplayClockProvider.overrideWithValue(() => now),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          requests++;
          request();
        }),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Use touch controls'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    Future<void> send(SessionFake session, double probability) async {
      detector.smile = probability;
      now = now.add(const Duration(milliseconds: 100));
      session.deliver!(ImageStub());
      await tester.pump();
    }

    final first = sessions.single;
    await send(first, .1);
    await send(first, .8);
    await send(first, .8);
    await send(first, .8);
    expect(requests, 1);
    final dynamic screen = tester.state(find.byType(GameplayScreen));
    screen.handleLifecycleEvent(AppLifecycleState.paused);
    await tester.pump();
    expect(first.disposals, 1);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sessions.length, 2);
    final second = sessions.last;
    await send(second, .8);
    await send(second, .8);
    await send(second, .8);
    expect(requests, 1);
    final before = detector.calls;
    first.deliver!(ImageStub());
    await tester.pump();
    expect(detector.calls, before);
    expect(requests, 1);
    await send(second, .1);
    await send(second, .8);
    await send(second, .8);
    await send(second, .8);
    expect(requests, 2);
    await send(second, .8);
    await send(second, .8);
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'interrupted restart candidate is released before player recovery',
    (tester) async {
      final sessions = <SessionFake>[];
      final blocked = Completer<void>();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final candidate = SessionFake();
          if (sessions.length == 1) candidate.initialization = blocked;
          sessions.add(candidate);
          return candidate;
        },
      );
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Use touch controls'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      await tester.pump();
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      expect(sessions.length, 2);
      expect(sessions.last.streamStarts, 0);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      blocked.complete();
      await tester.pump();
      await tester.pump();
      expect(sessions.length, 2);
      expect(sessions[1].disposals, 1);
      expect(sessions[1].active, isFalse);
      expect(sessions[1].streamStarts, 0);
      expect(sessions[1].streamStops, 0);
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.paused,
      );
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sessions.length, 3);
      expect(sessions[2].active, isTrue);
      expect(sessions[2].streamStarts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sessions[0].disposals, 1);
      expect(sessions[2].streamStops, 1);
      expect(sessions[2].disposals, 1);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 3);
      expect(tester.takeException(), isNull);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets(
    'repeated lifecycle callbacks and disposal cancel pending player restart',
    (tester) async {
      final sessions = <SessionFake>[];
      final candidateReady = Completer<void>();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final session = SessionFake();
          if (sessions.isNotEmpty) session.initialization = candidateReady;
          sessions.add(session);
          return session;
        },
      );
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Use touch controls'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      await tester.pump();
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 1);
      expect(sessions.first.disposals, 1);
      expect(sessions.first.streamStarts, 1);
      expect(sessions.first.streamStops, 1);
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      expect(sessions.length, 2);
      expect(sessions.last.active, isFalse);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 2);
      expect(sessions.last.streamStarts, 0);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      candidateReady.complete();
      await tester.pump();
      await tester.pump();
      expect(sessions.length, 2);
      expect(sessions.last.active, isFalse);
      expect(sessions.last.disposals, 1);
      expect(sessions.last.streamStarts, 0);
      expect(sessions.last.streamStops, 0);
      expect(camera.isStreaming, isFalse);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 2);
      expect(tester.takeException(), isNull);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets('pause drains an active camera frame before player resumes', (
    tester,
  ) async {
    final sessions = <SessionFake>[];
    final vision = HoldingVision();
    var frameTime = DateTime.utc(2026);
    var requests = 0;
    final camera = CameraServiceImpl(
      clock: () => frameTime,
      permissionStatus: () async => PermissionStatus.granted,
      discover: () async => [front],
      createSession: (_) {
        final session = SessionFake();
        sessions.add(session);
        return session;
      },
    );
    final container = ProviderContainer(
      overrides: [
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWithValue(vision),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          requests++;
          request();
        }),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Use touch controls'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    sessions.first.deliver!(ImageFake());
    await vision.started.future;
    final dynamic screen = tester.state(find.byType(GameplayScreen));
    screen.handleLifecycleEvent(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.paused);
    expect(sessions.length, 1);
    expect(sessions.first.disposals, 0);
    screen.handleLifecycleEvent(AppLifecycleState.resumed);
    await tester.pump();
    expect(sessions.length, 1);
    vision.result.complete(VisionFrame.noFace());
    await tester.pump();
    await tester.pump();
    expect(sessions.first.disposals, 1);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sessions.length, 2);
    expect(sessions.last.active, isTrue);
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    vision.nextFrame = VisionFrame(
      observation: FaceTrackingObservation(
        faceDetected: true,
        faceCount: 1,
        facePosition: const Offset(.5, .5),
        faceSize: .4,
        mouthPosition: const Offset(.5, .6),
        mouthOpenness: .1,
        smileProbability: .2,
        capturedAt: DateTime.now(),
      ),
    );
    sessions.last.deliver!(ImageFake());
    await tester.pump();
    expect(container.read(mouthTrackingProvider).smileProbability, .2);
    vision.nextFrame = VisionFrame(
      observation: FaceTrackingObservation(
        faceDetected: true,
        faceCount: 1,
        facePosition: const Offset(.5, .5),
        faceSize: .4,
        mouthPosition: const Offset(.5, .6),
        mouthOpenness: .1,
        smileProbability: .9,
        capturedAt: DateTime.now(),
      ),
    );
    sessions.first.deliver!(ImageFake());
    await tester.pump();
    expect(container.read(mouthTrackingProvider).smileProbability, .2);
    expect(requests, 0);
    frameTime = frameTime.add(const Duration(milliseconds: 100));
    vision.nextFrame = VisionFrame(
      observation: FaceTrackingObservation(
        faceDetected: true,
        faceCount: 1,
        facePosition: const Offset(.5, .5),
        faceSize: .4,
        mouthPosition: const Offset(.5, .6),
        mouthOpenness: .1,
        smileProbability: .3,
        capturedAt: DateTime.now(),
      ),
    );
    sessions.last.deliver!(ImageFake());
    await tester.pump();
    expect(container.read(mouthTrackingProvider).smileProbability, .3);
    expect(requests, 0);
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sessions.last.disposals, 1);
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'leaving gameplay drains in-flight camera frame and ignores late lifecycle resume',
    (tester) async {
      final session = SessionFake();
      var creations = 0;
      final vision = HoldingVision();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          creations++;
          return session;
        },
      );
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWithValue(vision),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(camera.isStreaming, isTrue);
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      session.deliver!(ImageFake());
      await vision.started.future;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(session.disposals, 0);
      vision.result.complete(VisionFrame.noFace());
      await tester.pump();
      await tester.pump();
      expect(session.disposals, 1);
      expect(camera.isStreaming, isFalse);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(creations, 1);
      expect(tester.takeException(), isNull);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets(
    'direct lifecycle callbacks are harmless after gameplay disposal',
    (tester) async {
      final sessions = <SessionFake>[];
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final session = SessionFake();
          sessions.add(session);
          return session;
        },
      );
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sessions.length, 1);
      expect(camera.isStreaming, isTrue);
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 1);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      await tester.pump();
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 1);
      expect(sessions.single.disposals, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(sessions.length, 1);
      expect(sessions.single.disposals, 1);
      expect(camera.isStreaming, isFalse);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets('failed tilt attempt retries once and rejects stale callbacks', (
    tester,
  ) async {
    final sensor = CapturingTiltSensor();
    final session = CountingSession();
    var now = DateTime.utc(2026);
    final container = ProviderContainer(
      overrides: [
        gameplayTiltSensorProvider.overrideWithValue(sensor),
        gameplayClockProvider.overrideWithValue(() => now),
        gameSessionProvider.overrideWith((ref) => session),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final oldAngle = sensor.callbacks.single;
    final oldError = sensor.errors.single;
    oldAngle(0);
    now = now.add(const Duration(milliseconds: 1100));
    oldAngle(0);
    await tester.pump();
    expect(find.text('Calibration unavailable'), findsOneWidget);
    expect(container.read(gameSessionProvider).state, GameSessionState.ready);
    expect(session.starts, 0);
    await tester.tap(find.text('Retry tilt'));
    await tester.pump();
    expect(sensor.callbacks.length, 2);
    final freshAngle = sensor.callbacks.last;
    for (var i = 0; i < 12; i++) {
      oldAngle(45);
      now = now.add(const Duration(milliseconds: 90));
    }
    oldError(StateError('late error'));
    await tester.pump();
    expect(find.text('Calibration unavailable'), findsNothing);
    expect(find.text('Controls ready! Starting in 3'), findsNothing);
    expect(session.starts, 0);
    for (var i = 0; i < 12; i++) {
      freshAngle(0);
      now = now.add(const Duration(milliseconds: 90));
    }
    freshAngle(0);
    for (var i = 0; i < 5; i++) {
      freshAngle(0);
    }
    await tester.pump();
    expect(find.text('Controls ready! Starting in 3'), findsOneWidget);
    expect(sensor.maxActive, 1);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    expect(session.starts, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(session.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
  });

  testWidgets('duplicate lifecycle resumes require fresh preparation', (
    tester,
  ) async {
    final sensor = CapturingTiltSensor();
    final session = CountingSession();
    var now = DateTime.utc(2026);
    final container = ProviderContainer(
      overrides: [
        gameplayTiltSensorProvider.overrideWithValue(sensor),
        gameplayClockProvider.overrideWithValue(() => now),
        gameSessionProvider.overrideWith((ref) => session),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final oldAngle = sensor.callbacks.single;
    oldAngle(0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(sensor.active, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sensor.callbacks.length, 1);
    oldAngle(0);
    expect(find.text('READY TO PLAY'), findsOneWidget);
    expect(session.starts, 0);
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sensor.callbacks.length, 2);
    for (var i = 0; i < 12; i++) {
      oldAngle(45);
      sensor.callbacks.last(0);
      now = now.add(const Duration(milliseconds: 90));
    }
    sensor.callbacks.last(0);
    await tester.pump();
    expect(find.text('Controls ready! Starting in 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(session.starts, 1);
    expect(sensor.maxActive, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sensor.active, isFalse);
    router.dispose();
    container.dispose();
  });

  testWidgets('interruption cancels preparation and requires a fresh start', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast(sync: true);
    var now = DateTime.utc(2026);
    final container = ProviderContainer(
      overrides: [
        gameplayTiltSensorProvider.overrideWithValue(
          TiltSensor(events: () => events.stream),
        ),
        gameplayClockProvider.overrideWithValue(() => now),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    events.add(AccelerometerEvent(0, 9.8, 0, now));
    expect(events.hasListener, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(events.hasListener, isFalse);
    expect(container.read(gameSessionProvider).state, GameSessionState.ready);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    now = now.add(const Duration(seconds: 3));
    events.add(AccelerometerEvent(0, 9.8, 0, now));
    await tester.pump(const Duration(seconds: 4));
    expect(container.read(gameSessionProvider).state, GameSessionState.ready);
    expect(find.text('READY TO PLAY'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await events.close();
    router.dispose();
    container.dispose();
  });

  testWidgets('smile samples are saved and used by active gameplay', (
    tester,
  ) async {
    var now = DateTime.now();
    var container = ProviderContainer(
      overrides: [
        gameplayClockProvider.overrideWithValue(() => now),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    var router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Calibrate smile'));
    await tester.pump();
    var notifier = container.read(mouthTrackingProvider.notifier);
    void observation(double probability) {
      now = now.add(const Duration(milliseconds: 100));
      final tracking = StableFaceTracking(
        status: FaceTrackingStatus.tracking,
        faceCount: 1,
        position: const Offset(.5, .5),
        faceSize: .4,
        mouthPosition: const Offset(.5, .5),
        mouthOpenness: 0,
        lastDetectedAt: now,
        updatedAt: now,
      );
      // The notifier is the existing camera-to-gameplay state boundary.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.state = notifier.state.copyWith(
        tracking: tracking,
        smileProbability: probability,
      );
    }

    for (var i = 0; i < 8; i++) {
      observation(.1);
      await tester.pump();
    }
    expect(find.text('Start smile sample'), findsOneWidget);
    await tester.tap(find.text('Start smile sample'));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      observation(.7);
      await tester.pump();
    }
    await tester.pump();
    expect(find.text('Smile calibration complete.'), findsOneWidget);
    final stored =
        (await SharedPreferences.getInstance()).getStringList(
          'smile_calibration_v1',
        )!;
    expect(double.parse(stored[0]), closeTo(.49, .001));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
    final restoredSession = CountingSession();
    var catchRequests = 0;
    container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith((ref) => restoredSession),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          catchRequests++;
          request();
        }),
        gameplayClockProvider.overrideWithValue(() => now),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    notifier = container.read(mouthTrackingProvider.notifier);
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Use touch controls'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    observation(.1);
    await tester.pump();
    restoredSession.putFoodAtMouth();
    observation(.55);
    await tester.pump();
    observation(.55);
    await tester.pump();
    observation(.55);
    await tester.pump();
    expect(catchRequests, 1);
    final game =
        tester
            .widget<GameWidget<MuskaanFlameGame>>(
              find.byType(GameWidget<MuskaanFlameGame>),
            )
            .game!;
    game.update(0);
    expect(container.read(gameSessionProvider).stats.catches, 1);
    restoredSession.putFoodAtMouth();
    for (var i = 0; i < 4; i++) {
      observation(.55);
      await tester.pump();
      game.update(0);
    }
    expect(catchRequests, 1);
    expect(container.read(gameSessionProvider).stats.catches, 1);
    observation(.1);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      observation(.55);
      await tester.pump();
    }
    expect(catchRequests, 2);
    game.update(0);
    expect(container.read(gameSessionProvider).stats.catches, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
  });

  testWidgets('stable sensor readings gate the countdown and round', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast(sync: true);
    var now = DateTime.utc(2026);
    final container = ProviderContainer(
      overrides: [
        gameplayTiltSensorProvider.overrideWithValue(
          TiltSensor(events: () => events.stream),
        ),
        gameplayClockProvider.overrideWithValue(() => now),
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(events.hasListener, isTrue);
    for (var i = 0; i < 12; i++) {
      events.add(AccelerometerEvent(0, 9.8, 0, now));
      now = now.add(const Duration(milliseconds: 90));
    }
    events.add(AccelerometerEvent(0, 9.8, 0, now));
    await tester.pump();
    expect(find.text('Controls ready! Starting in 3'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(milliseconds: 20));
      events.add(AccelerometerEvent(0, 9.8, 0, now));
    }
    await tester.pump();
    expect(find.text('Controls ready! Starting in 3'), findsOneWidget);
    expect(container.read(gameSessionProvider).state, GameSessionState.ready);
    expect(container.read(gameSessionProvider).activeFoods, isEmpty);
    final remaining = container.read(gameSessionProvider).stats.timeRemaining;
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(gameSessionProvider).state, GameSessionState.ready);
      expect(
        container.read(gameSessionProvider).stats.timeRemaining,
        remaining,
      );
      expect(container.read(gameSessionProvider).activeFoods, isEmpty);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(events.hasListener, isFalse);
    await events.close();
    router.dispose();
    container.dispose();
  });

  testWidgets(
    'insufficient samples allow retry and touch fallback cancels sensor',
    (tester) async {
      final events = StreamController<AccelerometerEvent>.broadcast(sync: true);
      var now = DateTime.utc(2026);
      final container = ProviderContainer(
        overrides: [
          gameplayTiltSensorProvider.overrideWithValue(
            TiltSensor(events: () => events.stream),
          ),
          gameplayClockProvider.overrideWithValue(() => now),
          cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      events.add(AccelerometerEvent(0, 9.8, 0, now));
      now = now.add(const Duration(milliseconds: 1100));
      events.add(AccelerometerEvent(0, 9.8, 0, now));
      await tester.pump();
      expect(find.text('Calibration unavailable'), findsOneWidget);
      expect(container.read(gameSessionProvider).state, GameSessionState.ready);
      await tester.tap(find.text('Retry tilt'));
      await tester.pump();
      expect(events.hasListener, isTrue);
      await tester.tap(find.text('Use touch controls'));
      await tester.pump();
      expect(events.hasListener, isFalse);
      events.add(AccelerometerEvent(9, 1, 0, now));
      expect(find.text('Controls ready! Starting in 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(events.hasListener, isFalse);
      expect(container.read(gameSessionProvider).state, GameSessionState.ready);
      expect(container.read(gameSessionProvider).activeFoods, isEmpty);
      await events.close();
      router.dispose();
      container.dispose();
    },
  );
}
