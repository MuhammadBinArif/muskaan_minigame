import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color backBtnBg = Color(0xFF252542);
  static const Color cardBg = Color(0xFF252542);
  static const Color barTrack = Color(0xFF1A1A2E);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);

  // Icon container
  static const Color iconBg1 = Color(0x33FF6B35); // orange @ 20%
  static const Color iconBg2 = Color(0x14FFD700); // gold @ 8%
  static const Color iconBorder = Color(0x66FF6B35);

  // Reward card
  static const Color rewardBg1 = Color(0x1AFFD700); // gold @ 10%
  static const Color rewardBg2 = Color(0x0DFF6B35); // orange @ 5%
  static const Color rewardBorder = Color(0x4DFFD700); // gold @ 30%
  static const Color rewardIconBg = Color(0x26FFD700); // gold @ 15%
  static const Color rewardIconBorder = Color(0x66FFD700);
}

class AppTypography {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle challengeTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle description = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGrey,
    height: 1.6,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle percent = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.accentOrange,
  );
  static const TextStyle barMeta = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle rewardLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
  static const TextStyle rewardValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
  static const TextStyle rewardSub = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
  );
  static const TextStyle timeTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle timeValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.accentOrange,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.6,
  );
}

// ==========================================
// CHALLENGE DETAIL SCREEN
// ==========================================
class ChallengeDetailScreen extends StatefulWidget {
  // ---- Configurable content (all optional with Figma defaults) ----
  final String emoji;
  final String title;
  final String description;
  final int caught;
  final int target;
  final int rewardPoints;
  final String badgeName;
  final String timeRemaining;

  const ChallengeDetailScreen({
    super.key,
    this.emoji = '🌊',
    this.title = 'Gol Gappa Tsunami',
    this.description =
        'Catch 100 gol gappas in one session without missing 3 in a row. '
        'Show your true mastery!',
    this.caught = 68,
    this.target = 100,
    this.rewardPoints = 750,
    this.badgeName = 'Tsunami Badge',
    this.timeRemaining = '5h 22m',
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with TickerProviderStateMixin {
  /// One-shot: drives progress-bar fill.
  late final AnimationController _progressAnim;

  /// Ping-pong: drives card-glow halos.
  late final AnimationController _glow;

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

  double get _progress => widget.caught / widget.target;
  int get _remaining => widget.target - widget.caught;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAppBar(context),
                const SizedBox(height: 20),
                _buildHero(),
                const SizedBox(height: 24),
                _buildProgressCard(),
                const SizedBox(height: 12),
                _buildRewardCard(),
                const SizedBox(height: 12),
                _buildTimeCard(),
                const SizedBox(height: 20),
                _buildPlayNowButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Material(
            color: AppColors.backBtnBg,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/challenges');
                }
              },
              child: const Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.bodyGrey,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text('Challenge Detail', style: AppTypography.pageTitle),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HERO — big icon + title + description
  // ---------------------------------------------------------------------------
  Widget _buildHero() {
    return Column(
      children: [
        // Pulsing glow behind icon + the icon itself
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final p = _glow.value;
              return Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.iconBg1, AppColors.iconBg2],
                  ),
                  border: Border.all(color: AppColors.iconBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withValues(
                        alpha: 0.20 + 0.25 * p,
                      ),
                      blurRadius: 12 + 12 * p,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 34, height: 1.0),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTypography.challengeTitle,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.description,
            textAlign: TextAlign.center,
            style: AppTypography.description,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PROGRESS CARD
  // ---------------------------------------------------------------------------
  Widget _buildProgressCard() {
    final percent = (_progress * 100).round();

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final p = _glow.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.08 + 0.14 * p,
                ),
                blurRadius: 10 + 10 * p,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your Progress', style: AppTypography.sectionTitle),
              ),
              Text('$percent%', style: AppTypography.percent),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          _buildProgressBar(),

          const SizedBox(height: 8),

          Row(
            children: [
              Text('${widget.caught} caught', style: AppTypography.barMeta),
              const Spacer(),
              Text('$_remaining to go', style: AppTypography.barMeta),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.barTrack,
        borderRadius: BorderRadius.circular(6),
      ),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_progressAnim.value);
          final widthFactor = (_progress * t).clamp(0.0, 1.0);
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [AppColors.accentOrange, AppColors.accentGold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentOrange.withValues(alpha: 0.50),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REWARD CARD
  // ---------------------------------------------------------------------------
  Widget _buildRewardCard() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final p = _glow.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.rewardBg1, AppColors.rewardBg2],
            ),
            border: Border.all(color: AppColors.rewardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGold.withValues(alpha: 0.08 + 0.12 * p),
                blurRadius: 10 + 8 * p,
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
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.rewardIconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rewardIconBorder),
            ),
            child: const Text(
              '🏅',
              style: TextStyle(fontSize: 22, height: 1.0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Completion Reward',
                  style: AppTypography.rewardLabel,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      '⭐',
                      style: TextStyle(fontSize: 14, height: 1.0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.rewardPoints} pts',
                      style: AppTypography.rewardValue,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+ ${widget.badgeName} unlock',
                  style: AppTypography.rewardSub,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TIME REMAINING CARD
  // ---------------------------------------------------------------------------
  Widget _buildTimeCard() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final p = _glow.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.06 + 0.10 * p,
                ),
                blurRadius: 8 + 8 * p,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 22, height: 1.0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Time Remaining', style: AppTypography.timeTitle),
              ],
            ),
          ),
          Text(widget.timeRemaining, style: AppTypography.timeValue),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PLAY NOW
  // ---------------------------------------------------------------------------
  Widget _buildPlayNowButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppColors.accentOrange, AppColors.accentGold],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.go('/countdown'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('PLAY NOW', style: AppTypography.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
