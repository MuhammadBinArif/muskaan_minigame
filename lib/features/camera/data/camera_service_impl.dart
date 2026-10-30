import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/camera_service.dart';
import '../domain/camera_state.dart';

/// Injectable platform boundary: tests exercise the production service itself.
abstract class CameraSession {
  dynamic get previewController;
  bool get initialized;
  bool get streaming;
  int get rotationDegrees;
  Future<void> initialize();
  Future<void> start(void Function(CameraImage) onFrame);
  Future<void> stop();
  Future<void> dispose();
}

class PluginCameraSession implements CameraSession {
  PluginCameraSession(CameraDescription description)
    : _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            defaultTargetPlatform == TargetPlatform.android
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );
  final CameraController _controller;
  @override
  CameraController get previewController => _controller;
  @override
  bool get initialized => _controller.value.isInitialized;
  @override
  bool get streaming => _controller.value.isStreamingImages;
  @override
  int get rotationDegrees {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return _controller.description.sensorOrientation;
    }
    final orientation = switch (_controller.value.deviceOrientation.name) {
      'landscapeLeft' => 90,
      'portraitDown' => 180,
      'landscapeRight' => 270,
      _ => 0,
    };
    final sensor = _controller.description.sensorOrientation;
    return _controller.description.lensDirection == CameraLensDirection.front
        ? (sensor + orientation) % 360
        : (sensor - orientation + 360) % 360;
  }

  @override
  Future<void> initialize() => _controller.initialize();
  @override
  Future<void> start(void Function(CameraImage) onFrame) =>
      _controller.startImageStream(onFrame);
  @override
  Future<void> stop() => _controller.stopImageStream();
  @override
  Future<void> dispose() => _controller.dispose();
}

class CameraServiceImpl implements CameraService {
  CameraServiceImpl({
    Future<PermissionStatus> Function()? permissionStatus,
    Future<PermissionStatus> Function()? requestPermission,
    Future<List<CameraDescription>> Function()? discover,
    CameraSession Function(CameraDescription)? createSession,
    DateTime Function()? clock,
  }) : _permissionStatus = permissionStatus ?? (() => Permission.camera.status),
       _requestPermission =
           requestPermission ?? (() => Permission.camera.request()),
       _discover = discover ?? availableCameras,
       _createSession = createSession ?? PluginCameraSession.new,
       _clock = clock ?? DateTime.now;

  final Future<PermissionStatus> Function() _permissionStatus;
  final Future<PermissionStatus> Function() _requestPermission;
  final Future<List<CameraDescription>> Function() _discover;
  final CameraSession Function(CameraDescription) _createSession;
  final DateTime Function() _clock;
  final _states = StreamController<CameraState>.broadcast();
  CameraState _state = const CameraState.idle();
  CameraSession? _session;
  Future<void> _operations = Future<void>.value();
  Future<void>? _frameJob;
  int _generation = 0;
  int _streamGeneration = 0;
  bool _acceptFrames = false;
  bool _closed = false;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Stream<CameraState> get stateStream => _states.stream;
  @override
  CameraState get state => _state;
  @override
  dynamic get controller => _session?.previewController;
  @override
  int get sensorOrientation => _session?.rotationDegrees ?? 0;
  @override
  int get imageRotationDegrees => _session?.rotationDegrees ?? 0;
  @override
  bool get isStreaming => _session?.streaming ?? false;

  void _emit(CameraState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  @override
  Future<void> initialize() {
    final generation = _generation;
    return _enqueue(() async {
      if (_closed || generation != _generation) return;
      if (_session?.initialized ?? false) return;
      CameraSession? candidate;
      bool cancelled() => _closed || generation != _generation;
      try {
        _emit(const CameraState(status: CameraStatus.requestingPermission));
        var permission = await _permissionStatus();
        if (cancelled()) return;
        if (!permission.isGranted && !permission.isPermanentlyDenied) {
          permission = await _requestPermission();
        }
        if (cancelled()) return;
        if (!permission.isGranted) {
          _emit(
            CameraState(
              status:
                  permission.isPermanentlyDenied
                      ? CameraStatus.permissionPermanentlyDenied
                      : CameraStatus.permissionDenied,
              errorMessage:
                  'Camera access is required to play. You can retry or open Settings.',
            ),
          );
          return;
        }
        _emit(const CameraState(status: CameraStatus.discovering));
        final cameras = await _discover();
        if (cancelled()) return;
        final front = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (front.isEmpty) {
          _emit(
            const CameraState(
              status: CameraStatus.noFrontCamera,
              errorMessage:
                  'No front-facing camera is available on this device.',
            ),
          );
          return;
        }
        await _releaseSession();
        if (cancelled()) return;
        _emit(const CameraState(status: CameraStatus.initialising));
        candidate = _createSession(front.first);
        await candidate.initialize();
        if (cancelled()) return;
        _session = candidate;
        candidate =
            null; // Ownership transfers only after successful initialization.
        _emit(const CameraState(status: CameraStatus.ready));
      } catch (error) {
        if (!cancelled()) {
          _emit(
            CameraState(
              status: CameraStatus.failed,
              errorMessage:
                  'Unable to initialize the camera. Please try again.',
            ),
          );
        }
      } finally {
        if (candidate != null) await candidate.dispose();
      }
    });
  }

  @override
  Future<void> startStream({required FrameCallback onFrame, int maxFps = 15}) {
    if (maxFps <= 0) {
      return Future<void>.error(ArgumentError.value(maxFps, 'maxFps'));
    }
    final generation = _generation;
    return _enqueue(() async {
      if (_closed || generation != _generation) return;
      final session = _session;
      if (session == null || !session.initialized) {
        _emit(
          const CameraState(
            status: CameraStatus.failed,
            errorMessage: 'Camera is not initialized. Please retry.',
          ),
        );
        return;
      }
      if (session.streaming) return;
      final streamGeneration = ++_streamGeneration;
      final minInterval = Duration(microseconds: (1000000 / maxFps).round());
      DateTime? lastFrame;
      _acceptFrames = true;
      try {
        await session.start((image) {
          if (!_acceptFrames ||
              streamGeneration != _streamGeneration ||
              _frameJob != null) {
            return;
          }
          final now = _clock();
          if (lastFrame != null && now.difference(lastFrame!) < minInterval) {
            return;
          }
          lastFrame = now;
          _frameJob = Future<void>.sync(() => onFrame(image))
              .catchError((Object error, StackTrace stack) {
                if (_acceptFrames && generation == _generation) {
                  _emit(
                    CameraState(
                      status: CameraStatus.failed,
                      errorMessage:
                          'Unable to process the camera frame. Please try again.',
                    ),
                  );
                }
              })
              .whenComplete(() {
                _frameJob = null;
              });
        });
        if (generation == _generation) {
          _emit(const CameraState(status: CameraStatus.streaming));
        }
      } catch (error) {
        _acceptFrames = false;
        _emit(
          CameraState(
            status: CameraStatus.failed,
            errorMessage:
                'Unable to start the camera stream. Please try again.',
          ),
        );
      }
    });
  }

  @override
  Future<void> stopStream() {
    _acceptFrames = false;
    ++_streamGeneration;
    return _enqueue(() async {
      try {
        if (_session?.streaming ?? false) await _session!.stop();
      } catch (_) {
        _emit(
          const CameraState(
            status: CameraStatus.failed,
            errorMessage: 'Unable to stop the camera stream. Please retry.',
          ),
        );
        rethrow;
      }
      await _frameJob;
      if (_session != null) {
        _emit(const CameraState(status: CameraStatus.ready));
      }
    });
  }

  Future<void> _releaseSession() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    try {
      if (session.streaming) await session.stop();
      await _frameJob;
    } finally {
      await session.dispose();
    }
  }

  /// Release is reusable: screen re-entry can initialize the same service again.
  @override
  Future<void> dispose() {
    ++_generation; // Cancel permission/discovery/initialization immediately.
    ++_streamGeneration;
    _acceptFrames = false;
    return _enqueue(() async {
      _emit(const CameraState(status: CameraStatus.disposing));
      try {
        await _releaseSession();
        _emit(const CameraState.idle());
      } catch (error) {
        _emit(
          CameraState(
            status: CameraStatus.failed,
            errorMessage:
                'Unable to release the camera. Please reopen the app.',
          ),
        );
      }
    });
  }

  Future<void> close() async {
    _closed = true;
    await dispose();
    await _states.close();
  }

  @override
  Future<bool> shouldOpenSettings() async =>
      (await _permissionStatus()).isPermanentlyDenied;
}
