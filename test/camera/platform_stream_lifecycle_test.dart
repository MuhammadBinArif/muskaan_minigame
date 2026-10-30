import 'dart:async';

// The platform interface is supplied by the camera plugin.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/features/camera/data/camera_service_impl.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/gameplay_screen.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountingCameraPlatform extends CameraPlatform {
  int subscriptions = 0;
  int cancellations = 0;
  int active = 0;
  int maxActive = 0;
  int successfulCancellations = 0;
  int creations = 0;
  bool failStart = false;
  bool failCancel = false;
  bool platformReleaseConfirmed = false;
  Completer<void>? cancellationGate;
  final cancellationStarted = Completer<void>();
  int platformDisposals = 0;
  Completer<void>? initialization;
  final initializing = Completer<void>();
  late final StreamController<CameraImageData> frames = StreamController(
    onListen: () {
      subscriptions++;
      active++;
      if (active > maxActive) maxActive = active;
    },
    onCancel: () async {
      cancellations++;
      active--;
      if (!cancellationStarted.isCompleted) cancellationStarted.complete();
      await cancellationGate?.future;
      if (failCancel) throw PlatformException(code: 'cancel-failed');
      successfulCancellations++;
      platformReleaseConfirmed = true;
    },
  );

  @override
  bool supportsImageStreaming() => true;
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings? settings,
  ) async {
    creations++;
    return 13;
  }

  @override
  Future<void> initializeCamera(
    int? cameraId, {
    ImageFormatGroup? imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (!initializing.isCompleted) initializing.complete();
    await initialization?.future;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        const CameraInitializedEvent(
          13,
          75,
          75,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      Stream.value(CameraErrorEvent(cameraId, 'fake'));
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    if (failStart) throw PlatformException(code: 'stream-failed');
    return frames.stream;
  }

  @override
  Future<void> dispose(int? cameraId) async {
    platformDisposals++;
  }
}

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CameraPlatform previous;
  late CountingCameraPlatform platform;
  setUp(() {
    previous = CameraPlatform.instance;
    platform = CountingCameraPlatform();
    CameraPlatform.instance = platform;
  });
  tearDown(() {
    CameraPlatform.instance = previous;
    unawaited(platform.frames.close());
  });

  CameraServiceImpl service() => CameraServiceImpl(
    permissionStatus: () async => PermissionStatus.granted,
    discover: () async => [_front],
  );

  test(
    'real controller creates and cancels one platform stream subscription',
    () async {
      final camera = service();
      await camera.initialize();
      await camera.startStream(onFrame: (_) {});
      await camera.startStream(onFrame: (_) {});
      expect(platform.subscriptions, 1);
      expect(platform.active, 1);
      await camera.stopStream();
      await camera.stopStream();
      await camera.dispose();
      await camera.dispose();
      expect(platform.cancellations, 1);
      expect(platform.active, 0);
      await camera.close();
    },
  );

  test('stream startup failure creates no platform subscription', () async {
    final camera = service();
    await camera.initialize();
    platform.failStart = true;
    await camera.startStream(onFrame: (_) {});
    expect(camera.state.status, CameraStatus.failed);
    await camera.dispose();
    expect(platform.subscriptions, 0);
    expect(platform.cancellations, 0);
    await camera.close();
  });

  test(
    'disposal waits for platform stream cancellation after subscription',
    () async {
      final camera = service();
      await camera.initialize();
      await camera.startStream(onFrame: (_) {});
      platform.cancellationGate = Completer<void>();
      final disposing = camera.dispose();
      await platform.cancellationStarted.future;
      expect(platform.subscriptions, 1);
      expect(platform.cancellations, 1);
      expect(platform.successfulCancellations, 0);
      expect(platform.platformDisposals, 0);
      platform.cancellationGate!.complete();
      await disposing;
      expect(platform.successfulCancellations, 1);
      expect(platform.active, 0);
      expect(platform.platformDisposals, 1);
      await camera.close();
    },
  );

  test(
    'disposal during initialization creates no platform subscription',
    () async {
      final camera = service();
      platform.initialization = Completer<void>();
      final starting = camera.initialize();
      await platform.initializing.future;
      final disposing = camera.dispose();
      platform.initialization!.complete();
      await Future.wait([starting, disposing]);
      expect(platform.subscriptions, 0);
      expect(platform.cancellations, 0);
      expect(platform.active, 0);
      await camera.close();
    },
  );

  test(
    'failed platform cancellation is surfaced and cannot be retried by controller',
    () async {
      final camera = service();
      await camera.initialize();
      await camera.startStream(onFrame: (_) {});
      platform.failCancel = true;
      await expectLater(camera.stopStream(), throwsA(isA<CameraException>()));
      expect(camera.state.status, CameraStatus.failed);
      expect(platform.subscriptions, 1);
      expect(platform.cancellations, 1);
      expect(platform.platformReleaseConfirmed, isFalse);
      expect(camera.isStreaming, isFalse);
      await camera.dispose();
      await camera.dispose();
      expect(platform.cancellations, 1);
      expect(platform.platformDisposals, 1);
      expect(platform.platformReleaseConfirmed, isFalse);
      await camera.close();
    },
  );

  testWidgets(
    'gameplay callbacks cancel platform stream and pending restart cannot resubscribe',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final camera = service();
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
      expect(platform.subscriptions, 1);
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
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(platform.cancellations, 1);
      expect(platform.successfulCancellations, 1);
      expect(platform.active, 0);
      expect(platform.creations, 1);
      platform.initialization = Completer<void>();
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      expect(platform.creations, 2);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      screen.handleLifecycleEvent(AppLifecycleState.paused);
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      platform.initialization!.complete();
      await tester.pump();
      await tester.pump();
      screen.handleLifecycleEvent(AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.creations, 2);
      expect(platform.subscriptions, 1);
      expect(platform.cancellations, 1);
      expect(platform.successfulCancellations, 1);
      expect(platform.maxActive, 1);
      expect(platform.active, 0);
      expect(platform.platformDisposals, 2);
      expect(tester.takeException(), isNull);
      router.dispose();
      container.dispose();
      await camera.close();
    },
  );
}
