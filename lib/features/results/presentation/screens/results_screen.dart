import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/game_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1A2E);
  static const Color backgroundBottom = Color(0xFF0D0D1A);

  static const Color cardBg = Color(0xFF252542);
  static const Color tileBg = Color(0xFF1A1A2E);
  static const Color tileBorder = Color(0xFF3D3D5C);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color smileRowBg = Color(0x1AFFD700);
  static const Color smileRowBorder = Color(0x4DFFD700);
}

class AppTypography {
  static const TextStyle sessionLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedGrey,
    letterSpacing: 3.0,
  );
  static const TextStyle score = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.accentGold,
    height: 1.0,
    letterSpacing: 0.5,
  );
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.5,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.bodyGrey,
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
  static const TextStyle smileLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.accentGold,
  );
  static const TextStyle smileValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.accentGold,
  );
  static const TextStyle primaryBtn = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.6,
  );
  static const TextStyle secondaryBtn = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.accentOrange,
    letterSpacing: 0.6,
  );
}

// ==========================================
// RESULTS SCREEN
// ==========================================
class ResultsScreen extends ConsumerWidget {
  final GameSessionRecord? gameRecord;

  const ResultsScreen({super.key, this.gameRecord});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = gameRecord ?? _emptyRecord();

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
          child: _ResultsBody(
            record: record,
            isNewBest: record.isNewBest,
            onPlayAgain: () {
              final session = ref.read(gameSessionProvider);
              if (session.isSaving || session.saveError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Save this result before starting another round. Use Retry save if needed.',
                    ),
                  ),
                );
                return;
              }
              context.go('/countdown');
            },
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  static GameSessionRecord _emptyRecord() {
    return GameSessionRecord.create().complete(
      finalScore: 0,
      finalLivesLost: 0,
      timePlayed: 0,
      finalBestCombo: 0,
      finalCatches: 0,
      finalAccuracy: 0.0,
      finalSmileScore: 0,
    );
  }
}

// ==========================================
// RESULTS BODY
// ==========================================
class _ResultsBody extends StatefulWidget {
  final GameSessionRecord record;
  final VoidCallback onPlayAgain;
  final bool isNewBest;

  const _ResultsBody({
    required this.record,
    required this.isNewBest,
    required this.onPlayAgain,
  });

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody>
    with TickerProviderStateMixin {
  late final AnimationController _countUp;
  late final Animation<double> _countAnimation;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();

    _countUp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _countAnimation = Tween<double>(
      begin: 0,
      end: widget.record.score.toDouble(),
    ).animate(CurvedAnimation(parent: _countUp, curve: Curves.easeOutCubic));
    _countUp.forward();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _countUp.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildThisRoundCard(),
          const SizedBox(height: 16),
          _buildPrimaryButton(context),
          const SizedBox(height: 10),
          _buildSecondaryButton(context),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          left: -40,
          right: -40,
          child: IgnorePointer(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.9,
                  colors: [
                    AppColors.accentGold.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            const Text('SESSION COMPLETE', style: AppTypography.sessionLabel),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: Listenable.merge([_countAnimation, _glow]),
              builder: (context, _) {
                final value = _countAnimation.value.round();
                final p = _glow.value;
                return Text(
                  _format(value),
                  style: AppTypography.score.copyWith(
                    shadows: [
                      Shadow(
                        color: AppColors.accentGold.withValues(
                          alpha: 0.35 + 0.35 * p,
                        ),
                        blurRadius: 18 + 14 * p,
                      ),
                      Shadow(
                        color: AppColors.accentGold.withValues(alpha: 0.20 * p),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (widget.isNewBest) _buildNewBestBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildNewBestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [AppColors.accentOrange, AppColors.accentGold],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⭐', style: TextStyle(fontSize: 14, height: 1.0)),
          SizedBox(width: 6),
          Text('NEW BEST!', style: AppTypography.badge),
        ],
      ),
    );
  }

  // ── This Round ─────────────────────────────────────────────
  Widget _buildThisRoundCard() {
    final r = widget.record;

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
          const Text('This Round', style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatTile('🫧', '${r.catches}', 'Catches')),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile('⚡', 'x${r.bestCombo}', 'Best Combo'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  '🎯',
                  '${(r.accuracy * 100).toStringAsFixed(0)}%',
                  'Accuracy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile('⏱️', _formatTime(r.timePlayed), 'Time'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmileRow(r.smileScore),
        ],
      ),
    );
  }

  Widget _buildStatTile(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tileBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20, height: 1.0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: AppTypography.statValue),
                const SizedBox(height: 2),
                Text(label, style: AppTypography.statLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmileRow(int smileScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.smileRowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.smileRowBorder, width: 1),
      ),
      child: Row(
        children: [
          const Text('😁', style: TextStyle(fontSize: 18, height: 1.0)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Smile Score', style: AppTypography.smileLabel),
          ),
          Text('$smileScore%', style: AppTypography.smileValue),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.accentGold,
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────
  Widget _buildPrimaryButton(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.accentOrange, AppColors.accentGold],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onPlayAgain,
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔄', style: TextStyle(fontSize: 14, height: 1.0)),
                SizedBox(width: 8),
                Text('PLAY AGAIN', style: AppTypography.primaryBtn),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentOrange, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/share'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📤', style: TextStyle(fontSize: 14, height: 1.0)),
                SizedBox(width: 8),
                Text('SHARE RESULT', style: AppTypography.secondaryBtn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FORMATTERS
// ==========================================
String _format(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _formatTime(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
