import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/smile/domain/smile_measurement.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import '../tracking/mouth_tracking_controller_test.dart'
    show MockCameraService, MockVisionService, FakeCameraImage;

void main() {
  testWidgets(
    'ML boundary observations update probability, expire and clear on interruption',
    (tester) async {
      final camera = MockCameraService();
      final vision = MockVisionService();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWithValue(vision),
          smileCalibrationProvider.overrideWith(
            (ref) => const SmileCalibration(
              neutralProbability: .18,
              naturalSmileProbability: .83,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(mouthTrackingProvider.notifier);
      await controller.startTracking();
      await tester.pump();
      for (final probability in [.18, .47, .83]) {
        final now = DateTime.now();
        vision.nextFrame = VisionFrame(
          observation: FaceTrackingObservation(
            smileProbability: probability,
            faceDetected: true,
            faceCount: 1,
            facePosition: const Offset(.5, .5),
            faceSize: .3,
            mouthPosition: const Offset(.5, .6),
            mouthOpenness: .02,
            capturedAt: now,
          ),
        );
        await camera.callback!(FakeCameraImage());
        await tester.pump(const Duration(milliseconds: 10));
        expect(
          container.read(mouthTrackingProvider).smile!.rawProbability,
          probability,
        );
        expect(
          container
              .read(mouthTrackingProvider)
              .smile!
              .smoothedCalibratedIntensity,
          isNotNull,
        );
      }
      await tester.pump(const Duration(milliseconds: 501));
      expect(container.read(mouthTrackingProvider).smile, isNull);
      vision.nextFrame = VisionFrame.noFace();
      await camera.callback!(FakeCameraImage());
      expect(container.read(mouthTrackingProvider).smile, isNull);
      await controller.stopTracking();
      expect(container.read(mouthTrackingProvider).smile, isNull);
      expect(container.read(mouthTrackingProvider).isStreaming, isFalse);
    },
  );
}
