import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF2A1A18);
  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color subtitleGrey = Color(0xFFC9C3D8);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 3.4,
    color: AppColors.titleCream,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.5,
    color: AppColors.subtitleGrey,
  );
}

// ==========================================
// SPLASH SCREEN
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ---- Entry animation (one-shot) ----
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // ---- Extended-duration navigation timer ----
  Timer? _navigationTimer;

  // ---- Continuous looping animations ----
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _dotController;

  /// How long the splash stays on screen before navigating away.
  /// Adjust this single value to taste:
  ///   2500 ms → snappy
  ///   3500 ms → balanced (default)
  ///   4500 ms → luxurious
  static const Duration _splashDuration = Duration(milliseconds: 3500);

  @override
  void initState() {
    super.initState();

    // ---------------------------------------------------------------
    // 1) Entry animation (fade + scale) — one-shot, ~1.5 s
    // ---------------------------------------------------------------
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );

    // ---------------------------------------------------------------
    // 2) Navigation timer — decoupled from the animation so the user
    //    sees the fully-loaded splash for a comfortable beat even on
    //    slow devices.
    // ---------------------------------------------------------------
    _navigationTimer = Timer(_splashDuration, () {
      if (!mounted) return;
      // Defer navigation to the next frame so the router isn't
      // mutated mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.go('/welcome');
        }
      });
    });

    // ---------------------------------------------------------------
    // 3) Continuous looping animations
    // ---------------------------------------------------------------
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Kick off entry
    _entryController.forward();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel(); // 👈 critical: no dangling timer
    _entryController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  /// Y offset for a floating element. Each element gets a different
  /// phase offset (based on [phaseIndex]) so they bob out of sync.
  double _floatOffset(int phaseIndex, {double amplitude = 8}) {
    final t = _floatController.value * 2 * math.pi;
    final phase = (2 * math.pi / 4) * phaseIndex;
    return math.sin(t + phase) * amplitude;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: Stack(
          children: [
            // ---- Radial orange glow overlay ----
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppColors.accentOrange.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),

            // ---- Floating emojis (bob up/down out of phase) ----
            Positioned(
              top: 40,
              left: 24,
              child: Opacity(
                opacity: 0.55,
                child: const GolgappaIcon(size: 40),
              ),
            ),
            _buildFloatingEmoji(
              '🫙',
              phaseIndex: 1,
              top: 80,
              right: 32,
              size: 26,
              opacity: 0.20,
            ),
            _buildFloatingEmoji(
              '🍵',
              phaseIndex: 2,
              bottom: 112,
              left: 40,
              size: 26,
              opacity: 0.25,
            ),
            _buildFloatingEmoji(
              '⭐',
              phaseIndex: 3,
              bottom: 64,
              right: 24,
              size: 32,
              opacity: 0.20,
            ),

            // ---- Center content ----
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogoWithGlow(),
                      const SizedBox(height: 24),
                      _buildTitle(),
                      const SizedBox(height: 8),
                      const Text(
                        'GOL GAPPA CHALLENGE',
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 40),
                      _buildPulsingDots(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  Widget _buildFloatingEmoji(
    String emoji, {
    required int phaseIndex,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatOffset(phaseIndex)),
            child: child,
          );
        },
        child: Opacity(
          opacity: opacity,
          child: Text(emoji, style: TextStyle(fontSize: size)),
        ),
      ),
    );
  }

  Widget _buildLogoWithGlow() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing radial glow behind the bubble
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) {
              final g = _glowController.value;
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentOrange.withValues(alpha: 0.45 + 0.25 * g),
                      AppColors.accentGold.withValues(alpha: 0.20 + 0.15 * g),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 0.85],
                  ),
                ),
              );
            },
          ),
          // Bubble emoji gently bobbing
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatOffset(0, amplitude: 6)),
                child: child,
              );
            },
            child: const GolgappaIcon(size: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final g = _glowController.value;
        return Text(
          'MUSKAAN PK',
          style: AppTypography.title.copyWith(
            shadows: [
              Shadow(
                color: AppColors.accentGold.withValues(alpha: 0.45 * g),
                blurRadius: 18,
              ),
              Shadow(
                color: AppColors.accentOrange.withValues(alpha: 0.35 * g),
                blurRadius: 30,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPulsingDots() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        final t = _dotController.value * 2 * math.pi;
        final dots = List.generate(3, (i) {
          // Stagger by 120° (2π/3) so it looks like a wave.
          final phase = -i * (2 * math.pi / 3);
          final intensity = 0.5 + 0.5 * math.sin(t + phase);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(
                alpha: 0.35 + 0.55 * intensity,
              ),
              shape: BoxShape.circle,
            ),
          );
        });
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: dots);
      },
    );
  }
}
