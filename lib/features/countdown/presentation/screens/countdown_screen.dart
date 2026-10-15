import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF0E1A12);
  static const Color backgroundMid = Color(0xFF0A140E);
  static const Color backgroundBottom = Color(0xFF070D0A);

  static const Color countdownNumber = Color(0xFFFF6B35);
  static const Color countdownGlow = Color(0xFFFF6B35);
  static const Color label = Color(0xFF817995);

  static const Color comboBg = Color(0x33FF6B35); // orange @ 20%
  static const Color comboBorder = Color(0xB3FF6B35); // orange @ 70%
  static const Color comboText = Color(0xFFFFB380); // soft orange
}

class AppTypography {
  static const TextStyle countdown = TextStyle(
    fontSize: 140,
    fontWeight: FontWeight.w900,
    height: 1.0,
    color: AppColors.countdownNumber,
    letterSpacing: -2.0,
  );
  static const TextStyle getReady = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.label,
    letterSpacing: 4.0,
  );
  static const TextStyle combo = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.comboText,
    letterSpacing: 0.5,
  );
}

// ==========================================
// COUNTDOWN SCREEN
// ==========================================
class CountdownScreen extends StatefulWidget {
  /// Where to navigate once the countdown reaches GO.
  final String nextRoute;

  /// Starting number (inclusive). Defaults to 3.
  final int from;

  const CountdownScreen({super.key, this.nextRoute = '/game', this.from = 3});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with SingleTickerProviderStateMixin {
  /// Current number displayed. 0 = GO.
  late int _count;

  /// Periodic tick that decrements `_count` once per second.
  Timer? _tick;

  /// One controller drives the number's scale pulse and the glow halo.
  late final AnimationController _pulse;
  late final Animation<double> _pulseValue;

  @override
  void initState() {
    super.initState();

    _count = widget.from;

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseValue = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

    // Kick off the countdown. Each tick decrements; when we hit 0
    // ("GO"), we navigate on the next frame.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_count <= 1) {
        _tick?.cancel();
        setState(() => _count = 0); // show "GO"
        // Give the user a beat to read "GO" before navigating.
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted && context.mounted) context.go(widget.nextRoute);
        });
      } else {
        setState(() => _count -= 1);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _display {
    return _count == 0 ? 'GO' : '$_count';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              AppColors.backgroundTop,
              AppColors.backgroundMid,
              AppColors.backgroundBottom,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------- Big number with glow ----------
                _buildNumber(),

                const SizedBox(height: 12),

                // ---------- GET READY ----------
                const Text('GET READY...', style: AppTypography.getReady),

                const SizedBox(height: 20),

                // ---------- Combo pill ----------
                _buildComboPill(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NUMBER (glow + scale pulse + switch animation between digits)
  // ---------------------------------------------------------------------------
  Widget _buildNumber() {
    return RepaintBoundary(
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing radial glow behind the number
            AnimatedBuilder(
              animation: _pulseValue,
              builder: (context, _) {
                final p = _pulseValue.value; // 0..1
                final size = 180.0 + 30.0 * p;
                final alpha = 0.30 + 0.25 * p;
                return IgnorePointer(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.countdownGlow.withValues(alpha: alpha),
                          AppColors.countdownGlow.withValues(
                            alpha: alpha * 0.4,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Number with scale pulse + animated switch between digits
            AnimatedBuilder(
              animation: _pulseValue,
              builder: (context, child) {
                final scale = 1.0 + 0.08 * _pulseValue.value;
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.6,
                        end: 1.0,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _display,
                  key: ValueKey<int>(_count),
                  style: AppTypography.countdown,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMBO PILL
  // ---------------------------------------------------------------------------
  Widget _buildComboPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.comboBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.comboBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.countdownGlow.withValues(alpha: 0.20),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('x1 COMBO', style: AppTypography.combo),
          SizedBox(width: 6),
          Text('⚡', style: TextStyle(fontSize: 14, height: 1.0)),
        ],
      ),
    );
  }
}
