import 'dart:math' as math;
import 'dart:ui';
import 'avatar_presentation.dart';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

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
  double? _movementX;
  bool _faceReady = false;
  FaceGameControlStatus? _reportedStatus;
  CollisionEvent? _feedbackEvent;
  int? _lastFeedbackTimestamp;
  double _feedbackAge = 0;
  final Map<bool, Picture> _foodPictures = {};

  Picture _foodPicture(bool pani) => _foodPictures.putIfAbsent(pani, () {
    final recorder = PictureRecorder();
    FoodPainter(
      pani: pani,
      showShadow: false,
    ).paint(Canvas(recorder), const Size.square(128));
    return recorder.endRecording();
  });

  @override
  void onRemove() {
    for (final picture in _foodPictures.values) {
      picture.dispose();
    }
    _foodPictures.clear();
    super.onRemove();
  }

  static const double targetY = 0.52;

  double get targetX {
    if (_movementX != null) {
      if (size.x <= 0) return _movementX!;
      final radius = math.min(58.0, size.x * 0.15);
      return (_movementX! * size.x).clamp(radius, size.x - radius) / size.x;
    }
    if (size.x <= 0) return control.currentX;
    final radius = math.min(58.0, size.x * 0.15);
    return control.worldX(worldWidth: size.x, targetRadius: radius) / size.x;
  }

  FaceGameControlStatus get controlStatus => control.status;
  bool get hasActiveFeedback => _feedbackEvent != null;

  void configureControl(FaceGameControlConfig config) {
    control.configure(config);
    _reportStatus();
  }

  void syncSession({
    required List<FoodItem> foods,
    required List<CollisionEvent> recentCollisions,
    required bool isPlaying,
  }) {
    _foods = List<FoodItem>.unmodifiable(foods);
    _isPlaying = isPlaying;
    if (recentCollisions.isNotEmpty) {
      final latest = recentCollisions.first;
      if (latest.timestamp != _lastFeedbackTimestamp) {
        _lastFeedbackTimestamp = latest.timestamp;
        _feedbackEvent = latest;
        _feedbackAge = 0;
      }
    }
  }

  void setMouthOpen(bool isOpen) => _isMouthOpen = isOpen;

  /// Supplies the selected movement mode without using face coordinates.
  void setMovementInput(double x, {required bool faceReady}) {
    if (x.isFinite) _movementX = x.clamp(.1, .9);
    _faceReady = faceReady;
  }

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
    _movementX = null;
    _faceReady = false;
    _feedbackEvent = null;
    _lastFeedbackTimestamp = null;
    _feedbackAge = 0;
    _reportStatus();
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void update(double dt) {
    super.update(dt);
    if (_feedbackEvent != null) {
      _feedbackAge += dt;
      if (_feedbackAge >= .65) _feedbackEvent = null;
    }
    avatar.update(dt);
    control.update(dt);
    _reportStatus();
    if (_isPlaying) {
      onControlFrame(
        _isMouthOpen,
        _movementX == null ? control.isActionable : _faceReady,
        targetX,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final food in _foods) {
      _drawFood(canvas, food);
    }
    _drawTarget(canvas);
    _drawFeedback(canvas);
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
    final rotation =
        food.positionY * 2.2 + (food.creationTime % 997) / 997 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    if (food.type == FoodItemType.tea) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
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
      canvas.restore();
      return;
    }
    // Fit the shell to the existing food radius; collision geometry stays in
    // the domain layer. Cache vector commands rather than rebuilding paths
    // and texture for every falling item on every frame.
    final scale = radius / (128 * .36 * 1.07);
    canvas.scale(scale);
    canvas.translate(-64, -128 * .53);
    canvas.drawPicture(_foodPicture(food.type == FoodItemType.teal));
    canvas.restore();
  }

  void _drawFeedback(Canvas canvas) {
    final event = _feedbackEvent;
    if (event == null || size.x <= 0 || size.y <= 0) return;
    final t = (_feedbackAge / .65).clamp(0.0, 1.0);
    final center = Offset(event.mouthX * size.x, event.mouthY * size.y);
    final color =
        event.isCatch
            ? (event.foodType == FoodItemType.gold
                ? const Color(0xFFFFD86B)
                : const Color(0xFF3DD68C))
            : const Color(0xFFFF6B83);
    final paint = Paint()..color = color.withValues(alpha: (1 - t) * .8);
    final radius = 24 + 54 * t;
    canvas.drawCircle(
      center,
      radius,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t) + 1,
    );
    if (event.isCatch) {
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final particle =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawCircle(
          particle,
          4 * (1 - t) + 1,
          paint..style = PaintingStyle.fill,
        );
      }
    } else {
      final cross = radius * .35;
      canvas.drawLine(
        center - Offset(cross, cross),
        center + Offset(cross, cross),
        paint..strokeWidth = 4,
      );
      canvas.drawLine(
        center + Offset(cross, -cross),
        center - Offset(cross, -cross),
        paint,
      );
    }
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
