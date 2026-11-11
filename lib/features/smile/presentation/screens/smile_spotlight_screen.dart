import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../profile/presentation/widgets/player_identity.dart';
import '../../../profile/data/player_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tracking/domain/mouth_tracking_provider.dart';
import '../../domain/smile_measurement.dart';
import '../providers/smile_analytics_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_bottom_nav.dart';

// ==========================================
// THEME TOKENS
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF1A1525);
  static const Color backgroundBottom = Color(0xFF0D0816);

  static const Color backBtnBg = Color(0xFF252542);

  static const Color cardBg = Color(0xFF252542);
  static const Color cardBorder = Color(0xFF3D3D5C);

  static const Color barTrack = Color(0xFF1A1A2E);
  static const Color disclaimerBg = Color(0xFF1A1A2E);
  static const Color disclaimerBorder = Color(0xFF3D3D5C);

  static const Color titleCream = Color(0xFFFDF5E6);
  static const Color bodyGrey = Color(0xFFC9C3D8);
  static const Color mutedGrey = Color(0xFF817995);

  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentGreen = Color(0xFF3CB371);

  static const Color ringTrack = Color(0x26FFD700); // gold @ 15%
  static const Color ringBorder = Color(0x66FFD700); // gold @ 40%
  static const Color avatarBgStart = Color(0xFF2D2D4A);
  static const Color avatarBgEnd = Color(0xFF252542);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.titleCream,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
  );
  static const TextStyle score = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.accentGold,
    height: 1.0,
    letterSpacing: -1,
  );
  static const TextStyle scoreLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
    letterSpacing: 3.5,
  );
  static const TextStyle badge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 0.6,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.bodyGrey,
  );
  static const TextStyle barLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.bodyGrey,
  );
  static const TextStyle barValue = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle disclaimer = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedGrey,
    height: 1.5,
  );
}

// ==========================================
// SMILE SPOTLIGHT SCREEN
// ==========================================
class SmileSpotlightScreen extends ConsumerStatefulWidget {
  const SmileSpotlightScreen({super.key});
  @override
  ConsumerState<SmileSpotlightScreen> createState() =>
      _SmileSpotlightScreenState();
}

class _SmileSpotlightScreenState extends ConsumerState<SmileSpotlightScreen>
    with TickerProviderStateMixin {
  bool _started = false;
  MouthTrackingController? _controller;
  ProviderSubscription<MouthTrackingState>? _measurementSubscription;
  SmileRoundStatisticsCollector? _collector;
  late final AppLifecycleListener _lifecycle;
  int? get _intensity =>
      _started
          ? ref
              .read(mouthTrackingProvider)
              .smile
              ?.smoothedCalibratedIntensity
              ?.round()
          : null;

  /// One-shot: drives ring sweep + score count-up + bars fill.
  late final AnimationController _scoreAnim;
  late final Animation<double> _scoreCurve;

  /// Ping-pong: drives glow halos.
  late final AnimationController _glow;

  /// Ring geometry constants.
  static const double _ringSize = 120;
  static const double _ringStroke = 7;
  static const double _ringRadius = 44;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () {
        unawaited(_controller?.stopTracking());
      },
      onPause: () {
        unawaited(_controller?.stopTracking());
      },
      onHide: () {
        unawaited(_controller?.stopTracking());
      },
      onResume: () {
        if (_started) unawaited(_controller?.startTracking());
      },
    );

    _scoreAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scoreCurve = CurvedAnimation(
      parent: _scoreAnim,
      curve: Curves.easeOutCubic,
    );
    _scoreAnim.forward();

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _measurementSubscription?.close();
    unawaited(_controller?.stopTracking());
    _scoreAnim.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_started) ref.watch(mouthTrackingProvider);
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
                _buildAppBar(context),
                const SizedBox(height: 20),
                _buildHero(context),
                const SizedBox(height: 20),
                _buildVibeBreakdown(),
                const SizedBox(height: 14),
                _buildHistoricalProgress(),
                const SizedBox(height: 14),
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  String _status() {
    final tracking = ref.read(mouthTrackingProvider);
    if (tracking.hasCameraError || tracking.error != null) {
      return 'Camera unavailable';
    }
    if (!tracking.isStreaming) return 'Measurement unavailable';
    if (!tracking.isFaceDetected) return 'Face not detected';
    return tracking.smile == null
        ? 'Measurement unavailable'
        : tracking.smile!.smoothedCalibratedIntensity == null
        ? 'Smile calibration unavailable'
        : 'Live calibrated on-device intensity';
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        // Back button — safe pop.
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
                  context.go('/home');
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Smile Spotlight', style: AppTypography.title),
              SizedBox(height: 2),
              Text(
                'Entertainment only — not scientific',
                style: AppTypography.subtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HERO — ring + score + label + badge
  // ---------------------------------------------------------------------------
  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        const PlayerIdentity(),
        // Ring + avatar
        RepaintBoundary(child: _buildProgressRing()),
        const SizedBox(height: 12),

        // Score
        AnimatedBuilder(
          animation: Listenable.merge([_scoreCurve, _glow]),
          builder: (context, _) {
            final value = _intensity;
            final p = _glow.value;
            return Text(
              value == null ? '—' : '$value%',
              style: AppTypography.score.copyWith(
                shadows: [
                  Shadow(
                    color: AppColors.accentGold.withValues(
                      alpha: 0.35 + 0.35 * p,
                    ),
                    blurRadius: 18 + 12 * p,
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
        const SizedBox(height: 4),
        const Text('SMILE INTENSITY', style: AppTypography.scoreLabel),
        const SizedBox(height: 12),

        // RADIANT badge
        Text(_started ? _status() : 'Start the camera to measure a smile.'),
        TextButton(
          onPressed: _startMeasurement,
          child: const Text('Start measurement'),
        ),
        TextButton(
          onPressed: _stopMeasurement,
          child: const Text('Stop measurement'),
        ),
      ],
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: _ringSize,
      height: _ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: Listenable.merge([_scoreCurve, _glow]),
            builder: (context, _) {
              final progress = ((_intensity ?? 0) / 100);
              final p = _glow.value;
              return CustomPaint(
                size: const Size(_ringSize, _ringSize),
                painter: _RingPainter(
                  progress: progress,
                  strokeWidth: _ringStroke,
                  radius: _ringRadius,
                  trackColor: AppColors.ringTrack,
                  startColor: AppColors.accentOrange,
                  endColor: AppColors.accentGold,
                  glowAlpha: 0.25 + 0.25 * p,
                ),
              );
            },
          ),

          // Avatar (emoji inside a gradient circle)
          Container(
            width: _ringSize - 20,
            height: _ringSize - 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.avatarBgStart, AppColors.avatarBgEnd],
              ),
              border: Border.all(color: AppColors.ringBorder, width: 2),
            ),
            child: Text(
              ref.watch(playerProfileProvider).asData?.value.avatar ?? '🥷',
              style: const TextStyle(fontSize: 34, height: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeBreakdown() {
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
          const Text('Measurement details', style: AppTypography.sectionTitle),
          const SizedBox(height: 14),
          const Text(
            'Calibrated on-device smile intensity; not an emotion measurement.',
          ),
          const SizedBox(height: 10),
          Text(
            _collector?.statistics.averageCalibratedIntensity == null
                ? 'Average Smile Intensity: unavailable'
                : 'Average Smile Intensity: ${_collector!.statistics.averageCalibratedIntensity!.round()}%',
          ),
          const SizedBox(height: 6),
          Text(
            _collector?.statistics.peakCalibratedIntensity == null
                ? 'Peak Smile Intensity: unavailable'
                : 'Peak Smile Intensity: ${_collector!.statistics.peakCalibratedIntensity!.round()}%',
          ),
          const SizedBox(height: 10),
          const Text('Processed on this device. No face images are saved.'),
        ],
      ),
    );
  }

  Widget _buildHistoricalProgress() {
    final player = ref.watch(playerProfileProvider).asData?.value;
    if (player == null) return const SizedBox.shrink();
    final history = ref.watch(
      playerSmileHistoryProvider(
        SmileHistoryQuery(player.id, SmileAnalyticsRange.thirtyDays),
      ),
    );
    return Container(
      key: const Key('spotlight-historical-progress'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: history.when(
        loading: () => const Text('Loading historical progress…'),
        error:
            (_, _) => const Text(
              'Historical progress is unavailable. Saved results were preserved.',
            ),
        data: (rounds) {
          final summary = playerSmileAnalytics.progress(rounds);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Historical progress · last 30 days',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 10),
              Text(
                summary == null
                    ? 'No calibrated measured rounds are available.'
                    : '${summary.eligibleRoundCount} measured rounds · '
                        '${summary.averageOfRoundAverages.toStringAsFixed(1)}% average of round averages · '
                        '${summary.highestPeakIntensity.toStringAsFixed(1)}% highest peak',
              ),
              const SizedBox(height: 8),
              const Text(
                'Historical values come from completed rounds. Live measurement above belongs only to this session.',
                style: AppTypography.disclaimer,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startMeasurement() async {
    _controller = ref.read(mouthTrackingProvider.notifier);
    final player = ref.read(playerProfileProvider).asData?.value;
    if (player == null) return;
    _collector = SmileRoundStatisticsCollector(
      playerId: player.id,
      roundId: DateTime.now().microsecondsSinceEpoch,
    );
    _measurementSubscription?.close();
    _measurementSubscription = ref.listenManual<MouthTrackingState>(
      mouthTrackingProvider,
      (_, next) {
        final measurement = next.smile;
        if (measurement != null &&
            _collector!.add(measurement, now: DateTime.now()) &&
            mounted) {
          setState(() {});
        }
      },
      fireImmediately: true,
    );
    if (mounted) setState(() => _started = true);
    await _controller!.startTracking();
  }

  void _stopMeasurement() {
    _measurementSubscription?.close();
    _measurementSubscription = null;
    unawaited(_controller?.stopTracking());
    if (mounted) setState(() => _started = false);
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.disclaimerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.disclaimerBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚠️', style: TextStyle(fontSize: 14, height: 1.2)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Smile Spotlight is purely for entertainment. '
              'It does not represent scientific or biometric measurement.',
              style: AppTypography.disclaimer,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// RING PAINTER
// ==========================================
class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final double strokeWidth;
  final double radius;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double glowAlpha;

  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.radius,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (swept clockwise starting from the top)
    if (progress > 0) {
      final progressPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: -math.pi / 2,
              endAngle: 3 * math.pi / 2,
              colors: [startColor, endColor],
              transform: const GradientRotation(-math.pi / 2),
            ).createShader(rect);

      // Ambient glow (slightly wider, blurred, low alpha)
      final glowPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 4
            ..strokeCap = StrokeCap.round
            ..color = endColor.withValues(alpha: glowAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.glowAlpha != glowAlpha ||
      old.startColor != startColor ||
      old.endColor != endColor;
}
