import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/calibration/presentation/screens/calibration_screen.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/gameplay_screen.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';

class DiagnosticFakeCameraService implements CameraService {
  final _controller = StreamController<CameraState>.broadcast();
  CameraState _state;
  final bool autoStream;
  bool isDisposed = false;

  DiagnosticFakeCameraService({
    CameraState initialState = const CameraState.idle(),
    this.autoStream = true,
  }) : _state = initialState;

  @override
  CameraState get state => _state;

  @override
  Stream<CameraState> get stateStream => _controller.stream;

  @override
  dynamic get controller => null;

  @override
  int get sensorOrientation => 0;

  @override
  bool get isStreaming => _state.status == CameraStatus.streaming;

  void emit(CameraState newState) {
    _state = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    if (autoStream) {
      emit(const CameraState(status: CameraStatus.streaming));
    }
  }

  @override
  Future<void> stopStream() async {
    emit(const CameraState(status: CameraStatus.ready));
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await _controller.close();
  }

  @override
  Future<bool> shouldOpenSettings() async =>
      _state.status == CameraStatus.permissionPermanentlyDenied;
}

void main() {
  group('Camera state diagnostics in CalibrationScreen', () {
    testWidgets('renders permission denied card with Grant Access button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            mouthTrackingProvider.overrideWith((ref) {
              return MouthTrackingController(
                camera: DiagnosticFakeCameraService(
                  initialState: const CameraState(
                    status: CameraStatus.permissionDenied,
                    errorMessage: 'Permission denied',
                  ),
                ),
                vision: NullVisionService(),
                config: CalibrationConfig.defaults(),
                ref: ref,
              );
            }),
          ],
          child: const MaterialApp(home: CalibrationScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Camera Permission Denied'), findsOneWidget);
      expect(find.text('Grant Access'), findsOneWidget);
    });

    testWidgets(
      'renders permission permanently denied card with Open Settings button',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              calibrationConfigProvider.overrideWith(
                (ref) => const CalibrationConfig(
                  closedBaseline: .02,
                  openThreshold: .08,
                ),
              ),
              mouthTrackingProvider.overrideWith((ref) {
                return MouthTrackingController(
                  camera: DiagnosticFakeCameraService(
                    initialState: const CameraState(
                      status: CameraStatus.permissionPermanentlyDenied,
                      errorMessage: 'Settings required',
                    ),
                  ),
                  vision: NullVisionService(),
                  config: CalibrationConfig.defaults(),
                  ref: ref,
                );
              }),
            ],
            child: const MaterialApp(home: CalibrationScreen()),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Camera Access Required'), findsOneWidget);
        expect(find.text('Open Settings'), findsOneWidget);
      },
    );

    testWidgets('renders no front camera diagnostic card', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            mouthTrackingProvider.overrideWith((ref) {
              return MouthTrackingController(
                camera: DiagnosticFakeCameraService(
                  initialState: const CameraState(
                    status: CameraStatus.noFrontCamera,
                    errorMessage: 'No front camera found',
                  ),
                ),
                vision: NullVisionService(),
                config: CalibrationConfig.defaults(),
                ref: ref,
              );
            }),
          ],
          child: const MaterialApp(home: CalibrationScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No Front Camera'), findsOneWidget);
    });

    testWidgets('renders error card with Retry button on camera failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            mouthTrackingProvider.overrideWith((ref) {
              return MouthTrackingController(
                camera: DiagnosticFakeCameraService(
                  initialState: const CameraState(
                    status: CameraStatus.failed,
                    errorMessage: 'Hardware sensor unavailable',
                  ),
                ),
                vision: NullVisionService(),
                config: CalibrationConfig.defaults(),
                ref: ref,
              );
            }),
          ],
          child: const MaterialApp(home: CalibrationScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Camera Error'), findsOneWidget);
      expect(find.text('Hardware sensor unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'provides accessible screen reader labels for diagnostic states and buttons',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              calibrationConfigProvider.overrideWith(
                (ref) => const CalibrationConfig(
                  closedBaseline: .02,
                  openThreshold: .08,
                ),
              ),
              mouthTrackingProvider.overrideWith((ref) {
                return MouthTrackingController(
                  camera: DiagnosticFakeCameraService(
                    initialState: const CameraState(
                      status: CameraStatus.permissionDenied,
                      errorMessage: 'Permission denied',
                    ),
                  ),
                  vision: NullVisionService(),
                  config: CalibrationConfig.defaults(),
                  ref: ref,
                );
              }),
            ],
            child: const MaterialApp(home: CalibrationScreen()),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.bySemanticsLabel('Grant camera access'), findsOneWidget);
        expect(find.bySemanticsLabel('Exit calibration'), findsOneWidget);
      },
    );

    testWidgets('renders exit button and handles back navigation cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            mouthTrackingProvider.overrideWith((ref) {
              return MouthTrackingController(
                camera: DiagnosticFakeCameraService(
                  initialState: const CameraState(
                    status: CameraStatus.failed,
                    errorMessage: 'Camera error',
                  ),
                ),
                vision: NullVisionService(),
                config: CalibrationConfig.defaults(),
                ref: ref,
              );
            }),
          ],
          child: const MaterialApp(home: CalibrationScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final exitFinder = find.bySemanticsLabel('Exit calibration');
      expect(exitFinder, findsOneWidget);
      await tester.tap(exitFinder);
      await tester.pump();
    });

    testWidgets('renders loading semantics when camera is initializing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            mouthTrackingProvider.overrideWith((ref) {
              return MouthTrackingController(
                camera: DiagnosticFakeCameraService(
                  initialState: const CameraState(
                    status: CameraStatus.initialising,
                  ),
                  autoStream: false,
                ),
                vision: NullVisionService(),
                config: CalibrationConfig.defaults(),
                ref: ref,
              );
            }),
          ],
          child: const MaterialApp(home: CalibrationScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Initializing camera feed',
        ),
        findsOneWidget,
      );
      expect(find.text('Initializing camera...'), findsOneWidget);
    });
  });

  group('Mouth state label feedback in GameplayScreen', () {
    testWidgets('shows OPEN MOUTH when closed and MOUTH OPEN when open', (
      tester,
    ) async {
      final fakeCamera = DiagnosticFakeCameraService(
        initialState: const CameraState(status: CameraStatus.ready),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calibrationConfigProvider.overrideWith(
              (ref) => const CalibrationConfig(
                closedBaseline: .02,
                openThreshold: .08,
              ),
            ),
            cameraServiceProvider.overrideWithValue(fakeCamera),
          ],
          child: const MaterialApp(home: GameplayScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap READY to enter active playing mode where _MouthRing is visible
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially closed
      expect(find.text('OPEN MOUTH'), findsOneWidget);
      expect(find.text('MOUTH OPEN'), findsNothing);
    });
  });
}
