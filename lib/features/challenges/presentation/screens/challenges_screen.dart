import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color cardBg = Color(0xFF252542);
  static const Color cardDivider = Color(0x663D3D5C);
  static const Color barTrack = Color(0xFF1A1A2E);

  // Featured card gradient
  static const Color featuredStart = Color(0xFF3D2210);
  static const Color featuredMid = Color(0xFF2D1A0E);
  static const Color featuredEnd = Color(0xFF1E1A2E);
  static const Color featuredBorder = Color(0x4DFF6B35); // orange @ 30%
  static const Color featuredTagBg = Color(0x26FF6B35); // orange @ 15%

  // Completed card (green tint)
  static const Color doneBg = Color(0x0D3CB371); // green @ 5%
  static const Color doneBorder = Color(0x4D3CB371); // green @ 30%
  static const Color doneIconBg = Color(0x333CB371); // green @ 20%
  static const Color doneIconBorder = Color(0x663CB371); // green @ 40%

  // Icon backgrounds
  static const Color iconBgOrange = Color(0x1AFF6B35); // orange @ 10%
  static const Color iconBorderOrange = Color(0x33FF6B35);
  static const Color iconBgFeatured = Color(0x33FF6B35);
  static const Color iconBorderFeatured = Color(0x66FF6B35);

  // Row highlight
  static const Color selfHighlight = Color(0x14FF6B35); // orange @ 8%

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentGreen = Color(0xFF3CB371);
}

class AppTypography {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle pageSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle featuredTag = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w800,
    color: AppColors.accentOrange,
    letterSpacing: 1.5,
  );
  static const TextStyle featuredTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle featuredDesc = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGrey,
  );
  static const TextStyle progressMeta = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle progressTime = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.accentOrange,
  );
  static const TextStyle reward = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle goalTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle goalTitleDone = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.accentGreen,
  );
  static const TextStyle goalReward = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
  static const TextStyle leaderName = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.titleCream,
  );
  static const TextStyle leaderNameSelf = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.accentOrange,
  );
  static const TextStyle leaderScore = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
}

// ==========================================
// CHALLENGES SCREEN
// ==========================================
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  /// One-shot: drives progress bar fills on mount.
  late final AnimationController _progressAnim;

  /// Ping-pong: drives card-glow halos.
  late final AnimationController _glow;

  // ---- Static data ----

  static const List<_DailyGoal> _dailyGoals = <_DailyGoal>[
    _DailyGoal(
      emoji: '🎯',
      title: 'Precision Player',
      desc: '',
      progress: 78,
      target: 80,
      unit: '%',
      reward: 200,
      done: false,
    ),
    _DailyGoal(
      emoji: '⚡',
      title: 'Combo King',
      desc: '',
      progress: 5,
      target: 6,
      unit: 'x',
      reward: 300,
      done: false,
    ),
    _DailyGoal(
      emoji: '😄',
      title: 'Smile Streak',
      desc: '',
      progress: 3,
      target: 3,
      reward: 150,
      done: true,
    ),
  ];

  static const List<_LeaderboardEntry> _leaderboard = <_LeaderboardEntry>[
    _LeaderboardEntry(medal: '🥇', name: 'Priya S.', score: '28,400'),
    _LeaderboardEntry(medal: '🥈', name: 'Rahul K.', score: '24,900'),
    _LeaderboardEntry(
      medal: '🥉',
      name: 'Arjun (You)',
      score: '12,480',
      isSelf: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim.forward();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressAnim.dispose();
    _glow.dispose();
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
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPageHeader(),
                const SizedBox(height: 14),
                _buildFeaturedCard(),
                const SizedBox(height: 14),
                const Text('Daily Goals', style: AppTypography.sectionTitle),
                const SizedBox(height: 10),
                for (int i = 0; i < _dailyGoals.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDailyGoalCard(_dailyGoals[i], i),
                  ),
                const SizedBox(height: 4),
                const Text('Leaderboard', style: AppTypography.sectionTitle),
                const SizedBox(height: 10),
                _buildLeaderboard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE HEADER
  // ---------------------------------------------------------------------------
  Widget _buildPageHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Challenges 🏆', style: AppTypography.pageTitle),
        SizedBox(height: 2),
        Text(
          'Complete goals to earn rewards',
          style: AppTypography.pageSubtitle,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FEATURED CARD
  // ---------------------------------------------------------------------------
  Widget _buildFeaturedCard() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final p = _glow.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/challenge-detail'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.featuredStart,
                  AppColors.featuredMid,
                  AppColors.featuredEnd,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              border: Border.all(color: AppColors.featuredBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentOrange.withValues(
                    alpha: 0.10 + 0.15 * p,
                  ),
                  blurRadius: 10 + 10 * p,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  // Gold radial glow (top-right)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IgnorePointer(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentGold.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(14), child: child),
                ],
              ),
            ),
          ),
        );
      },
      child: _buildFeaturedContent(),
    );
  }

  Widget _buildFeaturedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FEATURED TODAY tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.featuredTagBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('FEATURED TODAY', style: AppTypography.featuredTag),
        ),
        const SizedBox(height: 10),

        // Icon + title + desc + progress
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji icon
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconBgFeatured,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.iconBorderFeatured),
              ),
              child: const Text(
                '🌊',
                style: TextStyle(fontSize: 24, height: 1.0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gol Gappa Tsunami',
                    style: AppTypography.featuredTitle,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Catch 100 gol gappas without 3 misses',
                    style: AppTypography.featuredDesc,
                  ),
                  const SizedBox(height: 8),
                  _buildFeaturedProgress(),
                  const SizedBox(height: 8),
                  _buildRewardRow(750),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Text('68 / 100', style: AppTypography.progressMeta),
            Spacer(),
            Text('6h left', style: AppTypography.progressTime),
          ],
        ),
        const SizedBox(height: 5),
        _buildProgressBar(
          progressFraction: 0.68,
          height: 6,
          color: AppColors.accentOrange,
        ),
      ],
    );
  }

  Widget _buildRewardRow(int points) {
    return Row(
      children: [
        const Text('⭐', style: TextStyle(fontSize: 12, height: 1.0)),
        const SizedBox(width: 4),
        Text('$points pts', style: AppTypography.reward),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY GOAL CARD
  // ---------------------------------------------------------------------------
  Widget _buildDailyGoalCard(_DailyGoal goal, int index) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        // Stagger each card's glow by 120° so they breathe out of phase.
        final phase = index * (2 * math.pi / 3);
        final p = 0.5 + 0.5 * math.sin(_glow.value * 2 * math.pi + phase);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: goal.done ? AppColors.doneBg : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: goal.done
                ? Border.all(color: AppColors.doneBorder, width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: goal.done
                    ? AppColors.accentGreen.withValues(alpha: 0.08 + 0.10 * p)
                    : AppColors.accentOrange.withValues(alpha: 0.06 + 0.10 * p),
                blurRadius: 6 + 6 * p,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: _buildGoalContent(goal),
    );
  }

  Widget _buildGoalContent(_DailyGoal goal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: goal.done ? AppColors.doneIconBg : AppColors.iconBgOrange,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: goal.done
                  ? AppColors.doneIconBorder
                  : AppColors.iconBorderOrange,
            ),
          ),
          child: Text(
            goal.done ? '✅' : goal.emoji,
            style: const TextStyle(fontSize: 14, height: 1.0),
          ),
        ),
        const SizedBox(width: 12),

        // Title + progress bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: goal.done
                          ? AppTypography.goalTitleDone
                          : AppTypography.goalTitle,
                    ),
                  ),
                  Text('+${goal.reward}', style: AppTypography.goalReward),
                ],
              ),
              if (!goal.done) ...[
                const SizedBox(height: 6),
                _buildProgressBar(
                  progressFraction: goal.progress / goal.target,
                  height: 4,
                  color: AppColors.accentOrange,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEADERBOARD
  // ---------------------------------------------------------------------------
  Widget _buildLeaderboard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (int i = 0; i < _leaderboard.length; i++)
              _buildLeaderRow(
                _leaderboard[i],
                isLast: i == _leaderboard.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderRow(_LeaderboardEntry entry, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isSelf ? AppColors.selfHighlight : Colors.transparent,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.cardDivider, width: 1),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              entry.medal,
              style: const TextStyle(fontSize: 16, height: 1.0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.name,
              style: entry.isSelf
                  ? AppTypography.leaderNameSelf
                  : AppTypography.leaderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(entry.score, style: AppTypography.leaderScore),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED PROGRESS BAR
  // ---------------------------------------------------------------------------
  Widget _buildProgressBar({
    required double progressFraction,
    required double height,
    required Color color,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.barTrack,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, _) {
          // Eased animation * target fraction.
          final t = Curves.easeOutCubic.transform(_progressAnim.value);
          final widthFactor = (progressFraction * t).clamp(0.0, 1.0);
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
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
}

// ==========================================
// MODELS
// ==========================================
class _DailyGoal {
  final String emoji;
  final String title;
  final String desc;
  final int progress;
  final int target;
  final String unit;
  final int reward;
  final bool done;
  // final String? timeLeft;

  const _DailyGoal({
    required this.emoji,
    required this.title,
    this.desc = '',
    required this.progress,
    required this.target,
    this.unit = '',
    required this.reward,
    required this.done,
    // this.timeLeft,
  });
}

class _LeaderboardEntry {
  final String medal;
  final String name;
  final String score;
  final bool isSelf;

  const _LeaderboardEntry({
    required this.medal,
    required this.name,
    required this.score,
    this.isSelf = false,
  });
}
