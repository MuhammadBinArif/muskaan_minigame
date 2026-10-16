import 'dart:math' as math;
import 'dart:ui';
import 'avatar_presentation.dart';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';

typedef ControlFrameCallback =
    void Function(bool isOpen, bool isActionable, double targetX);

/// Flame presentation boundary for the active round.
///
/// Camera and ML Kit objects never enter this class. It receives a small
/// normalized tracking contract and immutable domain snapshots only.
class MuskaanFlameGame extends FlameGame {
  MuskaanFlameGame({
    required FaceGameControlConfig controlConfig,
    required this.onControlFrame,
    required this.onControlStatusChanged,
  }) : control = FaceGameControl(config: controlConfig);

  final AvatarPresentation avatar = AvatarPresentation();
  final FaceGameControl control;
  final ControlFrameCallback onControlFrame;
  final ValueChanged<FaceGameControlStatus> onControlStatusChanged;

  List<FoodItem> _foods = const [];
  bool _isPlaying = false;
  bool _isMouthOpen = false;
  FaceGameControlStatus? _reportedStatus;

  static const double targetY = 0.52;

  double get targetX {
    if (size.x <= 0) return control.currentX;
    final radius = math.min(58.0, size.x * 0.15);
    return control.worldX(worldWidth: size.x, targetRadius: radius) / size.x;
  }

  FaceGameControlStatus get controlStatus => control.status;

  void configureControl(FaceGameControlConfig config) {
    control.configure(config);
    _reportStatus();
  }

  void syncSession({required List<FoodItem> foods, required bool isPlaying}) {
    _foods = List<FoodItem>.unmodifiable(foods);
    _isPlaying = isPlaying;
  }

  void setMouthOpen(bool isOpen) => _isMouthOpen = isOpen;

  void applyTracking(FaceGameControlSample sample, {DateTime? now}) {
    control.ingest(sample, now: now);
    _reportStatus();
  }

  void pauseControl() {
    control.pause();
    _reportStatus();
  }

  void resumeControl() {
    control.resume();
    _reportStatus();
  }

  void resetControl() {
    control.reset();
    avatar.reset();
    _isMouthOpen = false;
    _reportStatus();
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void update(double dt) {
    super.update(dt);
    avatar.update(dt);
    control.update(dt);
    _reportStatus();
    if (_isPlaying) {
      onControlFrame(_isMouthOpen, control.isActionable, targetX);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final food in _foods) {
      _drawFood(canvas, food);
    }
    _drawTarget(canvas);
  }

  void _reportStatus() {
    if (_reportedStatus == control.status) return;
    _reportedStatus = control.status;
    onControlStatusChanged(control.status);
  }

  void _drawFood(Canvas canvas, FoodItem food) {
    if (size.x <= 0 || size.y <= 0) return;
    final center = Offset(food.positionX * size.x, food.positionY * size.y);
    final radius = (food.size * size.x / 2).clamp(12.0, 24.0);
    if (food.type == FoodItemType.tea) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: radius * 1.7,
          height: radius * 1.35,
        ),
        Radius.circular(radius * 0.3),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFFC89060));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFF8A5A34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    final color =
        food.type == FoodItemType.gold
            ? const Color(0xFFFFD86B)
            : const Color(0xFF3FB39A);
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(-radius * 0.25, -radius * 0.3),
      radius * 0.28,
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  void _drawTarget(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    final radius = math.min(58.0, size.x * 0.15);
    final center = Offset(
      control.worldX(worldWidth: size.x, targetRadius: radius),
      targetY * size.y,
    );
    final active = control.isActionable;
    final ringColor =
        !active
            ? const Color(0xFF817995)
            : _isMouthOpen
            ? const Color(0xFF3DD68C)
            : const Color(0xFFFF7A1A);
    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()..color = ringColor.withValues(alpha: active ? 0.12 : 0.06),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = ringColor.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor.withValues(alpha: active ? 0.9 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 2,
    );
    avatar.render(canvas, center, radius);
  }
}
