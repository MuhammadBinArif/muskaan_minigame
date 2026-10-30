import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:muskaan_minigame/features/camera/data/camera_service_impl.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/data/vision_sevice_impl.dart';
import '../camera/camera_service_regression_test.dart' show SessionFake, front;

class CountingDetector extends Fake implements FaceDetector {
  int closes = 0;
  Completer<List<Face>>? pending;

  @override
  Future<List<Face>> processImage(InputImage inputImage) => pending!.future;

  @override
  Future<void> close() async {
    closes++;
  }
}

class ImageStub extends Fake implements CameraImage {
  @override
  int get width => 2;
  @override
  int get height => 2;
  @override
  ImageFormat get format => FormatStub();
  @override
  List<Plane> get planes => [PlaneStub()];
}

class FormatStub extends Fake implements ImageFormat {
  @override
  ImageFormatGroup get group => ImageFormatGroup.nv21;
}

class PlaneStub extends Fake implements Plane {
  @override
  int get bytesPerRow => 2;
  @override
  Uint8List get bytes => Uint8List(6);
}

void main() {
  test(
    'camera restart reuses provider-owned detector until provider disposal',
    () async {
      final detector = CountingDetector();
      var detectorCreations = 0;
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
          faceDetectorFactoryProvider.overrideWithValue(() {
            detectorCreations++;
            return detector;
          }),
        ],
      );
      final tracking = container.read(mouthTrackingProvider.notifier);
      await tracking.startTracking();
      expect(detectorCreations, 1);
      expect(camera.isStreaming, isTrue);
      await tracking.stopTracking();
      expect(detector.closes, 0);
      expect(sessions.first.disposals, 1);
      await tracking.startTracking();
      expect(camera.isStreaming, isTrue);
      expect(sessions.length, 2);
      expect(detectorCreations, 1);
      expect(detector.closes, 0);
      await tracking.stopTracking();
      expect(sessions.last.disposals, 1);
      expect(detector.closes, 0);
      container.dispose();
      await Future<void>.value();
      expect(detector.closes, 1);
      await camera.close();
      expect(detector.closes, 1);
    },
  );
  test(
    'disposal drains active detection and rejects its late result',
    () async {
      final detector = CountingDetector()..pending = Completer<List<Face>>();
      final service = VisionServiceImpl(detector: detector);
      final processing = service.process(ImageStub(), rotationDegrees: 0);
      final result = expectLater(processing, throwsStateError);
      final disposing = service.dispose();
      expect(detector.closes, 0);
      detector.pending!.complete([]);
      await result;
      await disposing;
      await service.dispose();
      expect(detector.closes, 1);
      await expectLater(
        service.process(ImageStub(), rotationDegrees: 0),
        throwsStateError,
      );
    },
  );
  test(
    'vision service closes its detector once across repeated disposal',
    () async {
      final detector = CountingDetector();
      final service = VisionServiceImpl(detector: detector);
      await Future.wait([service.dispose(), service.dispose()]);
      await service.dispose();
      expect(detector.closes, 1);
    },
  );
}
