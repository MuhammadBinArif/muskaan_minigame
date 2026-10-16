import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/calibration/presentation/screens/calibration_screen.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_provider.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_service.dart';
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';

class DiagnosticFakeCameraService implements CameraService {
  DiagnosticFakeCameraService({
    CameraState initialState = const CameraState.idle(),
    this.autoStream = true,
    this.deliverFrame = false,
  }) : _state = initialState;

  final _states = StreamController<CameraState>.broadcast();
  CameraState _state;
  final bool autoStream;
  final bool deliverFrame;

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
    if (deliverFrame) await onFrame(DiagnosticCameraImage());
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

class DiagnosticVisionService implements VisionService {
  @override
  Future<VisionFrame> process(
    CameraImage image, {
    required int rotationDegrees,
  }) async => VisionFrame(
    observation: FaceTrackingObservation(
      faceDetected: true,
      faceCount: 1,
      facePosition: const Offset(.5, .45),
      faceSize: .35,
      mouthPosition: const Offset(.5, .58),
      mouthOpenness: .02,
      capturedAt: DateTime.now(),
    ),
  );

  @override
  Future<void> dispose() async {}
}

class DiagnosticCameraImage extends Fake implements CameraImage {}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    CameraState cameraState, {
    bool autoStream = true,
    bool deliverFrame = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(
            DiagnosticFakeCameraService(
              initialState: cameraState,
              autoStream: autoStream,
              deliverFrame: deliverFrame,
            ),
          ),
          visionServiceProvider.overrideWithValue(DiagnosticVisionService()),
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

  testWidgets('renders tracking-active state from a real observation path', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const CameraState(status: CameraStatus.ready),
      deliverFrame: true,
    );
    expect(find.text('✓ Tracking Active'), findsOneWidget);
    expect(find.text('Keep your mouth closed and hold still'), findsOneWidget);
  });
}
