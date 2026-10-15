import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/calibration/presentation/screens/calibration_screen.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'camera/camera_sevice_imple_test.dart';
import 'session_regression_test.dart' show RetryRepository;

class FrameFake extends Fake implements CameraImage {}

class MeasuredVision implements VisionService {
  double openness = .02;
  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async => VisionFrame(
    rawOpenness: openness,
    mouthCenter: const Offset(.5, .5),
    confidence: 1,
    faceDetected: true,
    capturedAt: DateTime.now(),
  );
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'measured calibration completes only after closed-open-closed frames',
    (tester) async {
      final camera = FakeCameraService();
      final vision = MeasuredVision();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          visionServiceProvider.overrideWithValue(vision),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final router = createRouter(initialLocation: '/calibration');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CalibrationScreen), findsOneWidget);
      Future<void> frames(double value, int count) async {
        vision.openness = value;
        for (var i = 0; i < count; i++) {
          camera.simulateFrame(FrameFake());
          await tester.pump(const Duration(milliseconds: 70));
        }
      }

      await frames(.02, 15);
      expect(container.read(calibrationConfigProvider).calibrated, isFalse);
      await frames(.10, 8);
      expect(container.read(calibrationConfigProvider).calibrated, isFalse);
      await frames(.02, 8);
      expect(container.read(calibrationConfigProvider).calibrated, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CalibrationScreen), findsNothing);
      expect(find.text('Welcome to'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('game over reaches results and a failed save can be retried', (
    tester,
  ) async {
    final repository = RetryRepository();
    final container = ProviderContainer(
      overrides: [
        cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
        visionServiceProvider.overrideWith((ref) => NullVisionService()),
        gameRecordsRepositoryProvider.overrideWithValue(repository),
        bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
        calibrationConfigProvider.overrideWith(
          (ref) =>
              const CalibrationConfig(closedBaseline: .02, openThreshold: .08),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = createRouter(initialLocation: '/game');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('READY'));
    await tester.pump();
    final game = container.read(gameSessionProvider.notifier);
    for (var i = 0; i < 3; i++) {
      const tea = FoodItem(
        type: FoodItemType.tea,
        positionX: .5,
        positionY: .52,
        velocityX: 0,
        velocityY: .25,
        size: .08,
        creationTime: 0,
      );
      game.state = game.state.copyWith(activeFoods: [tea]);
      game.updateMouthTracking(isOpen: false, isActionable: true);
      game.updateMouthTracking(isOpen: true, isActionable: true);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final result = game.state.completedRecord!;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);
    expect(game.state.completedRecord!.id, result.id);
    repository.fail = false;
    await tester.tap(find.text('Retry save'));
    await tester.pump();
    await tester.pump();
    expect(game.state.saveError, isNull);
    expect(repository.records, hasLength(1));
    expect(repository.records.values.single.id, result.id);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
