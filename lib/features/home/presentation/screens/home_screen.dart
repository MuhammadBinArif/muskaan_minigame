import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/shared/widgets/soap_bubble.dart';

import '../../../../shared/widgets/app_bottom_nav.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color cardBg = Color(0xFF252542);
  static const Color badgeBorder = Color(0xFF3D3D5C);

  // Hero card
  static const Color heroTop = Color(0xFF2D1A0E);
  static const Color heroMid = Color(0xFF3D2210);
  static const Color heroEnd = Color(0xFF1A1A2E);

  // Text
  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  // Accents
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentGreen = Color(0xFF3CB371);
}

class AppTypography {
  static const TextStyle greeting = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle userName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle badgeNumber = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
  static const TextStyle badgeLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle battleTag = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
    letterSpacing: 1.4,
  );
  static const TextStyle battleTimer = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle heroTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
    height: 1.2,
  );
  static const TextStyle heroSubtitle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
  );
  static const TextStyle progressLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle progressValue = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.accentOrange,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.6,
  );
  static const TextStyle tileTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle tileDesc = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle statValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle statLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
}

// ==========================================
// HOME SCREEN
// ==========================================
class HomeScreen extends ConsumerStatefulWidget {
  final int currentIndex;
  const HomeScreen({super.key, this.currentIndex = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  // 0 → 0.64, one-shot
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  // ping-pong, drives every card-glow pulse
  late final AnimationController _glowController;

  // loop, drives 🫧 float
  late final AnimationController _floatController;

  static const double _progressTarget = 32 / 50;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _progressTarget,
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _progressController.forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _glowController.dispose();
    _floatController.dispose();
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
        child: Column(
          children: [
            // ---- Header with orange top gradient ----
            _buildHeader(),

            // ---- Scrollable content ----
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 12),
                    _buildModeTiles(),
                    const SizedBox(height: 12),
                    _buildStats(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(currentIndex: widget.currentIndex),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accentOrange.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Good evening,', style: AppTypography.greeting),
                  SizedBox(height: 2),
                  Text('Arjun 👋', style: AppTypography.userName),
                ],
              ),

              // Streak badge
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/challenges'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.badgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('🔥', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 4),
                      Text('7 streak', style: AppTypography.badgeNumber),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO CARD (glow pulse + 🫧 float + gold radial)
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowController, _floatController]),
      builder: (context, _) {
        final g = _glowController.value;
        final dy = math.sin(_floatController.value * 2 * math.pi) * 5;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroTop, AppColors.heroMid, AppColors.heroEnd],
              stops: [0.0, 0.4, 1.0],
            ),
            border: Border.all(
              color: AppColors.accentOrange.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.10 + 0.15 * g,
                ),
                blurRadius: 8 + 8 * g,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Gold radial glow (top-right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentGold.withValues(alpha: 0.20),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: tag + timer + floating bubble
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: const Text(
                                        'DAILY BATTLE',
                                        style: AppTypography.battleTag,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      '5h 22m left',
                                      style: AppTypography.battleTimer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Street Food Rush',
                                  style: AppTypography.heroTitle,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Catch 50 gol gappas  ·  ⭐ 500 reward',
                                  style: AppTypography.heroSubtitle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Floating 🫧
                          Transform.translate(
                            offset: Offset(0, dy),
                            child: const SoapBubbles.square(size: 48),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Progress header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Progress', style: AppTypography.progressLabel),
                          Text('32 / 50', style: AppTypography.progressValue),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Animated progress bar
                      _buildProgressBar(),

                      const SizedBox(height: 12),

                      // PLAY NOW
                      _buildPlayNowButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, _) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [AppColors.accentOrange, AppColors.accentGold],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayNowButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [AppColors.accentOrange, AppColors.accentGold],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/mode-select'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('PLAY NOW', style: AppTypography.buttonText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODE TILES
  // ---------------------------------------------------------------------------
  Widget _buildModeTiles() {
    return Row(
      children: [
        Expanded(
          child: _buildModeTile(
            emoji: '😁',
            accent: AppColors.accentGold,
            title: 'Smile Spotlight',
            desc: 'Score your smile',
            onTap: () => context.go('/filmi-smile'),
            phaseIndex: 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildModeTile(
            emoji: '🏋️',
            accent: AppColors.accentGreen,
            title: 'Practice Mode',
            desc: 'Sharpen your skills',
            onTap: () => context.go('/mode-select'),
            phaseIndex: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildModeTile({
    required String emoji,
    required Color accent,
    required String title,
    required String desc,
    required VoidCallback onTap,
    required int phaseIndex,
  }) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        // Stagger each tile by 90° so they breathe out of sync.
        final phase = phaseIndex * (math.pi / 2);
        final pulse =
            0.5 + 0.5 * math.sin(_glowController.value * 2 * math.pi + phase);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.13)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08 + 0.12 * pulse),
                blurRadius: 8 + 8 * pulse,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                Text(title, style: AppTypography.tileTitle),
                const SizedBox(height: 2),
                Text(desc, style: AppTypography.tileDesc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATS
  // ---------------------------------------------------------------------------
  Widget _buildStats() {
    final bestAsync = ref.watch(bestRecordStreamProvider);
    final bestRecord = bestAsync.valueOrNull;

    final scoreStr =
        bestRecord != null ? _formatScore(bestRecord.score) : '12,480';
    final comboStr = bestRecord != null ? 'x${bestRecord.bestCombo}' : 'x8';
    final accuracyStr =
        bestRecord != null ? '${(bestRecord.accuracy * 100).toInt()}%' : '74%';

    return Row(
      children: [
        Expanded(
          child: _buildStat(
            emoji: '🏆',
            value: scoreStr,
            label: 'Best Score',
            phaseIndex: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStat(
            emoji: '⚡',
            value: comboStr,
            label: 'Best Combo',
            phaseIndex: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStat(
            emoji: '🎯',
            value: accuracyStr,
            label: 'Accuracy',
            phaseIndex: 2,
          ),
        ),
      ],
    );
  }

  String _formatScore(int score) {
    final s = score.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _buildStat({
    required String emoji,
    required String value,
    required String label,
    required int phaseIndex,
  }) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        // Wider stagger for a nicer wave across three cards.
        final phase = phaseIndex * (2 * math.pi / 3);
        final pulse =
            0.5 + 0.5 * math.sin(_glowController.value * 2 * math.pi + phase);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.06 + 0.10 * pulse,
                ),
                blurRadius: 6 + 6 * pulse,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.statValue),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.statLabel),
        ],
      ),
    );
  }
}
