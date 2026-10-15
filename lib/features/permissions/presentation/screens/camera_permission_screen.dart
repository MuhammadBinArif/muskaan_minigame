import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color headingCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color cardBg = Color(0xFF252542);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color successGreen = Color(0xFF3CB371);

  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.headingCream,
    letterSpacing: 0.3,
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
  static const TextStyle benefitText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
    height: 1.4,
  );
  static const TextStyle skipText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
}

// ==========================================
// CAMERA PERMISSION SCREEN
// ==========================================
class CameraPermissionScreen extends ConsumerStatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  ConsumerState<CameraPermissionScreen> createState() =>
      _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends ConsumerState<CameraPermissionScreen>
    with SingleTickerProviderStateMixin {
  /// Single controller drives all pulsing glow effects.
  /// Cards use phase offsets so they breathe out of sync.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // ---- Top icon with pulsing glow ----
                        _buildIcon(pulsePhase: 0),

                        const SizedBox(height: 28),

                        // ---- Headings ----
                        const Text(
                          'Camera Access',
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'We need your camera to track your mouth movements. '
                            'Your video stays on-device — never recorded or stored.',
                            style: AppTypography.body,
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ---- Benefit cards (each pulses out of phase) ----
                        _buildBenefitCard(
                          phaseIndex: 0,
                          emoji: '🔒',
                          text: 'Video processed locally — never uploaded',
                        ),
                        const SizedBox(height: 10),
                        _buildBenefitCard(
                          phaseIndex: 1,
                          emoji: '👁️',
                          text: 'No recording, no storage, no sharing',
                        ),
                        const SizedBox(height: 10),
                        _buildBenefitCard(
                          phaseIndex: 2,
                          emoji: '🛡️',
                          text: 'Full control — revoke anytime in Settings',
                        ),

                        const SizedBox(height: 48),

                        // ---- Actions ----
                        _buildContinueButton(context),
                        const SizedBox(height: 12),
                        _buildSkipButton(context),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top camera icon with pulsing glow + badge
  // ---------------------------------------------------------------------------
  Widget _buildIcon({required int pulsePhase}) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value * 2 * math.pi;
          final pulse = 0.5 + 0.5 * math.sin(t); // 0..1
          final glowBlur = 14.0 + 12.0 * pulse;
          final glowAlpha = 0.35 + 0.35 * pulse;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Ambient glow behind icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withValues(
                        alpha: glowAlpha * 0.6,
                      ),
                      blurRadius: glowBlur,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Main icon container with Figma-matching gradient
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentOrange.withValues(
                        alpha: 0.20 + 0.10 * pulse,
                      ),
                      AppColors.accentGold.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.accentOrange.withValues(
                      alpha: 0.40 + 0.20 * pulse,
                    ),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('📷', style: TextStyle(fontSize: 44)),
                ),
              ),
              // Green check badge
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundTop,
                      width: 2.5,
                    ),
                  ),
                  child: const Text(
                    '✓',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Benefit card — pulsing card-glow, staggered by phase index
  // ---------------------------------------------------------------------------
  Widget _buildBenefitCard({
    required int phaseIndex,
    required String emoji,
    required String text,
  }) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          // Stagger each card by 120° so they breathe out of sync.
          final phase = phaseIndex * (2 * math.pi / 3);
          final pulse =
              0.5 + 0.5 * math.sin(_pulse.value * 2 * math.pi + phase);
          final blur = 8.0 + 8.0 * pulse;
          final alpha = 0.10 + 0.18 * pulse;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.08 + 0.10 * pulse,
                ),
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
            // Emoji "icon" (matches Figma)
            SizedBox(
              width: 24,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: AppTypography.benefitText)),
            const SizedBox(width: 10),
            // Green check badge
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.successGreen,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '✓',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Continue CTA
  // ---------------------------------------------------------------------------
  Widget _buildContinueButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.btnGradientStart, AppColors.btnGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.btnGradientStart.withValues(alpha: 0.40),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            final camera = ref.read(cameraServiceProvider);
            await camera.initialize();
            if (!context.mounted) return;

            if (camera.state.status == CameraStatus.permissionDenied ||
                camera.state.status ==
                    CameraStatus.permissionPermanentlyDenied) {
              context.go('/camera-denied');
            } else {
              context.go('/calibration');
            }
          },
          child: const Center(
            child: Text('CONTINUE', style: AppTypography.buttonText),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Not now
  // ---------------------------------------------------------------------------
  Widget _buildSkipButton(BuildContext context) {
    return TextButton(
      onPressed: () => context.go('/camera-denied'),
      child: const Text('Not now', style: AppTypography.skipText),
    );
  }
}
