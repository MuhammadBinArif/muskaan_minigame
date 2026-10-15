import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/camera_service_impl.dart';
import 'camera_service.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraServiceImpl();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
