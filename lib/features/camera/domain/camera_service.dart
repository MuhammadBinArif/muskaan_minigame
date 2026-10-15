// Abstract camera boundary.
//
// The rest of the app depends on this interface. Only the concrete
// implementation in `data/camera_service_impl.dart` knows about the
// `camera` package. This lets unit tests use a fake.

import 'package:camera/camera.dart' show CameraImage;
import 'camera_state.dart';

/// Callback invoked for each camera frame the pipeline decides to keep.
/// Called on a background isolate where the platform supports it.
typedef FrameCallback = void Function(CameraImage image);

abstract class CameraService {
  /// Emits lifecycle changes. Consumers watch this to know when
  /// frames are available or when the camera has failed.
  Stream<CameraState> get stateStream;

  /// Current state snapshot.
  CameraState get state;

  /// Underlying controller when initialized, for camera preview rendering.
  dynamic get controller;

  /// Sensor orientation in degrees of the active camera.
  int get sensorOrientation;

  /// Whether the service is currently streaming frames.
  bool get isStreaming;

  /// Asks for camera permission, discovers the front camera, and
  /// prepares the controller. Idempotent — safe to call multiple
  /// times from a screen's `initState`.
  Future<void> initialize();

  /// Starts streaming frames to [onFrame].
  ///
  /// Frames are throttled to `maxFps` (default 15 — sufficient for
  /// mouth tracking while keeping ML Kit inference off the critical
  /// path). Overlapping frames are dropped: if the previous frame
  /// hasn't finished processing, the new one is discarded.
  Future<void> startStream({required FrameCallback onFrame, int maxFps = 15});

  /// Stops streaming. The controller stays alive.
  Future<void> stopStream();

  /// Releases the controller and resets state to idle. Call from
  /// `dispose()` and from any code path that navigates away.
  Future<void> dispose();

  /// Whether the user has permanently denied permission and must
  /// visit Settings.
  Future<bool> shouldOpenSettings();
}
