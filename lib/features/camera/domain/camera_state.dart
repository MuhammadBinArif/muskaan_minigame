// Lifecycle state for the camera service.
// Consumers switch on this to decide what UI to show.

enum CameraStatus {
  /// Nothing initialised yet.
  idle,

  /// Permission request in flight.
  requestingPermission,

  /// Permission denied this session (can ask again).
  permissionDenied,

  /// Permission permanently denied (must go to Settings).
  permissionPermanentlyDenied,

  /// `availableCameras()` call in flight.
  discovering,

  /// Camera controller created, `initialize()` in flight.
  initialising,

  /// Ready to stream frames.
  ready,

  /// Actively streaming frames to the vision layer.
  streaming,

  /// No front camera detected on the device.
  noFrontCamera,

  /// Initialisation failed (device, driver, or hardware error).
  failed,

  /// Releasing resources.
  disposing,
}

class CameraState {
  final CameraStatus status;
  final String? errorMessage;

  const CameraState({required this.status, this.errorMessage});

  bool get isFailed => status == CameraStatus.failed;
  bool get isReadyOrStreaming =>
      status == CameraStatus.ready || status == CameraStatus.streaming;
  bool get hasPermissionError =>
      status == CameraStatus.permissionDenied ||
      status == CameraStatus.permissionPermanentlyDenied;

  const CameraState.idle() : status = CameraStatus.idle, errorMessage = null;

  CameraState copyWith({CameraStatus? status, String? errorMessage}) =>
      CameraState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
