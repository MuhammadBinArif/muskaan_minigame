import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backdropTop = Color(0xD90D1A0D); // #0D1A0D @ 85%
  static const Color backdropBottom = Color(0xD90A100A); // #0A100A @ 85%

  static const Color cardBg = Color(0xFF2D2D4A);
  static const Color cardBorder = Color(0x0FFFFFFF); // white @ 6%
  static const Color scorePanelBg = Color(0xFF1A1A2E);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);

  static const Color toggleOnBg = Color(0x26FF6B35); // orange @ 15%
  static const Color toggleOnBorder = Color(0x66FF6B35); // orange @ 40%
  static const Color toggleOffBg = Color(0x0DFFFFFF); // white @ 5%
  static const Color toggleOffBorder = Color(0x1AFFFFFF); // white @ 10%

  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
    letterSpacing: 0.5,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle scoreLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedGrey,
    letterSpacing: 3.0,
  );
  static const TextStyle scoreValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.accentGold,
    height: 1.0,
  );
  static const TextStyle toggle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.6,
  );
  static const TextStyle outlineButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.accentOrange,
    letterSpacing: 0.6,
  );
  static const TextStyle quit = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedGrey,
  );
}

// ==========================================
// PAUSE OVERLAY SCREEN
// ==========================================
class PauseOverlayScreen extends StatefulWidget {
  /// The score to display. Passed in by the gameplay layer.
  final String score;

  const PauseOverlayScreen({super.key, this.score = '8,420'});

  @override
  State<PauseOverlayScreen> createState() => _PauseOverlayScreenState();
}

class _PauseOverlayScreenState extends State<PauseOverlayScreen>
    with TickerProviderStateMixin {
  /// One-shot entry: fade + scale in.
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  /// Looping glow pulse for the card border.
  late final AnimationController _glow;

  /// Toggle states — hoisted here so they persist across rebuilds.
  bool _soundOn = true;
  bool _musicOn = true;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutBack));
    _entry.forward();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entry.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ---- Backdrop (green-dark gradient @ 85%) ----
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.backdropTop, AppColors.backdropBottom],
                ),
              ),
            ),
          ),

          // ---- Centered card (with entrance animation) ----
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD
  // ---------------------------------------------------------------------------
  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final p = _glow.value;
        return Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(
                  alpha: 0.14 + 0.20 * p,
                ),
                blurRadius: 12 + 12 * p,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Title ----
            const Text(
              '⏸ PAUSED',
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            const SizedBox(height: 4),
            const Text(
              'Your game is waiting',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),

            const SizedBox(height: 16),

            // ---- Score panel ----
            _buildScorePanel(),

            const SizedBox(height: 16),

            // ---- Toggles ----
            Row(
              children: [
                Expanded(
                  child: _ToggleButton(
                    icon: '🔊',
                    label: 'Sound',
                    isOn: _soundOn,
                    onTap: () => setState(() => _soundOn = !_soundOn),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleButton(
                    icon: '🎵',
                    label: 'Music',
                    isOn: _musicOn,
                    onTap: () => setState(() => _musicOn = !_musicOn),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---- Actions ----
            _buildResumeButton(context),
            const SizedBox(height: 10),
            _buildRestartButton(),
            const SizedBox(height: 4),
            _buildQuitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScorePanel() {
    // Number pulses its glow slightly in sync with the card.
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final p = _glow.value;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.scorePanelBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('CURRENT SCORE', style: AppTypography.scoreLabel),
              const SizedBox(height: 6),
              Text(
                widget.score,
                style: AppTypography.scoreValue.copyWith(
                  shadows: [
                    Shadow(
                      color: AppColors.accentGold.withValues(
                        alpha: 0.35 + 0.35 * p,
                      ),
                      blurRadius: 10 + 8 * p,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumeButton(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
          // Resume → back to gameplay.
          onTap: () => context.go('/game'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('▶', style: TextStyle(fontSize: 14, height: 1.0)),
                SizedBox(width: 8),
                Text('RESUME', style: AppTypography.button),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestartButton() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentOrange, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Restart → countdown → fresh game.
          onTap: () => context.go('/countdown'),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '↺',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.0,
                    color: AppColors.accentOrange,
                  ),
                ),
                SizedBox(width: 8),
                Text('RESTART', style: AppTypography.outlineButton),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuitButton(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: () => context.go('/home'),
        child: const Text('Quit Game', style: AppTypography.quit),
      ),
    );
  }
}

// ==========================================
// TOGGLE BUTTON
// ==========================================
class _ToggleButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool isOn;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isOn,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 40,
            decoration: BoxDecoration(
              color: isOn ? AppColors.toggleOnBg : AppColors.toggleOffBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOn
                    ? AppColors.toggleOnBorder
                    : AppColors.toggleOffBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14, height: 1.0)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.toggle.copyWith(
                    color: isOn ? AppColors.accentOrange : AppColors.mutedGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
