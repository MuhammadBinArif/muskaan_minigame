import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─── Theme Tokens ───────────────────────────────────────────────────────────

class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);
  static const Color overlay = Color(0x80000000);
  static const Color sheetBg = Color(0xFF2D2D4A);
  static const Color sheetBorder = Color(0x0FFFFFFF);
  static const Color dragHandle = Color(0xFF4D4D6A);
  static const Color cardBg = Color(0xFF252542);
  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color mutedGrey = Color(0xFF817995);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF3CB371);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color btnGradientStart = Color(0xFFFF6B35);
  static const Color btnGradientEnd = Color(0xFFFFD700);
}

class AppTypography {
  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.titleCream,
  );
  static const TextStyle cardDesc = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.6,
  );
}

// ─── Mode Model ─────────────────────────────────────────────────────────────

class Mode {
  final String emoji;
  final String title;
  final String desc;
  final Color accent;

  const Mode({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.accent,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _press;

  late final Animation<double> _overlayFade;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;
  late final Animation<double> _btnFade;
  late final Animation<double> _btnScale;

  int _selectedIndex = 0;
  bool _isDismissing = false;

  // All three modes funnel through `/countdown` → `/game` → `/results`.
  // No `route` field exists to leak a stale destination.
  static const List<Mode> _modes = <Mode>[
    Mode(
      emoji: '⚔️',
      title: 'Daily Battle',
      desc: "Compete on today's leaderboard",
      accent: AppColors.accentOrange,
    ),
    Mode(
      emoji: '🏋️',
      title: 'Practice Mode',
      desc: 'Unlimited rounds, no leaderboard',
      accent: AppColors.accentGreen,
    ),
    Mode(
      emoji: '😁',
      title: 'Smile Spotlight',
      desc: 'Rate your smile and share',
      accent: AppColors.accentGold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _press.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _overlayFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _cardFades = List<Animation<double>>.generate(_modes.length, (i) {
      return CurvedAnimation(
        parent: _entry,
        curve: Interval(
          0.40 + i * 0.10,
          0.60 + i * 0.10,
          curve: Curves.easeOut,
        ),
      );
    });
    _cardSlides = List<Animation<Offset>>.generate(_modes.length, (i) {
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entry,
          curve: Interval(
            0.40 + i * 0.10,
            0.65 + i * 0.10,
            curve: Curves.easeOutBack,
          ),
        ),
      );
    });

    _btnFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.75, 0.95, curve: Curves.easeOut),
    );
    _btnScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.75, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  void _onSelect(int index) {
    if (index == _selectedIndex) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selectedIndex = index);
  }

  /// Deterministic: every mode goes to `/countdown`. No query string,
  /// no conditional, no way to leak to `/filmi-smile`.
  void _confirm() {
    context.go('/countdown');
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    setState(() => _isDismissing = true);

    try {
      await _entry.reverse();
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FadeTransition(
              opacity: _overlayFade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const ColoredBox(color: AppColors.overlay),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              child: SlideTransition(
                position: _sheetSlide,
                child: _buildSheet(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.sheetBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Choose Mode', style: AppTypography.heading),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _modes.length; i++)
                FadeTransition(
                  opacity: _cardFades[i],
                  child: SlideTransition(
                    position: _cardSlides[i],
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModeCard(
                        mode: _modes[i],
                        selected: i == _selectedIndex,
                        onTap: () => _onSelect(i),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _btnFade,
                child: ScaleTransition(
                  scale: _btnScale,
                  child: _buildConfirmButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut)),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            onTapDown: (_) => _press.forward(),
            onTapUp: (_) async {
              await _press.reverse();
              if (!mounted) return;
              _confirm();
            },
            onTapCancel: () => _press.reverse(),
            child: const Center(
              child: Text('CONFIRM MODE', style: AppTypography.button),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final Mode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.title}. ${mode.desc}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentOrange : Colors.transparent,
              width: selected ? 2 : 1,
            ),
            boxShadow: null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode.accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mode.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(mode.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mode.title, style: AppTypography.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      mode.desc,
                      style: AppTypography.cardDesc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected
                            ? AppColors.accentOrange
                            : AppColors.dragHandle,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
