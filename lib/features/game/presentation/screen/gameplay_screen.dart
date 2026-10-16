import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';

import 'package:flutter/foundation.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';
import 'package:muskaan_minigame/features/game/presentation/flame/muskaan_flame_game.dart';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:muskaan_minigame/features/tracking/domain/face_tracking.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';

// ============================================================
// GAMEPLAY PHASE — visual state derived from GameSessionState
// ============================================================
enum GameplayPhase { idle, catchSuccess, hazardHit, comboActive, paused }

// ============================================================
// THEME
// ============================================================
class _C {
  static const bgTop = Color(0xFF14122A);
  static const bgMid = Color(0xFF0F0D22);
  static const bgBot = Color(0xFF07060F);

  static const heart = Color(0xFFED4B5C);
  static const scoreGold = Color(0xFFFFD86B);
  static const timerGold = Color(0xFFFFD86B);
  static const comboA = Color(0xFFFF7A1A);
  static const comboB = Color(0xFFFFC93C);
  static const mouthGreen = Color(0xFF3DD68C);
  static const danger = Color(0xFFE63946);

  static const textDim = Color(0xFF8E8AA0);
  static const textSoft = Color(0xFFC7C3D6);
  static const cream = Color(0xFFFDF5E6);

  static const cardBg = Color(0xFF1E1B33);
  static const cardBorder = Color(0x33FFFFFF);
}

class _T {
  static const score = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: _C.scoreGold,
    height: 1.0,
    letterSpacing: 0.5,
  );
  static const scoreLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: _C.textDim,
    letterSpacing: 4,
  );
  static const timer = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: _C.timerGold,
    height: 1.0,
  );
  static const mouthLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: _C.textDim,
    letterSpacing: 1.5,
  );
  static const comboBig = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.0,
  );
  static const comboSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.0,
    letterSpacing: 0.5,
  );
  static const plus = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: _C.scoreGold,
    height: 1.0,
  );
  static const hazard = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 1.5,
    height: 1.0,
  );
  static const hazardSub = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: _C.danger,
    letterSpacing: 2,
    height: 1.0,
  );
  static const pauseTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: _C.comboA,
    letterSpacing: 3,
  );
  static const pauseHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: _C.cream,
  );
  static const pauseScoreLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: _C.textDim,
    letterSpacing: 2,
  );
  static const pauseScore = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: _C.scoreGold,
    height: 1.0,
  );
  static const pausePrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );
  static const pauseQuit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: _C.danger,
  );
}

// ============================================================
// SCREEN
// ============================================================
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fall;
  late final AnimationController _pulse;
  late final AnimationController _float;
  late final AppLifecycleListener _lifecycle;
  late final MuskaanFlameGame _game;
  late final ValueNotifier<FaceGameControlStatus> _controlStatus;
  late final ValueNotifier<MouthTrackingState> _trackingUi;
  late final ProviderSubscription<MouthTrackingState> _trackingSubscription;
  GameSessionNotifier? _sessionController;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _fall = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _sessionController = ref.read(gameSessionProvider.notifier);
    _controlStatus = ValueNotifier(FaceGameControlStatus.searching);
    _trackingUi = ValueNotifier(ref.read(mouthTrackingProvider));
    _game = MuskaanFlameGame(
      controlConfig: _faceControlConfig(ref.read(calibrationConfigProvider)),
      onControlFrame: (isOpen, isActionable, targetX) {
        if (_disposed || !mounted) return;
        ref
            .read(gameSessionProvider.notifier)
            .updateMouthTracking(
              isOpen: isOpen,
              isActionable: isActionable,
              mouthX: targetX,
              mouthY: MuskaanFlameGame.targetY,
            );
      },
      onControlStatusChanged: (status) {
        if (!_disposed && _controlStatus.value != status) {
          _controlStatus.value = status;
        }
      },
    );
    _trackingSubscription = ref.listenManual<MouthTrackingState>(
      mouthTrackingProvider,
      _onTrackingChanged,
      fireImmediately: true,
    );
    _lifecycle = AppLifecycleListener(
      onPause: _pause,
      onInactive: _pause,
      onHide: _pause,
      onResume: () {
        final session = ref.read(gameSessionProvider);
        if (session.state == GameSessionState.playing) {
          _trackingController?.startTracking();
        }
      },
    );

    // Initialize camera tracking when entering Gameplay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _trackingController = ref.read(mouthTrackingProvider.notifier);
        _trackingController?.startTracking();
      }
    });
  }

  MouthTrackingController? _trackingController;

  @override
  void dispose() {
    _disposed = true;
    _trackingSubscription.close();
    _game.pauseEngine();
    _lifecycle.dispose();
    _fall.dispose();
    _pulse.dispose();
    _float.dispose();
    unawaited(_trackingController?.stopTracking());
    _sessionController?.leaveGame();
    _trackingUi.dispose();
    _controlStatus.dispose();
    super.dispose();
  }

  FaceGameControlConfig _faceControlConfig(CalibrationConfig config) =>
      FaceGameControlConfig(
        neutralX: config.neutralFacePosition.dx,
        horizontalRange: config.horizontalControlRange,
        sensitivity: 1,
        responsePerSecond: 10,
      );

  void _onTrackingChanged(
    MouthTrackingState? previous,
    MouthTrackingState next,
  ) {
    if (_disposed) return;
    _trackingUi.value = next;
    _game.setMouthOpen(next.latestTransition.isOpen);

    final unavailable = next.hasCameraError || next.error != null;
    final status =
        unavailable
            ? FaceGameControlStatus.unavailable
            : switch (next.tracking.status) {
              FaceTrackingStatus.searching => FaceGameControlStatus.searching,
              FaceTrackingStatus.tracking => FaceGameControlStatus.tracking,
              FaceTrackingStatus.temporarilyLost =>
                FaceGameControlStatus.temporarilyLost,
              FaceTrackingStatus.lost => FaceGameControlStatus.lost,
            };
    _game.applyTracking(
      FaceGameControlSample(
        normalizedX:
            status == FaceGameControlStatus.tracking
                ? next.tracking.position?.dx
                : null,
        status: status,
        observedAt: next.tracking.lastDetectedAt ?? next.tracking.updatedAt,
      ),
    );

    if (unavailable &&
        ref.read(gameSessionProvider).state == GameSessionState.playing) {
      ref.read(gameSessionProvider.notifier).pauseGame();
    }
  }

  void _pause() {
    ref.read(gameSessionProvider.notifier).pauseGame();
    _game.pauseControl();
    _game.pauseEngine();
    unawaited(ref.read(mouthTrackingProvider.notifier).stopTracking());
  }

  Future<void> _resume() async {
    await ref.read(mouthTrackingProvider.notifier).startTracking();
    if (!mounted) return;
    final tracking = ref.read(mouthTrackingProvider);
    if (tracking.isStreaming && !tracking.hasCameraError) {
      _game.resumeControl();
      _game.resumeEngine();
      ref.read(gameSessionProvider.notifier).resumeGame();
    }
  }

  Future<void> _startGame() async {
    final session = ref.read(gameSessionProvider);
    if (session.isSaving || session.saveError != null) {
      context.go('/results');
      return;
    }
    await ref.read(mouthTrackingProvider.notifier).startTracking();
    if (!mounted) return;
    final tracking = ref.read(mouthTrackingProvider);
    if (tracking.isStreaming && !tracking.hasCameraError) {
      _game.configureControl(
        _faceControlConfig(ref.read(calibrationConfigProvider)),
      );
      _game.resetControl();
      _game.resumeEngine();
      ref.read(gameSessionProvider.notifier).startGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    _game.syncSession(
      foods: session.activeFoods,
      isPlaying: session.state == GameSessionState.playing,
    );

    ref.listen<GameSessionStateData>(gameSessionProvider, (previous, next) {
      if (previous?.state != GameSessionState.gameOver &&
          next.state == GameSessionState.gameOver) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/game-over');
        });
      }
    });
    return Scaffold(
      backgroundColor: _C.bgBot,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final gameView =
              session.state == GameSessionState.playing ||
                      session.state == GameSessionState.paused
                  ? _buildActiveGame(session)
                  : _buildDemoView(w, h, session);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: gameView),
              ValueListenableBuilder<MouthTrackingState>(
                valueListenable: _trackingUi,
                builder: (context, trackingState, _) {
                  if (!trackingState.hasCameraError &&
                      trackingState.error == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 16,
                    right: 16,
                    top: MediaQuery.paddingOf(context).top + 64,
                    child: Material(
                      color: const Color(0xFF252542),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                trackingState.error ?? 'Camera unavailable',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  () => _trackingController?.startTracking(),
                              child: const Text('Retry camera'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEMO / PRE-GAME VIEW
  // ---------------------------------------------------------------------------
  Widget _buildDemoView(double w, double h, GameSessionStateData session) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Background(),
        if (session.state == GameSessionState.gameOver)
          Positioned.fill(
            child: _Vignette(phase: GameplayPhase.hazardHit, pulse: _pulse),
          ),
        if (session.state == GameSessionState.ready ||
            session.state == GameSessionState.gameOver)
          Positioned.fill(
            child: Center(
              child: _StartOverlay(
                onStart: _startGame,
                onQuit: () => context.go('/home'),
              ),
            ),
          )
        else ...[
          Positioned.fill(
            child: RepaintBoundary(
              child: _FallingLayer(controller: _fall, width: w, height: h),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, 0.02),
              child: RepaintBoundary(
                child: _MouthRing(
                  phase: _phaseFor(session.state),
                  pulse: _pulse,
                  float: _float,
                ),
              ),
            ),
          ),
        ],
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _TopHud(
                    lives: session.stats.lives,
                    score: session.stats.score,
                    time: session.stats.timeRemaining,
                    onPauseTap: _pause,
                    isPaused: session.state == GameSessionState.paused,
                  ),
                ),
                if (session.state == GameSessionState.playing) ...[
                  const SizedBox(height: 8),
                  _ComboPill(combo: session.stats.combo, pulse: _pulse),
                ],
              ],
            ),
          ),
        ),
        if (session.state == GameSessionState.paused)
          Positioned.fill(
            child: _PauseOverlay(
              score: session.stats.score,
              onResume: _resume,
              onQuit: () => context.go('/home'),
            ),
          ),
        if (session.state != GameSessionState.paused)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Text(
              session.state == GameSessionState.playing
                  ? 'Open your mouth wide to catch!'
                  : 'Tap READY to start your round',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _C.textSoft.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE GAME VIEW
  // ---------------------------------------------------------------------------
  Widget _buildActiveGame(GameSessionStateData session) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Background(),
        if (session.state == GameSessionState.gameOver)
          Positioned.fill(
            child: _Vignette(phase: GameplayPhase.hazardHit, pulse: _pulse),
          ),
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: GameWidget<MuskaanFlameGame>(game: _game),
            ),
          ),
        ),
        if (session.recentCollisions.isNotEmpty)
          _buildCollisionBanner(session.recentCollisions.first),
        if (session.recentCollisions.isNotEmpty &&
            session.recentCollisions.first.isCatch)
          Positioned.fill(child: _PlusPop(pulse: _pulse)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _TopHud(
                    lives: session.stats.lives,
                    score: session.stats.score,
                    time: session.stats.timeRemaining,
                    onPauseTap: _pause,
                    isPaused: session.state == GameSessionState.paused,
                  ),
                ),
                const SizedBox(height: 8),
                _ComboPill(combo: session.stats.combo, pulse: _pulse),
                const SizedBox(height: 6),
                ValueListenableBuilder<MouthTrackingState>(
                  valueListenable: _trackingUi,
                  builder:
                      (context, trackingState, _) => Text(
                        trackingState.latestTransition.isOpen
                            ? 'MOUTH OPEN'
                            : 'OPEN MOUTH',
                        style: _T.mouthLabel.copyWith(
                          color:
                              trackingState.latestTransition.isOpen
                                  ? _C.mouthGreen
                                  : _C.textDim,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
        if (session.state == GameSessionState.paused)
          Positioned.fill(
            child: _PauseOverlay(
              score: session.stats.score,
              onResume: _resume,
              onQuit: () => context.go('/home'),
            ),
          ),
        if (session.state == GameSessionState.playing)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<FaceGameControlStatus>(
              valueListenable: _controlStatus,
              builder:
                  (context, status, _) => _TrackingInstruction(status: status),
            ),
          ),
        if (!kReleaseMode)
          ValueListenableBuilder<MouthTrackingState>(
            valueListenable: _trackingUi,
            builder:
                (context, trackingState, _) => _DebugOverlay(
                  trackingState: trackingState,
                  config: ref.read(calibrationConfigProvider),
                ),
          ),
      ],
    );
  }

  Widget _buildCollisionBanner(CollisionEvent event) {
    if (event.isCatch) return const SizedBox.shrink();
    return Align(
      alignment: const Alignment(0, 0.02),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('HOT CHAI!!', style: _T.hazard),
          SizedBox(height: 6),
          Text('-LIFE', style: _T.hazardSub),
        ],
      ),
    );
  }

  GameplayPhase _phaseFor(GameSessionState state) {
    switch (state) {
      case GameSessionState.ready:
      case GameSessionState.preparing:
        return GameplayPhase.idle;
      case GameSessionState.playing:
        return GameplayPhase.comboActive;
      case GameSessionState.paused:
        return GameplayPhase.paused;
      case GameSessionState.gameOver:
        return GameplayPhase.hazardHit;
      case GameSessionState.results:
        return GameplayPhase.idle;
    }
  }
}

// ============================================================
// SUB-WIDGETS
// ============================================================
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_C.bgTop, _C.bgMid, _C.bgBot],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  final GameplayPhase phase;
  final AnimationController pulse;

  const _Vignette({required this.phase, required this.pulse});

  @override
  Widget build(BuildContext context) {
    if (phase != GameplayPhase.hazardHit) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final p = pulse.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  _C.danger.withValues(alpha: 0.18 + 0.22 * p),
                  _C.danger.withValues(alpha: 0.55 + 0.15 * p),
                ],
                stops: const [0.35, 0.75, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MouthRing extends StatelessWidget {
  final GameplayPhase phase;
  final AnimationController pulse;
  final AnimationController float;

  const _MouthRing({
    required this.phase,
    required this.pulse,
    required this.float,
  });

  @override
  Widget build(BuildContext context) {
    final isCatch = phase == GameplayPhase.catchSuccess;
    final isHazard = phase == GameplayPhase.hazardHit;

    final ringColor =
        isCatch
            ? _C.mouthGreen
            : isHazard
            ? _C.danger
            : _C.comboA;

    return AnimatedBuilder(
      animation: Listenable.merge([pulse, float]),
      builder: (context, _) {
        final p = pulse.value;
        final dy = math.sin(float.value * 2 * math.pi) * 4.0;
        final scale = 1.0 + 0.04 * p;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Container(
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              colors: [Color(0x33252542), Color(0x0014122A)],
                            ),
                          ),
                          child: Icon(
                            Icons.face_retouching_natural,
                            size: 44,
                            color: ringColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      CustomPaint(
                        size: const Size(160, 160),
                        painter: _BracketPainter(
                          color: _C.textSoft.withValues(alpha: 0.35),
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              ringColor.withValues(alpha: 0.10 + 0.18 * p),
                              ringColor.withValues(alpha: 0.02),
                            ],
                          ),
                          border: Border.all(
                            color: ringColor.withValues(alpha: 0.55 + 0.35 * p),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ringColor.withValues(
                                alpha: 0.25 + 0.35 * p,
                              ),
                              blurRadius: 20 + 12 * p,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('OPEN MOUTH', style: _T.mouthLabel),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

    const arm = 12.0;
    canvas.drawLine(const Offset(0, arm), Offset.zero, p);
    canvas.drawLine(Offset.zero, const Offset(arm, 0), p);
    canvas.drawLine(Offset(size.width - arm, 0), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, arm), p);
    canvas.drawLine(Offset(0, size.height - arm), Offset(0, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(arm, size.height), p);
    canvas.drawLine(
      Offset(size.width - arm, size.height),
      Offset(size.width, size.height),
      p,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - arm),
      p,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

class _FallingLayer extends StatelessWidget {
  final AnimationController controller;
  final double width;
  final double height;

  const _FallingLayer({
    required this.controller,
    required this.width,
    required this.height,
  });

  static const List<_FallItem> _items = <_FallItem>[
    _FallItem(kind: _ItemKind.gold, left: 0.12, phase: 0.00, size: 34),
    _FallItem(kind: _ItemKind.teal, left: 0.82, phase: 0.22, size: 32),
    _FallItem(kind: _ItemKind.gold, left: 0.28, phase: 0.42, size: 28),
    _FallItem(kind: _ItemKind.chai, left: 0.55, phase: 0.10, size: 30),
    _FallItem(kind: _ItemKind.gold, left: 0.72, phase: 0.55, size: 32),
    _FallItem(kind: _ItemKind.gold, left: 0.45, phase: 0.78, size: 30),
    _FallItem(kind: _ItemKind.teal, left: 0.20, phase: 0.65, size: 26),
    _FallItem(kind: _ItemKind.gold, left: 0.62, phase: 0.90, size: 28),
  ];

  @override
  Widget build(BuildContext context) {
    const pad = 40.0;
    final travel = height + pad * 2;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [for (final item in _items) _buildItem(item, travel, pad)],
        );
      },
    );
  }

  Widget _buildItem(_FallItem item, double travel, double pad) {
    final t = (controller.value + item.phase) % 1.0;
    final y = -pad + t * travel;
    final fade = t > 0.88 ? (1 - (t - 0.88) / 0.12) : 1.0;

    return Positioned(
      top: y,
      left: item.left * width - item.size / 2,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: IgnorePointer(
          child: _ItemIcon(kind: item.kind, size: item.size),
        ),
      ),
    );
  }
}

class _FallItem {
  final _ItemKind kind;
  final double left;
  final double phase;
  final double size;

  const _FallItem({
    required this.kind,
    required this.left,
    required this.phase,
    required this.size,
  });
}

enum _ItemKind { gold, teal, chai }

class _ItemIcon extends StatelessWidget {
  final _ItemKind kind;
  final double size;

  const _ItemIcon({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _ItemKind.gold:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFFFFE28A), Color(0xFFD4A24A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD86B).withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
        );
      case _ItemKind.teal:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFFB8F0E5), Color(0xFF3FB39A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3FB39A).withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
        );
      case _ItemKind.chai:
        return Container(
          width: size,
          height: size * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.15),
            color: const Color(0xFFC89060),
            border: Border.all(color: const Color(0xFF8A5A34), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC89060).withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text('☕', style: TextStyle(fontSize: size * 0.5, height: 1.0)),
        );
    }
  }
}

class _StartOverlay extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onQuit;

  const _StartOverlay({required this.onStart, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final width = math.min(320.0, MediaQuery.sizeOf(context).width - 48);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_C.comboA, _C.comboB]),
              boxShadow: [
                BoxShadow(
                  color: _C.comboA.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'READY TO PLAY',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let the street food rush begin',
            style: TextStyle(fontSize: 12, color: _C.textSoft),
          ),
          const SizedBox(height: 24),
          _PrimaryBtn(label: 'READY', onTap: onStart),
          const SizedBox(height: 12),
          _OutlineBtn(label: 'QUIT ROUND', onTap: onQuit),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [_C.comboA, _C.comboB]),
        boxShadow: [
          BoxShadow(
            color: _C.comboA.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: Text(label, style: _T.pausePrimary)),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.danger.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: Text(label, style: _T.pauseQuit)),
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final int lives;
  final int score;
  final int time;
  final bool isPaused;
  final VoidCallback onPauseTap;

  const _TopHud({
    required this.lives,
    required this.score,
    required this.time,
    required this.isPaused,
    required this.onPauseTap,
  });

  String get _formattedScore {
    final s = score.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: List.generate(3, (i) {
            final filled = i < lives;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                '❤',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.0,
                  color: filled ? _C.heart : _C.heart.withValues(alpha: 0.25),
                ),
              ),
            );
          }),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formattedScore, style: _T.score),
              const SizedBox(height: 3),
              const Text('SCORE', style: _T.scoreLabel),
            ],
          ),
        ),
        Text('$time', style: _T.timer),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: isPaused ? 'Resume' : 'Pause',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPauseTap,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow : Icons.pause,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComboPill extends StatelessWidget {
  final int combo;
  final AnimationController pulse;

  const _ComboPill({required this.combo, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final p = pulse.value;
        final scale = 1.0 + 0.05 * p;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [_C.comboA, _C.comboB]),
              boxShadow: [
                BoxShadow(
                  color: _C.comboA.withValues(alpha: 0.45 + 0.30 * p),
                  blurRadius: 14 + 10 * p,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('x$combo', style: _T.comboBig),
                const SizedBox(width: 6),
                const Text('COMBO ⚡', style: _T.comboSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlusPop extends StatelessWidget {
  final AnimationController pulse;

  const _PlusPop({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.15),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final p = pulse.value;
          return Opacity(
            opacity: 0.6 + 0.4 * p,
            child: Transform.scale(
              scale: 1.0 + 0.15 * p,
              child: const Text('+100', style: _T.plus),
            ),
          );
        },
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final int score;
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const _PauseOverlay({
    required this.score,
    required this.onResume,
    required this.onQuit,
  });

  String get _formattedScore {
    final s = score.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: _C.comboA.withValues(alpha: 0.15),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _C.comboA.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pause, size: 18, color: _C.comboA),
                ),
                const SizedBox(height: 12),
                const Text('GAME PAUSED', style: _T.pauseTitle),
                const SizedBox(height: 6),
                const Text('Street rush on hold', style: _T.pauseHeading),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14122A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('CURRENT SCORE', style: _T.pauseScoreLabel),
                      const SizedBox(height: 4),
                      Text(_formattedScore, style: _T.pauseScore),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PrimaryBtn(label: 'RESUME GAME', onTap: onResume),
                const SizedBox(height: 8),
                _OutlineBtn(label: 'QUIT ROUND', onTap: onQuit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingInstruction extends StatelessWidget {
  const _TrackingInstruction({required this.status});

  final FaceGameControlStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FaceGameControlStatus.tracking => (
        'Move your face to aim · Open your mouth to catch',
        _C.mouthGreen,
      ),
      FaceGameControlStatus.temporarilyLost => (
        'Hold still — reacquiring your face',
        _C.timerGold,
      ),
      FaceGameControlStatus.lost => (
        'Tracking lost — target paused',
        _C.danger,
      ),
      FaceGameControlStatus.unavailable => (
        'Camera unavailable — gameplay paused',
        _C.danger,
      ),
      FaceGameControlStatus.paused => ('Tracking paused', _C.textSoft),
      FaceGameControlStatus.searching => (
        'Center your face to take control',
        _C.textSoft,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          label,
          key: ValueKey(status),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _DebugOverlay extends StatelessWidget {
  final MouthTrackingState trackingState;
  final CalibrationConfig config;

  const _DebugOverlay({required this.trackingState, required this.config});

  @override
  Widget build(BuildContext context) {
    final res = trackingState.latestResult;
    final transition = trackingState.latestTransition;
    final isOpen = transition.isOpen;

    return Positioned(
      left: 12,
      top: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOpen ? const Color(0xFF3DD68C) : const Color(0xFFFF7A1A),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DEBUG PIPELINE OVERLAY',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            _diagRow(
              'Face Present',
              res.faceDetected ? 'YES' : 'NO',
              res.faceDetected ? Colors.greenAccent : Colors.redAccent,
            ),
            _diagRow(
              'Raw Openness',
              trackingState.rawOpenness.toStringAsFixed(4),
              Colors.white,
            ),
            _diagRow(
              'Smoothed',
              transition.smoothedOpenness.toStringAsFixed(4),
              Colors.white,
            ),
            _diagRow(
              'Thresholds',
              'C: ${config.closedBaseline.toStringAsFixed(3)} | O: ${config.openThreshold.toStringAsFixed(3)}',
              Colors.white70,
            ),
            _diagRow(
              'Mouth State',
              isOpen ? "OPEN" : "CLOSED",
              isOpen ? const Color(0xFF3DD68C) : Colors.orangeAccent,
            ),
            _diagRow(
              'Detector FPS',
              '${trackingState.fps.toStringAsFixed(1)} FPS',
              Colors.cyanAccent,
            ),
            if (trackingState.lastEventTime != null)
              _diagRow(
                'Last Event',
                '${DateTime.now().difference(trackingState.lastEventTime!).inSeconds}s ago',
                Colors.yellowAccent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
