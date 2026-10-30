import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:muskaan_minigame/features/camera/data/camera_service_impl.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';

class ImageFake extends Fake implements CameraImage {}

class SessionFake implements CameraSession {
  Completer<void>? initialization;
  bool fail = false;
  bool disposed = false;
  bool ready = false;
  bool active = false;
  bool failStart = false;
  int disposals = 0;
  int streamStarts = 0;
  int streamStops = 0;
  void Function(CameraImage)? deliver;
  @override
  dynamic get previewController => null;
  @override
  bool get initialized => ready;
  @override
  bool get streaming => active;
  @override
  int get rotationDegrees => 90;
  @override
  Future<void> initialize() async {
    await initialization?.future;
    if (fail) throw StateError('sensor unavailable');
    ready = true;
  }

  @override
  Future<void> start(void Function(CameraImage) callback) async {
    if (failStart) throw StateError('stream unavailable');
    streamStarts++;
    active = true;
    deliver = callback;
  }

  @override
  Future<void> stop() async {
    streamStops++;
    active = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    disposed = true;
    ready = active = false;
  }
}

const front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

void main() {
  test(
    'dispose during restart releases candidate exactly once without starting it',
    () async {
      final first = SessionFake();
      final candidate = SessionFake()..initialization = Completer<void>();
      final created = Completer<void>();
      var creations = 0;
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          creations++;
          if (creations == 1) return first;
          created.complete();
          return candidate;
        },
      );
      addTearDown(service.close);
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      await service.dispose();
      expect(first.disposals, 1);
      final restart = service.initialize();
      await created.future;
      final dispose = service.dispose();
      candidate.initialization!.complete();
      await Future.wait([restart, dispose]);
      expect(candidate.disposals, 1);
      expect(candidate.active, isFalse);
      expect(service.isStreaming, isFalse);
      expect(service.state.status, CameraStatus.idle);
      await service.dispose();
      expect(candidate.disposals, 1);
    },
  );
  test(
    'permission denial followed by grant starts and releases one session',
    () async {
      var permission = PermissionStatus.denied;
      final session = SessionFake();
      var creations = 0;
      final service = CameraServiceImpl(
        permissionStatus: () async => permission,
        requestPermission: () async => permission,
        discover: () async => [front],
        createSession: (_) {
          creations++;
          return session;
        },
      );
      addTearDown(service.close);
      await service.initialize();
      expect(service.state.status, CameraStatus.permissionDenied);
      expect(creations, 0);
      permission = PermissionStatus.granted;
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      expect(service.isStreaming, isTrue);
      expect(creations, 1);
      await service.dispose();
      await service.dispose();
      expect(session.disposals, 1);
      expect(session.active, isFalse);
    },
  );

  test(
    'stream start failure can retry without creating another session',
    () async {
      final session = SessionFake()..failStart = true;
      var creations = 0;
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) {
          creations++;
          return session;
        },
      );
      addTearDown(service.close);
      await service.initialize();
      await service.startStream(onFrame: (_) {});
      expect(service.state.status, CameraStatus.failed);
      expect(service.isStreaming, isFalse);
      session.failStart = false;
      await service.startStream(onFrame: (_) {});
      expect(service.state.status, CameraStatus.streaming);
      expect(creations, 1);
      await service.dispose();
      expect(session.disposals, 1);
    },
  );
  test(
    'production service handles denial, permanent denial, and absent front camera',
    () async {
      var permission = PermissionStatus.denied;
      final service = CameraServiceImpl(
        permissionStatus: () async => permission,
        requestPermission: () async => permission,
        discover: () async => [],
      );
      addTearDown(service.close);
      await service.initialize();
      expect(service.state.status, CameraStatus.permissionDenied);
      permission = PermissionStatus.permanentlyDenied;
      await service.initialize();
      expect(service.state.status, CameraStatus.permissionPermanentlyDenied);
      expect(await service.shouldOpenSettings(), isTrue);
      permission = PermissionStatus.granted;
      await service.initialize();
      expect(service.state.status, CameraStatus.noFrontCamera);
    },
  );

  test(
    'failed initialization releases candidate and retry creates a fresh session',
    () async {
      final first = SessionFake()..fail = true;
      final next = SessionFake();
      var creations = 0;
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => creations++ == 0 ? first : next,
      );
      addTearDown(service.close);
      await service.initialize();
      expect(service.state.status, CameraStatus.failed);
      expect(service.state.errorMessage, isNot(contains('sensor unavailable')));
      expect(service.state.errorMessage, contains('Please try again'));
      expect(first.disposed, isTrue);
      await service.initialize();
      expect(service.state.status, CameraStatus.ready);
      await service.initialize();
      expect(creations, 2);
      await service.dispose();
      expect(next.disposed, isTrue);
    },
  );

  test(
    'leaving during initialization cancels publication and releases late controller',
    () async {
      final session = SessionFake()..initialization = Completer<void>();
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => session,
      );
      addTearDown(service.close);
      final starting = service.initialize();
      await Future<void>.delayed(Duration.zero);
      final leaving = service.dispose();
      session.initialization!.complete();
      await Future.wait([starting, leaving]);
      expect(session.disposed, isTrue);
      expect(service.state.status, CameraStatus.idle);
      expect(service.controller, isNull);
    },
  );

  test(
    'async frame backpressure drops overlapping frames and disposal drains work',
    () async {
      final session = SessionFake();
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => session,
      );
      addTearDown(service.close);
      await service.initialize();
      final frameDone = Completer<void>();
      var calls = 0;
      await service.startStream(
        maxFps: 1000000,
        onFrame: (_) async {
          calls++;
          await frameDone.future;
        },
      );
      session.deliver!(ImageFake());
      await Future<void>.delayed(const Duration(milliseconds: 1));
      session.deliver!(ImageFake());
      expect(calls, 1);
      final stopping = service.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(session.disposed, isFalse);
      frameDone.complete();
      await stopping;
      expect(session.disposed, isTrue);
    },
  );

  test(
    'failed frame processing releases the lock and reports an error',
    () async {
      final session = SessionFake();
      final service = CameraServiceImpl(
        permissionStatus: () async => PermissionStatus.granted,
        discover: () async => [front],
        createSession: (_) => session,
      );
      addTearDown(service.close);
      await service.initialize();
      var calls = 0;
      await service.startStream(
        maxFps: 1000000,
        onFrame: (_) async {
          calls++;
          if (calls == 1) throw StateError('bad frame');
        },
      );
      session.deliver!(ImageFake());
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(service.state.status, CameraStatus.failed);
      session.deliver!(ImageFake());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
    },
  );
}
