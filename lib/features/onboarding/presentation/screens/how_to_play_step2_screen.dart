import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

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
  static const Color cardBg = Color(0xFF252542);
  static const Color cardLabel = Color(0xFF817995);
  static const Color dotActive = Color(0xFFFF6B35);
  static const Color dotInactive = Color(0xFF3D3D5C);
  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color scoreCrimson = Color(0xFFDC143C);
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
// STEP 2 SCREEN
// ==========================================
class HowToPlayStep2Screen extends StatefulWidget {
  const HowToPlayStep2Screen({super.key});
  @override
  State<HowToPlayStep2Screen> createState() => _HowToPlayStep2ScreenState();
}

class _HowToPlayStep2ScreenState extends State<HowToPlayStep2Screen>
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
                _buildAppBar(context, 'STEP 2 OF 3'),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _buildIllustration(),
                        const SizedBox(height: 32),
                        const Text(
                          'Smile to Catch',
                          style: AppTypography.heading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tilt your phone to move. Smile when food reaches '
                          'the catch zone. Each item has different points!',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _buildScoreLegend(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                _buildPagination(1),
                const SizedBox(height: 16),
                _buildNextButton(context),
                const SizedBox(height: 24), // ← same
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
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
              Semantics(
                label: 'Face with open mouth',
                child: const ExcludeSemantics(
                  child: Text(
                    '😮',
                    key: Key('onboarding-open-mouth-emoji'),
                    style: TextStyle(fontSize: 92, height: 1),
                  ),
                ),
              ),
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

  Widget _buildScoreLegend() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final pulse = _glow.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            // card-glow effect
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.10 + 0.15 * pulse,
                ),
                blurRadius: 10 + 10 * pulse,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _ScoreItem(
                icon: GolgappaIcon(size: 28),
                value: '+100',
                label: 'Gol Gappa',
                negative: false,
              ),
              _ScoreItem(
                icon: GolgappaIcon(size: 28, pani: true),
                value: '+50',
                label: 'Pani Puri',
                negative: false,
              ),
              _ScoreItem(
                icon: Icon(
                  Icons.star_rounded,
                  color: AppColors.accentGold,
                  size: 28,
                ),
                value: '+150',
                label: 'Bonus',
                negative: false,
              ),
              _ScoreItem(
                icon: Icon(
                  Icons.local_cafe_rounded,
                  color: Colors.white70,
                  size: 26,
                ),
                value: '−1 ❤️',
                label: 'Hot Tea',
                negative: true,
              ),
            ],
          ),
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

  Widget _buildNextButton(BuildContext context) {
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
          onTap: () => context.push('/how-to-play/step3'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('NEXT', style: AppTypography.buttonText),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCORE ITEM
// ==========================================
class _ScoreItem extends StatelessWidget {
  final Widget icon;
  final String value;
  final String label;
  final bool negative;

  const _ScoreItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.negative,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: negative ? AppColors.scoreCrimson : AppColors.accentGold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.stepText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
