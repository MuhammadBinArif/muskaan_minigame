import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:muskaan_minigame/core/domain/game_session.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1A2E);
  static const Color backgroundBottom = Color(0xFF0D0D1A);

  static const Color crimson = Color(0xFFDC143C);
  static const Color mutedGrey = Color(0xFF817995);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.crimson,
    letterSpacing: 3.0,
    height: 1.0,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
}

// ==========================================
// GAME OVER SCREEN
// ==========================================
class GameOverScreen extends StatefulWidget {
  final GameSessionRecord? gameRecord;
  final String? nextRoute;

  const GameOverScreen({super.key, this.gameRecord, this.nextRoute});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  late final AnimationController _pulse;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutBack));
    _entry.forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    final next = widget.nextRoute;
    if (next != null) {
      _navTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted || !context.mounted) return;
        // Direct call — the router schedules its own frame.
        // (Was: addPostFrameCallback, which hangs when no animation
        // schedules a frame — see calibration-screen bug.)
        context.go(next);
      });
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Opacity(
                      opacity: 0.80,
                      child: Text(
                        '😵',
                        style: TextStyle(fontSize: 60, height: 1.0),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTitle(),
                    const SizedBox(height: 14),
                    const Text(
                      'Tallying your score…',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: 16),
                    _buildDots(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final p = 0.5 + 0.5 * math.sin(_pulse.value * 2 * math.pi);
        return Text(
          'GAME OVER',
          style: AppTypography.title.copyWith(
            shadows: [
              Shadow(
                color: AppColors.crimson.withValues(alpha: 0.40 + 0.35 * p),
                blurRadius: 30 + 20 * p,
              ),
              Shadow(
                color: AppColors.crimson.withValues(alpha: 0.25 + 0.20 * p),
                blurRadius: 60 + 25 * p,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value * 2 * math.pi;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(3, (i) {
            final phase = -i * (2 * math.pi / 3);
            final intensity = 0.5 + 0.5 * math.sin(t + phase);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.crimson.withValues(
                    alpha: 0.35 + 0.55 * intensity,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
