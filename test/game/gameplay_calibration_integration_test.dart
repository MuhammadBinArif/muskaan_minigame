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
  int processCalls = 0;
  int completedCalls = 0;
  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    processCalls++;
    if (!started.isCompleted) started.complete();
    final frame = nextFrame == null ? await result.future : nextFrame!;
    completedCalls++;
    return frame;
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
  void putFoodAtMouth({double x = .5, FoodItemType type = FoodItemType.gold}) {
    state = state.copyWith(
      activeFoods: [
        FoodItem(
          type: type,
          positionX: x,
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

  testWidgets(
    'old smile session callbacks cannot affect touch or replacement smile generation',
    (tester) async {
      var now = DateTime.utc(2026);
      var requests = 0;
      final sessions = <SessionFake>[];
      final session = CountingSession();
      final vision = HoldingVision();
      final camera = CameraServiceImpl(
        clock: () => now,
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final candidate = SessionFake();
          sessions.add(candidate);
          return candidate;
        },
      );
      final container = ProviderContainer(
        overrides: [
          gameplayClockProvider.overrideWithValue(() => now),
          gameSessionProvider.overrideWith((ref) => session),
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
      final oldCallback = sessions.first.deliver!;
      oldCallback(ImageFake());
      await vision.started.future;
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      oldCallback(ImageFake());
      await tester.pump();
      expect(vision.processCalls, 1);
      expect(requests, 0);
      expect(sessions.first.disposals, 0);
      vision.result.complete(
        VisionFrame(
          observation: FaceTrackingObservation(
            faceDetected: true,
            faceCount: 1,
            facePosition: const Offset(.5, .5),
            faceSize: .4,
            mouthPosition: const Offset(.5, .5),
            mouthOpenness: .1,
            smileProbability: .9,
            capturedAt: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(vision.completedCalls, 1);
      expect(requests, 0);
      expect(container.read(gameSessionProvider).stats.score, 0);
      expect(sessions.first.disposals, 1);
      oldCallback(ImageFake());
      await tester.pump();
      expect(vision.processCalls, 1);
      expect(find.text('CATCH'), findsOneWidget);
      session.putFoodAtMouth();
      await tester.pump();
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      final game =
          tester
              .widget<GameWidget<MuskaanFlameGame>>(
                find.byType(GameWidget<MuskaanFlameGame>),
              )
              .game!;
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 100);
      expect(requests, 1);
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sessions.length, 2);
      final before = container.read(mouthTrackingProvider);
      oldCallback(ImageFake());
      await tester.pump();
      expect(vision.processCalls, 1);
      expect(identical(container.read(mouthTrackingProvider), before), isTrue);
      expect(requests, 1);
      Future<void> observe(double probability) async {
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
        final notifier = container.read(mouthTrackingProvider.notifier);
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        notifier.state = notifier.state.copyWith(
          tracking: tracking,
          smileProbability: probability,
        );
        await tester.pump();
      }

      session.putFoodAtMouth();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await observe(.8);
      }
      expect(requests, 1);
      await observe(.1);
      for (var i = 0; i < 3; i++) {
        await observe(.8);
      }
      game.update(0);
      expect(requests, 2);
      expect(container.read(gameSessionProvider).stats.score, 200);
      expect(session.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sessions.every((candidate) => candidate.disposals == 1), isTrue);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets('pause and resume while smile to touch cleanup is held', (
    tester,
  ) async {
    final sessions = <SessionFake>[];
    final vision = HoldingVision();
    final session = CountingSession();
    var now = DateTime.utc(2026);
    var requests = 0;
    final camera = CameraServiceImpl(
      permissionStatus: () async => PermissionStatus.granted,
      discover: () async => [front],
      createSession: (_) {
        final value = SessionFake();
        sessions.add(value);
        return value;
      },
    );
    final container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith((ref) => session),
        gameplayClockProvider.overrideWithValue(() => now),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          requests++;
          request();
        }),
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
    await tester.tap(find.text('READY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Use touch controls'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final remaining = container.read(gameSessionProvider).stats.timeRemaining;
    Future<void> observe(double p) async {
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
      final notifier = container.read(mouthTrackingProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.state = notifier.state.copyWith(
        tracking: tracking,
        smileProbability: p,
      );
      await tester.pump();
    }

    await observe(.1);
    for (var i = 0; i < 3; i++) {
      await observe(.8);
    }
    expect(requests, 1);
    sessions.first.deliver!(ImageFake());
    await vision.started.future;
    await tester.tap(find.text('Use touch-only'));
    await tester.pump();
    final dynamic screen = tester.state(find.byType(GameplayScreen));
    screen.handleLifecycleEvent(AppLifecycleState.paused);
    screen.handleLifecycleEvent(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.paused);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.paused);
    expect(sessions.length, 1);
    expect(sessions.first.disposals, 0);
    vision.result.complete(
      VisionFrame(
        observation: FaceTrackingObservation(
          faceDetected: true,
          faceCount: 1,
          facePosition: const Offset(.5, .5),
          faceSize: .4,
          mouthPosition: const Offset(.5, .5),
          mouthOpenness: .1,
          smileProbability: .9,
          capturedAt: now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(sessions.first.disposals, 1);
    expect(sessions.first.streamStops, 1);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    expect(find.text('CATCH'), findsOneWidget);
    expect(find.byTooltip('Move left'), findsOneWidget);
    expect(find.byTooltip('Move right'), findsOneWidget);
    expect(container.read(gameSessionProvider).stats.timeRemaining, remaining);
    session.putFoodAtMouth();
    await tester.pump();
    final game =
        tester
            .widget<GameWidget<MuskaanFlameGame>>(
              find.byType(GameWidget<MuskaanFlameGame>),
            )
            .game!;
    game.update(0);
    expect(container.read(gameSessionProvider).stats.score, 0);
    await tester.tap(find.text('CATCH'));
    await tester.pump();
    game.update(0);
    expect(container.read(gameSessionProvider).stats.score, 100);
    expect(requests, 2);
    expect(sessions.length, 1);
    expect(session.starts, 1);
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'touch catch is canceled before expiry while smile initialization is held',
    (tester) async {
      final gate = Completer<void>();
      final candidate = SessionFake()..initialization = gate;
      final session = CountingSession();
      var requests = 0;
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => candidate,
      );
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith((ref) => session),
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
            requests++;
            request();
          }),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game?control=touch');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      session.putFoodAtMouth(x: .05);
      await tester.pump();
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      expect(requests, 1);
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      expect(candidate.streamStarts, 0);
      await tester.pump(const Duration(milliseconds: 650));
      expect(requests, 1);
      expect(container.read(gameSessionProvider).stats.score, 0);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(candidate.streamStarts, 1);
      expect(find.text('Use touch-only'), findsOneWidget);
      session.putFoodAtMouth();
      await tester.pump();
      final game =
          tester
              .widget<GameWidget<MuskaanFlameGame>>(
                find.byType(GameWidget<MuskaanFlameGame>),
              )
              .game!;
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 0);
      expect(requests, 1);
      expect(session.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(candidate.streamStops, 1);
      expect(candidate.disposals, 1);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  for (final gameOver in [false, true]) {
    testWidgets(
      gameOver
          ? 'pending smile catch is cleared by game over during held cleanup'
          : 'pending smile catch is cleared by pause during held cleanup',
      (tester) async {
        var now = DateTime.utc(2026);
        var requests = 0;
        final sessions = <SessionFake>[];
        final vision = HoldingVision();
        final gameSession = CountingSession();
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
            gameplayClockProvider.overrideWithValue(() => now),
            gameSessionProvider.overrideWith((ref) => gameSession),
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
        final remaining =
            container.read(gameSessionProvider).stats.timeRemaining;
        Future<void> observation(double probability) async {
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
          final notifier = container.read(mouthTrackingProvider.notifier);
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          notifier.state = notifier.state.copyWith(
            tracking: tracking,
            smileProbability: probability,
          );
          await tester.pump();
        }

        await observation(.1);
        gameSession.putFoodAtMouth(x: .05);
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await observation(.8);
        }
        expect(requests, 1);
        expect(container.read(gameSessionProvider).stats.score, 0);
        sessions.first.deliver!(ImageFake());
        await vision.started.future;
        await tester.tap(find.text('Use touch-only'));
        await tester.pump();
        expect(sessions.first.disposals, 0);
        final game =
            tester
                .widget<GameWidget<MuskaanFlameGame>>(
                  find.byType(GameWidget<MuskaanFlameGame>),
                )
                .game!;
        for (final x in [.05, .5]) {
          gameSession.putFoodAtMouth(x: x);
          await tester.pump();
          game.update(0);
          expect(container.read(gameSessionProvider).stats.score, 0);
          expect(container.read(gameSessionProvider).stats.catches, 0);
        }
        final dynamic screen = tester.state(find.byType(GameplayScreen));
        if (gameOver) {
          for (var i = 0; i < 3; i++) {
            gameSession.putFoodAtMouth(type: FoodItemType.tea);
            gameSession.updateMouthTracking(isOpen: false, isActionable: true);
            gameSession.updateMouthTracking(
              isOpen: true,
              isActionable: true,
              mouthY: MuskaanFlameGame.targetY,
            );
          }
        } else {
          screen.handleLifecycleEvent(AppLifecycleState.paused);
        }
        await tester.pump();
        final terminalScore = container.read(gameSessionProvider).stats.score;
        vision.result.complete(
          VisionFrame(
            observation: FaceTrackingObservation(
              faceDetected: true,
              faceCount: 1,
              facePosition: const Offset(.5, .5),
              faceSize: .4,
              mouthPosition: const Offset(.5, .5),
              mouthOpenness: .1,
              smileProbability: .9,
              capturedAt: now,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(sessions.first.disposals, 1);
        expect(sessions.first.streamStops, 1);
        expect(requests, 1);
        expect(container.read(gameSessionProvider).stats.score, terminalScore);
        expect(gameSession.starts, 1);
        if (!gameOver) {
          expect(
            container.read(gameSessionProvider).state,
            GameSessionState.paused,
          );
          expect(
            container.read(gameSessionProvider).stats.timeRemaining,
            remaining,
          );
          await tester.tap(find.text('RESUME GAME'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            container.read(gameSessionProvider).state,
            GameSessionState.playing,
          );
          expect(container.read(gameSessionProvider).stats.score, 0);
          expect(requests, 1);
        } else {
          expect(
            container.read(gameSessionProvider).state,
            GameSessionState.gameOver,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
        router.dispose();
        container.dispose();
        await camera.close();
      },
    );
  }

  testWidgets('pending touch catch clears when pause interrupts smile startup', (
    tester,
  ) async {
    final gate = Completer<void>();
    final candidate = SessionFake()..initialization = gate;
    final replacement = SessionFake();
    final session = CountingSession();
    var creations = 0;
    var requests = 0;
    var now = DateTime.utc(2026);
    final camera = CameraServiceImpl(
      permissionStatus: () async => PermissionStatus.granted,
      discover: () async => [front],
      createSession: (_) {
        creations++;
        return creations == 1 ? candidate : replacement;
      },
    );
    final container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith((ref) => session),
        gameplayClockProvider.overrideWithValue(() => now),
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          requests++;
          request();
        }),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game?control=touch');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    session.putFoodAtMouth(x: .05);
    await tester.pump();
    final time = container.read(gameSessionProvider).stats.timeRemaining;
    await tester.tap(find.text('CATCH'));
    await tester.pump();
    expect(requests, 1);
    expect(container.read(gameSessionProvider).stats.score, 0);
    await tester.tap(find.text('Use smile (camera)'));
    await tester.pump();
    expect(creations, 1);
    final dynamic screen = tester.state(find.byType(GameplayScreen));
    screen.handleLifecycleEvent(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.paused);
    screen.handleLifecycleEvent(AppLifecycleState.resumed);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.paused);
    expect(creations, 1);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(candidate.disposals, 1);
    expect(candidate.streamStarts, 0);
    expect(candidate.active, isFalse);
    await tester.tap(find.text('RESUME GAME'));
    await tester.pump();
    expect(container.read(gameSessionProvider).state, GameSessionState.playing);
    expect(container.read(gameSessionProvider).stats.timeRemaining, time);
    expect(container.read(gameSessionProvider).stats.score, 0);
    await tester.tap(find.text('Use smile (camera)'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(creations, 2);
    expect(replacement.streamStarts, 1);
    Future<void> observe(double probability) async {
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
      final notifier = container.read(mouthTrackingProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.state = notifier.state.copyWith(
        tracking: tracking,
        smileProbability: probability,
      );
      await tester.pump();
    }

    session.putFoodAtMouth();
    await tester.pump();
    final game =
        tester
            .widget<GameWidget<MuskaanFlameGame>>(
              find.byType(GameWidget<MuskaanFlameGame>),
            )
            .game!;
    for (var i = 0; i < 3; i++) {
      await observe(.8);
    }
    game.update(0);
    expect(requests, 1);
    expect(container.read(gameSessionProvider).stats.score, 0);
    await observe(.1);
    for (var i = 0; i < 3; i++) {
      await observe(.8);
    }
    game.update(0);
    await tester.pump();
    expect(requests, 2);
    expect(container.read(gameSessionProvider).stats.score, 100);
    expect(session.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(replacement.disposals, 1);
    expect(tester.takeException(), isNull);
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'game over during smile to touch cleanup drains frame without restarting',
    (tester) async {
      final candidate = SessionFake();
      final vision = HoldingVision();
      final session = CountingSession();
      var requests = 0;
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => candidate,
      );
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith((ref) => session),
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
      candidate.deliver!(ImageFake());
      await vision.started.future;
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      expect(candidate.disposals, 0);
      for (var i = 0; i < 3; i++) {
        session.putFoodAtMouth(type: FoodItemType.tea);
        session.updateMouthTracking(isOpen: false, isActionable: true);
        session.updateMouthTracking(
          isOpen: true,
          isActionable: true,
          mouthY: MuskaanFlameGame.targetY,
        );
      }
      await tester.pump();
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.gameOver,
      );
      final score = container.read(gameSessionProvider).stats.score;
      vision.result.complete(
        VisionFrame(
          observation: FaceTrackingObservation(
            faceDetected: true,
            faceCount: 1,
            facePosition: const Offset(.5, .5),
            faceSize: .4,
            mouthPosition: const Offset(.5, .5),
            mouthOpenness: .1,
            smileProbability: .9,
            capturedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(candidate.disposals, 1);
      expect(candidate.streamStarts, 1);
      expect(candidate.streamStops, 1);
      expect(candidate.active, isFalse);
      expect(requests, 0);
      expect(session.starts, 1);
      expect(container.read(gameSessionProvider).stats.score, score);
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.gameOver,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets(
    'game over during held stream startup drains and releases session',
    (tester) async {
      final gate = Completer<void>();
      final candidate = SessionFake()..streamStartGate = gate;
      var creations = 0;
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          creations++;
          return candidate;
        },
      );
      final session = CountingSession();
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith((ref) => session),
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game?control=touch');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      await candidate.streamStartEntered.future;
      expect(candidate.streamStarts, 0);
      for (var i = 0; i < 3; i++) {
        session.putFoodAtMouth(type: FoodItemType.tea);
        session.updateMouthTracking(isOpen: false, isActionable: true);
        session.updateMouthTracking(
          isOpen: true,
          isActionable: true,
          mouthY: MuskaanFlameGame.targetY,
        );
      }
      await tester.pump();
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.gameOver,
      );
      final score = container.read(gameSessionProvider).stats.score;
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(candidate.streamStarts, 1);
      expect(candidate.streamStops, 1);
      expect(candidate.disposals, 1);
      expect(candidate.active, isFalse);
      expect(creations, 1);
      expect(session.starts, 1);
      expect(container.read(gameSessionProvider).stats.score, score);
      expect(find.text('Use touch-only'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets('game over during smile initialization rejects late candidate', (
    tester,
  ) async {
    final held = Completer<void>();
    final candidate = SessionFake()..initialization = held;
    var creations = 0;
    var catchRequests = 0;
    final camera = CameraServiceImpl(
      permissionStatus: () async => PermissionStatus.granted,
      discover: () async => [front],
      createSession: (_) {
        creations++;
        return candidate;
      },
    );
    final gameSession = CountingSession();
    final container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith((ref) => gameSession),
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          catchRequests++;
          request();
        }),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game?control=touch');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    gameSession.putFoodAtMouth(x: .05);
    await tester.pump();
    await tester.tap(find.text('CATCH'));
    await tester.pump();
    expect(catchRequests, 1);
    expect(container.read(gameSessionProvider).stats.score, 0);
    await tester.tap(find.text('Use smile (camera)'));
    await tester.pump();
    expect(creations, 1);
    for (var i = 0; i < 3; i++) {
      gameSession.putFoodAtMouth(type: FoodItemType.tea);
      gameSession.updateMouthTracking(isOpen: false, isActionable: true);
      gameSession.updateMouthTracking(
        isOpen: true,
        isActionable: true,
        mouthY: MuskaanFlameGame.targetY,
      );
    }
    await tester.pump();
    expect(
      container.read(gameSessionProvider).state,
      GameSessionState.gameOver,
    );
    held.complete();
    await tester.pump();
    await tester.pump();
    expect(candidate.disposals, 1);
    expect(candidate.streamStarts, 0);
    expect(camera.isStreaming, isFalse);
    expect(catchRequests, 1);
    expect(container.read(gameSessionProvider).stats.score, 0);
    expect(gameSession.starts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'disposing gameplay during smile initialization releases late candidate without streaming',
    (tester) async {
      final held = Completer<void>();
      final candidate = SessionFake()..initialization = held;
      var creations = 0;
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          creations++;
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
      final router = createRouter(initialLocation: '/game?control=touch');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      expect(creations, 1);
      expect(candidate.streamStarts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      held.complete();
      await tester.pump();
      await tester.pump();
      expect(candidate.disposals, 1);
      expect(candidate.streamStarts, 0);
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
    'three catches preserve one round across smile touch smile transitions',
    (tester) async {
      var now = DateTime.utc(2026);
      var requests = 0;
      final sessions = <SessionFake>[];
      final gameSession = CountingSession();
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
          gameplayClockProvider.overrideWithValue(() => now),
          gameSessionProvider.overrideWith((ref) => gameSession),
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
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
      final initialTime =
          container.read(gameSessionProvider).stats.timeRemaining;
      final initialDuration = gameSession.sessionDuration;
      final game =
          tester
              .widget<GameWidget<MuskaanFlameGame>>(
                find.byType(GameWidget<MuskaanFlameGame>),
              )
              .game!;
      Future<void> observation(double p) async {
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
        final notifier = container.read(mouthTrackingProvider.notifier);
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        notifier.state = notifier.state.copyWith(
          tracking: tracking,
          smileProbability: p,
        );
        await tester.pump();
      }

      await observation(.1);
      gameSession.putFoodAtMouth(x: .05);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await observation(.8);
      }
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 0);
      gameSession.putFoodAtMouth();
      await tester.pump();
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 100);
      await observation(.1);
      for (var i = 0; i < 3; i++) {
        await observation(.8);
      }
      expect(requests, 2);
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      await tester.pump();
      expect(container.read(gameSessionProvider).stats.score, 100);
      gameSession.putFoodAtMouth();
      await tester.pump();
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 100);
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 200);
      gameSession.putFoodAtMouth(x: .05);
      await tester.pump();
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      final pendingRequests = requests;
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(gameSessionProvider).stats.score, 200);
      expect(requests, pendingRequests);
      gameSession.putFoodAtMouth();
      await tester.pump();
      final before = requests;
      for (var i = 0; i < 3; i++) {
        await observation(.8);
      }
      game.update(0);
      expect(requests, before);
      expect(container.read(gameSessionProvider).stats.score, 200);
      await observation(.1);
      for (var i = 0; i < 3; i++) {
        await observation(.8);
      }
      game.update(0);
      expect(container.read(gameSessionProvider).stats.score, 300);
      expect(container.read(gameSessionProvider).stats.catches, 3);
      expect(
        container.read(gameSessionProvider).stats.timeRemaining,
        initialTime,
      );
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.playing,
      );
      expect(gameSession.starts, 1);
      expect(gameSession.sessionDuration, initialDuration);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sessions.length, 2);
      expect(
        sessions.every(
          (session) => session.disposals == 1 && session.streamStops == 1,
        ),
        isTrue,
      );
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  for (final failStream in [false, true]) {
    testWidgets(
      failStream
          ? 'stream-start failure retries smile without restarting round'
          : 'initialization failure retries smile without restarting round',
      (tester) async {
        final sessions = <SessionFake>[];
        final camera = CameraServiceImpl(
          permissionStatus: () async => PermissionStatus.granted,
          discover: () async => [front],
          createSession: (_) {
            final session = SessionFake();
            if (sessions.isEmpty) {
              session.fail = !failStream;
              session.failStart = failStream;
            }
            sessions.add(session);
            return session;
          },
        );
        final session = CountingSession();
        final container = ProviderContainer(
          overrides: [
            gameSessionProvider.overrideWith((ref) => session),
            cameraServiceProvider.overrideWithValue(camera),
            visionServiceProvider.overrideWith((ref) => NullVisionService()),
            bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        final router = createRouter(initialLocation: '/game?control=touch');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('READY'));
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        final before = container.read(gameSessionProvider);
        await tester.tap(find.text('Use smile (camera)'));
        await tester.pump();
        await tester.pump();
        expect(find.text('CATCH'), findsOneWidget);
        expect(sessions.length, 1);
        expect(sessions.first.streamStarts, 0);
        expect(sessions.first.disposals, 1);
        expect(
          container.read(gameSessionProvider).stats.score,
          before.stats.score,
        );
        expect(
          container.read(gameSessionProvider).stats.timeRemaining,
          before.stats.timeRemaining,
        );
        await tester.tap(find.text('Use smile (camera)'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(sessions.length, 2);
        expect(sessions.last.streamStarts, 1);
        expect(find.text('Use touch-only'), findsOneWidget);
        expect(session.starts, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(sessions.last.streamStops, 1);
        expect(sessions.last.disposals, 1);
        router.dispose();
        container.dispose();
        await camera.close();
      },
    );
  }

  testWidgets(
    'smile startup timeout keeps touch usable and drains late candidate before retry',
    (tester) async {
      final sessions = <SessionFake>[];
      final held = Completer<void>();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final session = SessionFake();
          if (sessions.isEmpty) session.initialization = held;
          sessions.add(session);
          return session;
        },
      );
      final container = ProviderContainer(
        overrides: [
          smileCameraStartupTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 200),
          ),
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game?control=touch');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      expect(sessions.length, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Camera timed out. Continue with touch and retry.'),
        findsOneWidget,
      );
      expect(find.text('CATCH'), findsOneWidget);
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      expect(sessions.length, 1);
      held.complete();
      await tester.pump();
      await tester.pump();
      expect(sessions.first.disposals, 1);
      expect(sessions.first.streamStarts, 0);
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sessions.length, 2);
      expect(sessions.last.streamStarts, 1);
      expect(find.text('Use touch-only'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sessions.last.disposals, 1);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets(
    'switch to touch waits for in-flight camera frame before release',
    (tester) async {
      final cameraSession = SessionFake();
      final vision = HoldingVision();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => cameraSession,
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
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Use touch controls'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      cameraSession.deliver!(ImageFake());
      await vision.started.future;
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      expect(find.text('Switching controls…'), findsOneWidget);
      final switchingButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Switching controls…'),
          matching: find.byType(TextButton),
        ),
      );
      expect(switchingButton.onPressed, isNull);
      expect(cameraSession.streamStarts, 1);
      expect(cameraSession.streamStops, 1);
      expect(cameraSession.disposals, 0);
      expect(find.text('CATCH'), findsNothing);
      vision.result.complete(VisionFrame.noFace());
      await tester.pump();
      await tester.pump();
      expect(cameraSession.disposals, 1);
      expect(cameraSession.streamStarts, 1);
      expect(cameraSession.streamStops, 1);
      expect(cameraSession.active, isFalse);
      expect(find.text('CATCH'), findsOneWidget);
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.playing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets('failed smile selection keeps touch round playable', (
    tester,
  ) async {
    var requests = 0;
    final camera = CameraServiceImpl(
      permissionStatus: () async => PermissionStatus.permanentlyDenied,
      discover: () async => [front],
    );
    final session = CountingSession();
    final container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith((ref) => session),
        cameraServiceProvider.overrideWithValue(camera),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
          requests++;
          request();
        }),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    final router = createRouter(initialLocation: '/game?control=touch');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final before = container.read(gameSessionProvider);
    await tester.tap(find.text('Use smile (camera)'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Camera unavailable. Continue with touch or retry Smile.'),
      findsOneWidget,
    );
    expect(find.text('CATCH'), findsOneWidget);
    expect(container.read(gameSessionProvider).stats.score, before.stats.score);
    expect(
      container.read(gameSessionProvider).stats.timeRemaining,
      before.stats.timeRemaining,
    );
    await tester.tap(find.text('CATCH'));
    await tester.pump();
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    container.dispose();
    await camera.close();
  });

  testWidgets(
    'switch controls releases camera and restores one stream without resetting round',
    (tester) async {
      final sessions = <SessionFake>[];
      final sensor = CapturingTiltSensor();
      final camera = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          final session = SessionFake();
          sessions.add(session);
          return session;
        },
      );
      final gameSession = CountingSession();
      final container = ProviderContainer(
        overrides: [
          gameplayTiltSensorProvider.overrideWithValue(sensor),
          gameSessionProvider.overrideWith((ref) => gameSession),
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
      gameSession.putFoodAtMouth(x: .05);
      await tester.pump();
      final before = container.read(gameSessionProvider);
      expect(sessions.length, 1);
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      await tester.pump();
      expect(sessions.first.disposals, 1);
      expect(sessions.first.active, isFalse);
      expect(find.text('CATCH'), findsOneWidget);
      expect(
        container.read(gameSessionProvider).stats.score,
        before.stats.score,
      );
      expect(
        container.read(gameSessionProvider).stats.timeRemaining,
        before.stats.timeRemaining,
      );
      expect(
        container.read(gameSessionProvider).activeFoods.length,
        before.activeFoods.length,
      );
      await tester.tap(find.text('Use smile (camera)'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sessions.length, 2);
      expect(sessions.last.active, isTrue);
      expect(find.text('Use touch-only'), findsOneWidget);
      expect(
        container.read(gameSessionProvider).stats.score,
        before.stats.score,
      );
      expect(
        container.read(gameSessionProvider).stats.timeRemaining,
        before.stats.timeRemaining,
      );
      expect(gameSession.starts, 1);
      await tester.tap(find.text('Use touch-only'));
      await tester.pump();
      await tester.pump();
      expect(find.text('CATCH'), findsOneWidget);
      expect(sessions.length, 2);
      expect(sessions.last.streamStops, 1);
      expect(sessions.last.disposals, 1);
      expect(sessions.where((session) => session.active), isEmpty);
      expect(gameSession.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sessions.last.disposals, 1);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );

  testWidgets(
    'touch-only round does not construct camera or vision and requests catches once',
    (tester) async {
      var cameraConstructions = 0;
      var visionConstructions = 0;
      var detectorConstructions = 0;
      var calibrationStores = 0;
      var requests = 0;
      final touchSession = CountingSession();
      final container = ProviderContainer(
        overrides: [
          gameSessionProvider.overrideWith((ref) => touchSession),
          cameraServiceProvider.overrideWith((ref) {
            cameraConstructions++;
            return FakeCameraService();
          }),
          visionServiceProvider.overrideWith((ref) {
            visionConstructions++;
            return NullVisionService();
          }),
          faceDetectorFactoryProvider.overrideWithValue(() {
            detectorConstructions++;
            return GameplayDetector();
          }),
          gameplaySmileCalibrationStoreProvider.overrideWith((ref) {
            calibrationStores++;
            throw StateError('Touch-only must not load smile calibration');
          }),
          gameplayCatchRequestHandlerProvider.overrideWithValue((request) {
            requests++;
            request();
          }),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      final router = createRouter(initialLocation: '/game?control=touch');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('READY'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.playing,
      );
      expect(cameraConstructions, 0);
      expect(visionConstructions, 0);
      expect(detectorConstructions, 0);
      expect(calibrationStores, 0);
      final score = container.read(gameSessionProvider).stats.score;
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      expect(requests, 1);
      expect(container.read(gameSessionProvider).stats.score, score);
      final game =
          tester
              .widget<GameWidget<MuskaanFlameGame>>(
                find.byType(GameWidget<MuskaanFlameGame>),
              )
              .game!;
      touchSession.putFoodAtMouth(x: .05);
      await tester.pump();
      game.update(0);
      expect(container.read(gameSessionProvider).stats.catches, 0);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      expect(requests, 2);
      touchSession.putFoodAtMouth();
      await tester.pump();
      game.update(0);
      expect(container.read(gameSessionProvider).stats.catches, 1);
      touchSession.putFoodAtMouth();
      await tester.pump();
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      game.update(0);
      expect(requests, 3);
      expect(container.read(gameSessionProvider).stats.catches, 2);
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      expect(requests, 4);
      final dynamic screen = tester.state(find.byType(GameplayScreen));
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      await tester.pump();
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.paused,
      );
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      expect(
        container.read(gameSessionProvider).state,
        GameSessionState.playing,
      );
      await tester.tap(find.text('CATCH'));
      await tester.pump();
      expect(requests, 5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(cameraConstructions, 0);
      expect(visionConstructions, 0);
      expect(detectorConstructions, 0);
      expect(calibrationStores, 0);
      router.dispose();
      container.dispose();
    },
  );

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
