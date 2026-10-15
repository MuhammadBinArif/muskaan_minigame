import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/calibration/presentation/screens/calibration_screen.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_provider.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_result.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_service.dart';

class DiagnosticFakeCameraService implements CameraService {
  DiagnosticFakeCameraService({
    CameraState initialState = const CameraState.idle(),
    this.autoStream = true,
  }) : _state = initialState;

  final _states = StreamController<CameraState>.broadcast();
  CameraState _state;
  final bool autoStream;

  @override
  CameraState get state => _state;
  @override
  Stream<CameraState> get stateStream => _states.stream;
  @override
  Object? get controller => null;
  @override
  int get sensorOrientation => 0;
  @override
  int get imageRotationDegrees => 0;
  @override
  bool get isStreaming => _state.status == CameraStatus.streaming;

  void emit(CameraState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    if (autoStream) emit(const CameraState(status: CameraStatus.streaming));
  }

  @override
  Future<void> stopStream() async {
    if (!_states.isClosed) emit(const CameraState(status: CameraStatus.ready));
  }

  @override
  Future<void> dispose() async => _states.close();

  @override
  Future<bool> shouldOpenSettings() async =>
      _state.status == CameraStatus.permissionPermanentlyDenied;
}

class DiagnosticFaceService implements FaceDetectionService {
  @override
  Future<FaceDetectionResult> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async => FaceDetectionResult.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    CameraState cameraState, {
    bool autoStream = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(
            DiagnosticFakeCameraService(
              initialState: cameraState,
              autoStream: autoStream,
            ),
          ),
          faceDetectionServiceProvider.overrideWithValue(
            DiagnosticFaceService(),
          ),
        ],
        child: const MaterialApp(home: CalibrationScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders permission denied with retry action', (tester) async {
    await pumpScreen(
      tester,
      const CameraState(
        status: CameraStatus.permissionDenied,
        errorMessage: 'Permission denied',
      ),
    );
    expect(find.text('Camera Permission Denied'), findsOneWidget);
    expect(find.text('Grant Access'), findsOneWidget);
  });

  testWidgets('renders permanently denied state with settings action', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const CameraState(
        status: CameraStatus.permissionPermanentlyDenied,
        errorMessage: 'Settings required',
      ),
    );
    expect(find.text('Camera Access Required'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('renders no-front-camera state', (tester) async {
    await pumpScreen(
      tester,
      const CameraState(
        status: CameraStatus.noFrontCamera,
        errorMessage: 'No front camera found',
      ),
    );
    expect(find.text('No Front Camera'), findsOneWidget);
  });

  testWidgets('renders camera error with retry action', (tester) async {
    await pumpScreen(
      tester,
      const CameraState(
        status: CameraStatus.failed,
        errorMessage: 'Hardware sensor unavailable',
      ),
    );
    expect(find.text('Camera Error'), findsOneWidget);
    expect(find.text('Hardware sensor unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders initialization state accessibly', (tester) async {
    await pumpScreen(
      tester,
      const CameraState(status: CameraStatus.initialising),
      autoStream: false,
    );
    expect(find.text('Initializing camera...'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Initializing camera feed',
      ),
      findsOneWidget,
    );
  });
}
