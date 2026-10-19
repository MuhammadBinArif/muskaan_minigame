import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

import '../../../../shared/widgets/app_bottom_nav.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color cardBg = Color(0xFF252542);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color iconBg = Color(0x26FF6B35); // orange @ 15%
  static const Color iconBorder = Color(0x4DFF6B35); // orange @ 30%

  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
    height: 1.15,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGrey,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle cardDesc = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.6,
  );
}

// ==========================================
// HOME FIRST TIME SCREEN
// ==========================================
class HomeFirstTimeScreen extends StatefulWidget {
  const HomeFirstTimeScreen({super.key});

  @override
  State<HomeFirstTimeScreen> createState() => _HomeFirstTimeScreenState();
}

class _HomeFirstTimeScreenState extends State<HomeFirstTimeScreen>
    with TickerProviderStateMixin {
  // ── SHIMMER ── 1.4 s linear loop, drives a bright band sweeping the title
  late final AnimationController _shimmer;

  // ── FLOAT ── 2.4 s loop, bobs the golgappa illustration ±14 px
  late final AnimationController _float;

  // ── GLOW ── 1.6 s ping-pong, breathes the three feature cards' halos
  late final AnimationController _glow;

  static const List<_Feature> _features = <_Feature>[
    _Feature(
      emoji: '🎯',
      title: 'Face Tracking',
      desc: 'Open your mouth to catch food',
    ),
    _Feature(
      emoji: '⚡',
      title: 'Build Combos',
      desc: 'Chain catches for multipliers',
    ),
    _Feature(
      emoji: '😁',
      title: 'Smile Score',
      desc: 'Get rated on your biggest smile',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _float.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Header ----
                      const Text('Welcome to', style: AppTypography.title),
                      const SizedBox(height: 2),
                      _buildShimmerTitle(),
                      const SizedBox(height: 8),
                      const Text(
                        'Your street food adventure starts here.',
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 16),

                      // ---- Floating golgappa ----
                      _buildFloatingGolgappa(),

                      const SizedBox(height: 20),

                      // ---- Feature cards ----
                      for (int i = 0; i < _features.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildFeatureCard(_features[i], i),
                        ),

                      const SizedBox(height: 8),
                      _buildCta(context),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // SHIMMER TITLE
  //
  // Uses `Alignment` shifting (no custom GradientTransform) — this is the
  // most reliable way to slide a gradient in Flutter. The bright band is
  // narrow (stops 0.42 / 0.5 / 0.58) and pure white, so the sweep is
  // unmistakable against the cream base color.
  // ---------------------------------------------------------------------------
  Widget _buildShimmerTitle() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final v = _shimmer.value;
        // Gradient sweeps from left of text to right of text over 1 cycle.
        final begin = Alignment(-2.0 + 4.0 * v, 0);
        final end = Alignment(-1.0 + 4.0 * v, 0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: const [
                AppColors.titleCream,
                AppColors.titleCream,
                Color(0xFFFFF7E0), // near-white bright band
                AppColors.accentGold,
                AppColors.titleCream,
                AppColors.titleCream,
              ],
              stops: const [0.0, 0.38, 0.46, 0.54, 0.62, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: const Text('Muskaan Minigame! 🎉', style: AppTypography.title),
    );
  }

  // ---------------------------------------------------------------------------
  // FLOATING GOLGAPPA — shared with onboarding food artwork.
  // so the bob is clearly visible without being distracting.
  // ---------------------------------------------------------------------------
  Widget _buildFloatingGolgappa() {
    return SizedBox(
      height: 140,
      child: Center(
        child: AnimatedBuilder(
          animation: _float, // your existing controller
          builder: (context, child) {
            final dy = math.sin(_float.value * 2 * math.pi) * 14.0;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: const GolgappaIcon(size: 120),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FEATURE CARD — glow made obvious (alpha 0.18→0.48, blur 10→24)
  // ---------------------------------------------------------------------------
  Widget _buildFeatureCard(_Feature f, int index) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        // Stagger each card's pulse by 120° so they breathe out of phase.
        final phase = index * (2 * math.pi / 3);
        final pulse = 0.5 + 0.5 * math.sin(_glow.value * 2 * math.pi + phase);

        final blur = 10.0 + 14.0 * pulse;
        final alpha = 0.18 + 0.30 * pulse;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accentOrange.withValues(
                alpha: 0.15 + 0.25 * pulse,
              ),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(alpha: alpha),
                blurRadius: blur,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.iconBorder),
            ),
            child: Text(f.emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.title, style: AppTypography.cardTitle),
                const SizedBox(height: 2),
                Text(f.desc, style: AppTypography.cardDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA BUTTON
  // ---------------------------------------------------------------------------
  Widget _buildCta(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.btnGradientStart, AppColors.btnGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.btnGradientStart.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push('/mode-select'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎯', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Text('SEE HOW TO PLAY', style: AppTypography.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUPPORTING TYPES
// ==========================================

class _Feature {
  final String emoji;
  final String title;
  final String desc;
  const _Feature({
    required this.emoji,
    required this.title,
    required this.desc,
  });
}
