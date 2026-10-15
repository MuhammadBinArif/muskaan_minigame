import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

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
  static const Color stepBadge = Color(0xFFFF6B35);

  static const Color crimson = Color(0xFFDC143C);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);

  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
  static const Color outlineBtnBorder = Color(0xFFFF6B35);
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
  static const TextStyle outlineButtonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.outlineBtnBorder,
    letterSpacing: 0.8,
  );
  static const TextStyle stepText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
    height: 1.4,
  );
  static const TextStyle stepNumber = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.0,
  );
}

// ==========================================
// CAMERA DENIED SCREEN
// ==========================================
class CameraDeniedScreen extends StatefulWidget {
  const CameraDeniedScreen({super.key});

  @override
  State<CameraDeniedScreen> createState() => _CameraDeniedScreenState();
}

class _CameraDeniedScreenState extends State<CameraDeniedScreen>
    with TickerProviderStateMixin {
  /// Loops — drives the crimson pulse on the icon.
  late final AnimationController _pulse;

  /// One-shot — drives the staggered slide-in of the step cards.
  late final AnimationController _entry;

  static const List<String> _steps = <String>[
    'Open your device Settings',
    'Scroll to find Muskaan Minigame',
    'Tap Permissions → Camera',
    'Select "Allow" and return',
  ];

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _entry.dispose();
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

                        // ---- Top blocked icon ----
                        _buildBlockedIcon(),

                        const SizedBox(height: 28),

                        // ---- Headings ----
                        const Text(
                          'Camera Blocked',
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Camera access was denied. Follow these steps '
                            'to enable it.',
                            style: AppTypography.body,
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ---- Step cards (staggered slide-in) ----
                        for (int i = 0; i < _steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildStepCard(index: i, text: _steps[i]),
                          ),

                        const SizedBox(height: 40),

                        // ---- Actions ----
                        _buildOpenSettingsButton(),
                        const SizedBox(height: 14),
                        _buildTryAgainButton(context),
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
  // Blocked icon with pulsing crimson glow
  // ---------------------------------------------------------------------------
  Widget _buildBlockedIcon() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value * 2 * math.pi;
          final pulse = 0.5 + 0.5 * math.sin(t); // 0..1

          return Stack(
            alignment: Alignment.center,
            children: [
              // Ambient crimson glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.crimson.withValues(
                        alpha: 0.15 + 0.20 * pulse,
                      ),
                      blurRadius: 14 + 12 * pulse,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Main icon container
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(
                    alpha: 0.15 + 0.05 * pulse,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.crimson.withValues(
                      alpha: 0.40 + 0.20 * pulse,
                    ),
                    width: 2,
                  ),
                ),
                child: const Text(
                  '🚫',
                  style: TextStyle(fontSize: 48, height: 1.0),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step card — slide-in staggered by index
  // ---------------------------------------------------------------------------
  Widget _buildStepCard({required int index, required String text}) {
    // Stagger start time: card 0 begins at 0, card 3 begins at 45%.
    final double start = index * 0.15;
    final double end = (start + 0.55).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final raw = _entry.value;
        // Map raw progress → this card's local 0..1 progress
        final local = ((raw - start) / (end - start)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(local);

        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, (1 - curved) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Numbered badge
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.stepBadge,
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}', style: AppTypography.stepNumber),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTypography.stepText)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Primary CTA — OPEN SETTINGS
  // ---------------------------------------------------------------------------
  Widget _buildOpenSettingsButton() {
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
            await openAppSettings();
          },
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⚙️', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('OPEN SETTINGS', style: AppTypography.buttonText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secondary CTA — Try Again
  // ---------------------------------------------------------------------------
  Widget _buildTryAgainButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineBtnBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.go('/camera-permission'),
          child: const Center(
            child: Text('Try Again', style: AppTypography.outlineButtonText),
          ),
        ),
      ),
    );
  }
}
