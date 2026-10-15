import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);
  static const Color backBtnBg = Color(0xFF252542);
  static const Color stepText = Color(0xFF817995);
  static const Color headingCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color dotActive = Color(0xFFFF6B35);
  static const Color dotInactive = Color(0xFF3D3D5C);
  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle stepIndicator = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.stepText,
    letterSpacing: 1.5,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.headingCream,
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
}

// ==========================================
// STEP 3 SCREEN
// ==========================================
class HowToPlayStep3Screen extends StatefulWidget {
  const HowToPlayStep3Screen({super.key});
  @override
  State<HowToPlayStep3Screen> createState() => _HowToPlayStep3ScreenState();
}

class _HowToPlayStep3ScreenState extends State<HowToPlayStep3Screen>
    with TickerProviderStateMixin {
  late final AnimationController _float;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    _glow.dispose();
    super.dispose();
  }

  double _floatOffset(int phase, {double amp = 6}) {
    final t = _float.value * 2 * math.pi;
    final p = (2 * math.pi / 3) * phase;
    return math.sin(t + p) * amp;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildAppBar(context, 'STEP 3 OF 3'),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _buildIllustration('⚡'),
                        const SizedBox(height: 32),
                        const Text(
                          'Build Combos, Avoid Hazards',
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Catch items back-to-back for combo multipliers. '
                          'Avoid hot tea — it costs a life!',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _buildComboRow(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                _buildPagination(2),
                const SizedBox(height: 16),
                _buildStartButton(context),
                const SizedBox(height: 24), // ← same
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(String emoji) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([_float, _glow]),
        builder: (context, _) {
          final pulse = _glow.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentOrange.withValues(
                        alpha: 0.15 + 0.08 * pulse,
                      ),
                      AppColors.accentOrange.withValues(alpha: 0.03),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 76)),
              Positioned(
                top: 34,
                right: 24,
                child: Transform.translate(
                  offset: Offset(0, _floatOffset(0, amp: 5)),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 22,
                child: Transform.translate(
                  offset: Offset(0, _floatOffset(1, amp: 4)),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
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

  Widget _buildComboRow() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final pulse = _glow.value;
        return Row(
          children: [
            Expanded(
              child: _ComboCard(multiplier: 'x2', index: 0, pulse: pulse),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ComboCard(multiplier: 'x3', index: 1, pulse: pulse),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ComboCard(multiplier: 'x4', index: 2, pulse: pulse),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, String stepText) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.backBtnBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                },
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          Text(stepText, style: AppTypography.stepIndicator),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildPagination(int active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == active;
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

  Widget _buildStartButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
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
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.go('/camera-permission'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📷', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text('START CAMERA SETUP', style: AppTypography.buttonText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// COMBO CARD (with card-glow pulse)
// ==========================================
class _ComboCard extends StatelessWidget {
  final String multiplier;
  final int index;
  final double pulse;

  const _ComboCard({
    required this.multiplier,
    required this.index,
    required this.pulse,
  });

  // Figma: hsl(20 + i*15, 100%, 55 + i*5%)
  //  i=0 → hsl(20, 100%, 55%) = #FF8C00
  //  i=1 → hsl(35, 100%, 60%) = #FFB200
  //  i=2 → hsl(50, 100%, 65%) = #FFD700
  Color get _numberColor {
    switch (index) {
      case 0:
        return const Color(0xFFFF8C00);
      case 1:
        return const Color(0xFFFFB200);
      default:
        return const Color(0xFFFFD700);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma: linear-gradient(135deg, rgba(255,107,53, 0.10 + i*0.08), rgba(255,215,0,0.04))
    final topAlpha = 0.10 + index * 0.08;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentOrange.withValues(alpha: topAlpha),
            AppColors.accentGold.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(
              alpha: 0.10 + 0.15 * pulse,
            ),
            blurRadius: 10 + 8 * pulse,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            multiplier,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _numberColor,
              shadows: [
                Shadow(
                  color: _numberColor.withValues(alpha: 0.6 * pulse),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Combo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.bodyGrey,
            ),
          ),
        ],
      ),
    );
  }
}
