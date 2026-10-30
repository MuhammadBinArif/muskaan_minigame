import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/profile/domain/profile_avatar.dart';
import 'package:muskaan_minigame/features/profile/presentation/screens/avatar_studio_screen.dart'
    show AvatarPainter;

enum AvatarReaction { idle, catchFood, combo, miss, gameOver }

/// Presentation-only clock and transition mapper. Counters are round-local
/// event identities, so timer ticks and save retries cannot replay reactions.
class AvatarPresentation {
  AvatarReaction reaction = AvatarReaction.idle;
  bool paused = false;
  bool reducedMotion = false;
  double age = 0;
  double idleAge = 0;
  int _catches = 0, _hazards = 0, _misses = 0;
  GameSessionState? _state;
  ui.Picture? _portrait;
  String? _symbol;
  bool _disposed = false;
  String get symbol => _symbol ?? ProfileAvatar.fallback.symbol;

  void sync(GameSessionStateData session) {
    if (_disposed) return;
    if (session.state == GameSessionState.ready) reset();
    paused = session.state == GameSessionState.paused;
    AvatarReaction? next;
    if (session.stats.catches > _catches) {
      next =
          session.stats.combo >= 3 && session.stats.combo % 3 == 0
              ? AvatarReaction.combo
              : AvatarReaction.catchFood;
    }
    if (session.stats.hazardsHit > _hazards || session.missCount > _misses) {
      next = AvatarReaction.miss;
    }
    if (session.state == GameSessionState.gameOver && _state != session.state) {
      next = AvatarReaction.gameOver;
    }
    _catches = session.stats.catches;
    _hazards = session.stats.hazardsHit;
    _misses = session.missCount;
    _state = session.state;
    if (next != null) {
      reaction = next;
      age = 0;
    }
  }

  void setAvatar(ProfileAvatar avatar) {
    if (_disposed) return;
    final symbol = ProfileAvatar.resolve(avatar).symbol;
    if (_symbol == symbol) return;
    _symbol = symbol;
    _portrait?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final index = ProfileAvatar.options.indexOf(symbol);
    AvatarPainter(
      hairStyle: index < 0 ? 0 : index,
    ).paint(canvas, const Size.square(100));
    _portrait = recorder.endRecording();
  }

  void update(double dt) {
    if (_disposed || paused || !dt.isFinite || dt <= 0) return;
    idleAge += dt;
    age += dt;
    if (age >= .6 && reaction != AvatarReaction.gameOver) {
      reaction = AvatarReaction.idle;
    }
  }

  double get scale {
    if (reducedMotion) return 1;
    final pulse = math.sin((age / .6).clamp(0.0, 1.0) * math.pi);
    return switch (reaction) {
      AvatarReaction.idle => 1 + .018 * math.sin(idleAge * 2),
      AvatarReaction.catchFood => 1 + .08 * pulse,
      AvatarReaction.combo => 1 + .13 * pulse,
      AvatarReaction.miss => 1 - .06 * pulse,
      AvatarReaction.gameOver => 1 - .08 * (age / .6).clamp(0.0, 1.0),
    };
  }

  Color get accent => switch (reaction) {
    AvatarReaction.catchFood => const Color(0xFF3DD68C),
    AvatarReaction.combo => const Color(0xFFFFD86B),
    AvatarReaction.miss => const Color(0xFFFF8FAD),
    _ => const Color(0xFFB994FF),
  };

  void render(Canvas canvas, Offset center, double radius) {
    if (_disposed) return;
    if (_portrait == null) setAvatar(ProfileAvatar.fallback);
    final portrait = _portrait!;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.drawCircle(
      Offset.zero,
      radius * .91,
      Paint()..color = const Color(0xFF302149),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 1.12,
      Paint()..color = accent.withValues(alpha: .10),
    );
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius * .86)),
    );
    final fit = radius * 1.72 / 100;
    canvas.scale(fit);
    canvas.translate(-50, -50);
    canvas.drawPicture(portrait);
    canvas.restore();
  }

  void reset() {
    reaction = AvatarReaction.idle;
    age = idleAge = 0;
    _catches = _hazards = _misses = 0;
    _state = null;
    paused = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _portrait?.dispose();
    _portrait = null;
  }
}
