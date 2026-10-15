import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color cardBorder = Color(0xFF3D3D5C);
  static const Color cardBgTop = Color(0xFF1A2A1A);
  static const Color cardBgBottom = Color(0xFF0D1A0D);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color heartRed = Color(0xFFFF4D4D);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color skipGrey = Color(0xFF817995);

  static const Color dotActive = Color(0xFFFF6B35);
  static const Color dotInactive = Color(0xFF3D3D5C);

  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
    letterSpacing: 0.5,
    height: 1.2,
  );
  static const TextStyle body = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGrey,
    height: 1.6,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.8,
  );
  static const TextStyle skip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.skipGrey,
  );
  static const TextStyle scoreText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
}

// ==========================================
// WELCOME SCREEN
// ==========================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // Falls (sawtooth loop) — drives falling emojis + score pop
  late AnimationController _fallController;
  // Pulse (ping-pong loop) — drives card glow, dashed oval, mouth ring
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // 3s loop: one complete fall cycle
    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 2s bidirectional: glow in, glow out
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fallController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ---- Radial orange glow overlay (matches Figma) ----
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2), // ~40% from top
                      radius: 0.9,
                      colors: [
                        AppColors.accentOrange.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),

              // ---- Main content ----
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            _buildGamePreviewCard(),
                            const SizedBox(height: 28),
                            const Text(
                              'Catch. Smile. Win!',
                              style: AppTypography.heading,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Open your mouth to catch falling street food. '
                                'Build combos, avoid hot chai, and show off your biggest smile!',
                                style: AppTypography.body,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildPaginationDots(),
                            const SizedBox(height: 20),
                            _buildPrimaryButton(context),
                            const SizedBox(height: 10),
                            _buildSkipButton(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Game Preview Card (all animations)
  // ---------------------------------------------------------------------------
  Widget _buildGamePreviewCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_fallController, _pulseController]),
      builder: (context, _) {
        // 0 → 1 → 0 across pulse cycle
        final pulse = _pulseController.value;

        // Card border glow
        final glowAlpha = 0.25 + 0.45 * pulse;
        final glowBlur = 12.0 + 14.0 * pulse;

        return Container(
          width: 180, // matches w-40 in Figma (Tailwind w-40 = 10rem = 160px)
          height: 240, // h-60 = 15rem = 240px
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Card gradient background
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.cardBgTop, AppColors.cardBgBottom],
                      ),
                    ),
                  ),
                ),

                // ---- Dashed oval + mouth ring (center) ----
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dashed oval with pulsing glow
                        CustomPaint(
                          size: const Size(80, 112),
                          painter: DashedOvalPainter(
                            pulse: pulse,
                            glowAlpha: 0.3 + 0.4 * pulse,
                          ),
                        ),
                        // Mouth ring (bottom of oval, scales)
                        Positioned(
                          bottom: 12,
                          child: Transform.scale(
                            scale: 1.0 + 0.10 * pulse,
                            child: Container(
                              width: 32,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accentOrange,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentOrange.withValues(
                                      alpha: 0.5 * pulse,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- Falling 🫧 (phase 0) ----
                _fallingEmoji(
                  emoji: '🫧',
                  phaseOffset: 0.0,
                  leftFraction: 0.30,
                  fontSize: 20,
                  totalHeight: 240,
                ),
                // ---- Falling ⭐ (phase 0.5, right side) ----
                _fallingEmoji(
                  emoji: '⭐',
                  phaseOffset: 0.45,
                  leftFraction: 0.70,
                  fontSize: 18,
                  totalHeight: 240,
                ),

                // ---- Score "+100" pop ----
                _buildScorePop(),

                // ---- Card header: hearts + score ----
                _buildCardHeader(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallingEmoji({
    required String emoji,
    required double phaseOffset,
    required double leftFraction,
    required double fontSize,
    required double totalHeight,
  }) {
    // Sawtooth: t goes 0→1, emoji moves top→bottom, then wraps.
    final t = (_fallController.value + phaseOffset) % 1.0;
    // Start slightly above and end slightly below for a clean loop.
    final y = -30 + t * (totalHeight + 60);
    // Fade in during first 10%, fade out during last 20%
    final opacity = t < 0.1
        ? t / 0.1
        : t > 0.8
        ? (1 - t) / 0.2
        : 1.0;

    return Positioned(
      top: y,
      left: leftFraction * 180, // card width
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(emoji, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }

  Widget _buildScorePop() {
    // Score pop: rises in, holds, then rises out + fades.
    final t = _fallController.value;
    double offsetY;
    double opacity;
    if (t < 0.2) {
      // Rise in
      final p = t / 0.2;
      offsetY = 20 * (1 - p);
      opacity = p;
    } else if (t < 0.7) {
      // Hold
      offsetY = 0;
      opacity = 1;
    } else {
      // Fade out + drift up
      final p = (t - 0.7) / 0.3;
      offsetY = -25 * p;
      opacity = 1 - p;
    }

    return Positioned(
      top: 48,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: const Text(
            '+100',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.accentGold,
              shadows: [Shadow(color: AppColors.accentGold, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 3 hearts
          Row(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Text('❤️', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
          // Score
          const Text(
            '1,250',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pagination dots
  // ---------------------------------------------------------------------------
  Widget _buildPaginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.dotActive : AppColors.dotInactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [AppColors.btnGradientStart, AppColors.btnGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.btnGradientStart.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: () => context.push('/how-to-play/step1'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎯', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('SEE HOW IT WORKS', style: AppTypography.buttonText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return TextButton(
      onPressed: () => context.go('/home'),
      child: const Text('Skip intro', style: AppTypography.skip),
    );
  }
}

// ==========================================
// DASHED OVAL PAINTER (animated glow)
// ==========================================
class DashedOvalPainter extends CustomPainter {
  final double pulse;
  final double glowAlpha;

  DashedOvalPainter({required this.pulse, required this.glowAlpha});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()..addOval(rect);

    // 1) Glow stroke (blurred, alpha pulses)
    final glowPaint = Paint()
      ..color = AppColors.accentOrange.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // 2) Dashed stroke on top
    final dashPaint = Paint()
      ..color = AppColors.accentOrange.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final dashPath = _dashPath(path, dashLength: 6.0, gapLength: 4.0);
    canvas.drawPath(dashPath, dashPaint);
  }

  Path _dashPath(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        dest.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashLength + gapLength;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DashedOvalPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.glowAlpha != glowAlpha;
  }
}
