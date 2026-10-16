import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'camera/camera_sevice_imple_test.dart';
import 'session_regression_test.dart' show RetryRepository;

void main() {
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
