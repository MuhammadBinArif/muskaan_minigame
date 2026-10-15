import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:permission_handler/permission_handler.dart';

import '../domain/camera_service.dart';
import '../domain/camera_state.dart';

class CameraServiceImpl implements CameraService {
  CameraController? _controller;
  CameraDescription? _frontCamera;

  StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();
  CameraState _state = const CameraState.idle();

  bool _isInitializing = false;

  /// Frame-processing lock. When non-null, the previous frame is still
  /// being handled and new frames are dropped.
  bool _processingFrame = false;

  /// Throttling: the last time we forwarded a frame to the consumer.
  DateTime _lastForwardedFrame = DateTime.fromMillisecondsSinceEpoch(0);

  StreamController<CameraState> get _activeStateController {
    if (_stateController.isClosed) {
      _stateController = StreamController<CameraState>.broadcast();
    }
    return _stateController;
  }

  @override
  Stream<CameraState> get stateStream => _activeStateController.stream;

  @override
  CameraState get state => _state;

  @override
  CameraController? get controller => _controller;

  @override
  int get sensorOrientation => _frontCamera?.sensorOrientation ?? 0;

  @override
  int get imageRotationDegrees {
    final camera = _frontCamera;
    final controller = _controller;
    if (camera == null || controller == null) return sensorOrientation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return camera.sensorOrientation;
    }

    const orientationDegrees = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation =
        orientationDegrees[controller.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      return (camera.sensorOrientation + deviceRotation) % 360;
    }
    return (camera.sensorOrientation - deviceRotation + 360) % 360;
  }

  @override
  bool get isStreaming => _controller?.value.isStreamingImages ?? false;

  void _emit(CameraState next) {
    _state = next;
    if (!_activeStateController.isClosed) {
      _activeStateController.add(next);
    }
  }

  // -----------------------------------------------------------------
  // Initialization
  // -----------------------------------------------------------------
  @override
  Future<void> initialize() async {
    if (_state.status == CameraStatus.ready ||
        _state.status == CameraStatus.streaming) {
      return; // idempotent
    }
    if (_isInitializing) {
      return; // prevent duplicate concurrent initializations
    }

    _isInitializing = true;
    try {
      _emit(_state.copyWith(status: CameraStatus.requestingPermission));

      // 1. Permission
      var permission = await Permission.camera.status;
      if (!permission.isGranted) {
        permission = await Permission.camera.request();
      }

      if (permission.isPermanentlyDenied) {
        _emit(
          _state.copyWith(
            status: CameraStatus.permissionPermanentlyDenied,
            errorMessage: 'Camera permission permanently denied.',
          ),
        );
        return;
      }

      if (!permission.isGranted) {
        _emit(
          _state.copyWith(
            status: CameraStatus.permissionDenied,
            errorMessage: 'Camera permission denied.',
          ),
        );
        return;
      }

      // 2. Discover front camera
      _emit(_state.copyWith(status: CameraStatus.discovering));
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          _emit(
            _state.copyWith(
              status: CameraStatus.failed,
              errorMessage: 'No cameras available on this device.',
            ),
          );
          return;
        }
        final frontCameras =
            cameras
                .where((c) => c.lensDirection == CameraLensDirection.front)
                .toList();
        if (frontCameras.isEmpty) {
          _emit(
            _state.copyWith(
              status: CameraStatus.noFrontCamera,
              errorMessage: 'No front-facing camera found on this device.',
            ),
          );
          return;
        }
        _frontCamera = frontCameras.first;
      } on CameraException catch (e) {
        _emit(
          _state.copyWith(
            status: CameraStatus.failed,
            errorMessage: 'Camera discovery failed: ${e.description}',
          ),
        );
        return;
      }

      // 3. Clean up any existing controller before creating new one
      if (_controller != null) {
        try {
          if (_controller!.value.isStreamingImages) {
            await _controller!.stopImageStream();
          }
        } catch (_) {}
        try {
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }

      // 4. Create and initialise controller
      _emit(_state.copyWith(status: CameraStatus.initialising));
      try {
        final controller = CameraController(
          _frontCamera!,
          ResolutionPreset.medium, // 480p is plenty for face landmarks
          enableAudio: false,
          imageFormatGroup:
              defaultTargetPlatform == TargetPlatform.android
                  ? ImageFormatGroup.nv21
                  : ImageFormatGroup.bgra8888,
        );
        await controller.initialize();
        _controller = controller;
        _emit(_state.copyWith(status: CameraStatus.ready));
      } on CameraException catch (e) {
        _emit(
          _state.copyWith(
            status: CameraStatus.failed,
            errorMessage: 'Camera initialisation failed: ${e.description}',
          ),
        );
      } catch (e) {
        _emit(
          _state.copyWith(
            status: CameraStatus.failed,
            errorMessage: 'Unexpected camera error: $e',
          ),
        );
      }
    } finally {
      _isInitializing = false;
    }
  }

  // -----------------------------------------------------------------
  // Streaming
  // -----------------------------------------------------------------
  @override
  Future<void> startStream({
    required FrameCallback onFrame,
    int maxFps = 15,
  }) async {
    if (maxFps <= 0) {
      throw ArgumentError.value(maxFps, 'maxFps', 'must be greater than zero');
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _emit(
        _state.copyWith(
          status: CameraStatus.failed,
          errorMessage: 'Cannot start stream: camera not initialised.',
        ),
      );
      return;
    }
    if (controller.value.isStreamingImages) return;

    final minFrameInterval = Duration(microseconds: (1000000 / maxFps).round());

    try {
      await controller.startImageStream((image) {
        // Backpressure: drop if the consumer is still processing.
        if (_processingFrame) return;

        // Throttle: drop frames that arrive too fast.
        final now = DateTime.now();
        if (now.difference(_lastForwardedFrame) < minFrameInterval) return;

        _processingFrame = true;
        _lastForwardedFrame = now;
        unawaited(_forwardFrame(image, onFrame));
      });
      _emit(_state.copyWith(status: CameraStatus.streaming));
    } on CameraException catch (e) {
      _processingFrame = false; // safety release
      _emit(
        _state.copyWith(
          status: CameraStatus.failed,
          errorMessage: 'Failed to start stream: ${e.description}',
        ),
      );
    }
  }

  Future<void> _forwardFrame(CameraImage image, FrameCallback onFrame) async {
    try {
      await onFrame(image);
    } catch (_) {
      // Frame-level errors belong to the vision controller. Keep the camera
      // stream alive so the UI can offer a retry without rebuilding hardware.
    } finally {
      _processingFrame = false;
    }
  }

  @override
  Future<void> stopStream() async {
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isStreamingImages) return;

    try {
      await controller.stopImageStream();
    } on CameraException catch (_) {
      // The stream may already be torn down. Swallow and move on.
    } finally {
      _processingFrame = false;
      if (_state.status != CameraStatus.disposing) {
        _emit(_state.copyWith(status: CameraStatus.ready));
      }
    }
  }

  // -----------------------------------------------------------------
  // Teardown
  // -----------------------------------------------------------------
  @override
  Future<void> dispose() async {
    _emit(_state.copyWith(status: CameraStatus.disposing));
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {
        /* best effort */
      }
      try {
        await controller.dispose();
      } catch (_) {
        /* best effort */
      }
    }
    _processingFrame = false;
    _isInitializing = false;
    _emit(const CameraState.idle());
    await _stateController.close();
  }

  @override
  Future<bool> shouldOpenSettings() async {
    return Permission.camera.isPermanentlyDenied;
  }
}
