import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camera/camera.dart' show CameraController, CameraPreview;
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:muskaan_minigame/features/camera/domain/camera_state.dart';
import 'package:muskaan_minigame/features/face_detection/domain/face_detection_provider.dart';

// ==========================================
// THEME TOKENS  (unchanged)
// ==========================================
class AppColors {
  static const Color backgroundTop = Color(0xFF0D1A0D);
  static const Color backgroundBottom = Color(0xFF0A100A);
  static const Color dashGreen = Color(0xFF3CB371);
  static const Color dashYellow = Color(0x99FFD700);
  static const Color sheetBg = Color(0xFF1A1A2E);
  static const Color sheetTop = Color(0x001A1A2E);
  static const Color cardBg = Color(0xCC252542);
  static const Color cardLabel = Color(0xFFC9C3D8);
  static const Color readyGreen = Color(0xFF3CB371);
  static const Color checkingGold = Color(0xFFFFD700);
  static const Color helperGrey = Color(0xFF817995);
  static const Color progressTrack = Color(0x26FF6B35);
  static const Color progressStart = Color(0xFFFF6B35);
  static const Color progressEnd = Color(0xFFFFD700);
  static const Color scanLaser = Color(0xFF00FFA3);
  static const Color extractionCyan = Color(0xFF00E5FF);
}

class AppTypography {
  static const TextStyle faceDetected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.dashGreen,
    letterSpacing: 0.4,
  );
  static const TextStyle cardLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.cardLabel,
  );
  static const TextStyle statusReady = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.readyGreen,
  );
  static const TextStyle statusChecking = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.checkingGold,
  );
  static const TextStyle badgeText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.0,
  );
  static const TextStyle helper = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.helperGrey,
  );
}

class _Timings {
  static const Duration faceDetected = Duration(milliseconds: 600);
  static const Duration lightingReady = Duration(milliseconds: 1300);
  static const Duration startExtraction = Duration(milliseconds: 1500);
  static const Duration extractionDuration = Duration(milliseconds: 2600);
  static const Duration postCompletionHold = Duration(milliseconds: 400);
  static const Duration pulse = Duration(milliseconds: 1400);
  static const Duration scanner = Duration(milliseconds: 1800);
}

// ==========================================
// CALIBRATION SCREEN
// ==========================================
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──
  late final AnimationController _pulseController;
  late final AnimationController _scannerController;
  late final AnimationController _progressController;

  // ── Typed curves ──
  late final Animation<double> _pulseCurve;
  late final Animation<double> _progressAnimation;

  // ── Sequential status flags ──
  final _faceReady = ValueNotifier<bool>(false);
  final _lightingReady = ValueNotifier<bool>(false);
  final _biometricReady = ValueNotifier<bool>(false);

  // ── Sequence state ──
  bool _sequenceStarted = false;

  // ── Timers ──
  Timer? _stepFace;
  Timer? _stepLighting;
  Timer? _stepBiometric;
  Timer? _navTimer;

  // ── Lifecycle observer ──
  // Tracks whether the app is currently foreground. The nav timer
  // only navigates when this is true; if the timer fires in the
  // background, we defer navigation until the next resume.
  late final AppLifecycleListener _lifecycle;
  bool _isForeground = true;
  bool _pendingNavigation = false;

  static const double _outerW = 160;
  static const double _outerH = 208;
  static const double _innerW = 96;
  static const double _innerH = 64;

  FaceDetectionController? _faceDetectionController;

  @override
  void initState() {
    super.initState();

    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: _Timings.pulse,
    );
    _pulseCurve = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseController.repeat(reverse: true);

    _scannerController = AnimationController(
      vsync: this,
      duration: _Timings.scanner,
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: _Timings.extractionDuration,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    // If initial tracking state is already ready, start sequence
    final initialDetectionState = ref.read(faceDetectionProvider);
    if (initialDetectionState.isFaceDetected) {
      _startCalibrationSequence();
    }

    // Start real camera tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _faceDetectionController = ref.read(faceDetectionProvider.notifier);
        _faceDetectionController?.start();
      }
    });
  }

  void _onLifecycleChange(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _faceDetectionController?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _faceDetectionController?.start();
    }

    // If we deferred a navigation while backgrounded, run it now.
    if (_isForeground && _pendingNavigation) {
      _pendingNavigation = false;
      _navigateAway();
    }
  }

  void _navigateAway() {
    if (!mounted || !context.mounted) return;
    context.go('/home-first-time');
  }

  void _cancelCalibrationSequence() {
    _sequenceStarted = false;
    _stepFace?.cancel();
    _stepLighting?.cancel();
    _stepBiometric?.cancel();
    _navTimer?.cancel();
    _stepFace = null;
    _stepLighting = null;
    _stepBiometric = null;
    _navTimer = null;
    _progressController.reset();
    _faceReady.value = false;
    _lightingReady.value = false;
    _biometricReady.value = false;
  }

  void _startCalibrationSequence() {
    if (_sequenceStarted) return;
    _sequenceStarted = true;

    _stepFace = Timer(_Timings.faceDetected, () {
      if (!mounted) return;
      _faceReady.value = true;
    });

    _stepLighting = Timer(_Timings.lightingReady, () {
      if (!mounted) return;
      _lightingReady.value = true;
    });

    _stepBiometric = Timer(_Timings.startExtraction, () {
      if (!mounted) return;

      _progressController.forward().whenCompleteOrCancel(() {
        if (!mounted) return;
        _biometricReady.value = true;

        // Freeze continuous loops — the screen is done.
        _pulseController.stop();
        _scannerController.stop();

        _navTimer = Timer(_Timings.postCompletionHold, () {
          if (!mounted) return;

          // 🟢 FIX: Direct navigation. No `addPostFrameCallback` —
          // that API does not schedule a frame, so it silently hangs
          // when every animation on the screen has been stopped.
          // `context.go` schedules its own frame, guaranteeing the
          // router transition is rendered on the next tick.
          if (_isForeground) {
            _navigateAway();
          } else {
            // Timer fired while backgrounded — defer until resumed.
            _pendingNavigation = true;
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _stepFace?.cancel();
    _stepLighting?.cancel();
    _stepBiometric?.cancel();
    _navTimer?.cancel();

    _progressController.dispose();
    _scannerController.dispose();
    _pulseController.dispose();

    _faceReady.dispose();
    _lightingReady.dispose();
    _biometricReady.dispose();

    _lifecycle.dispose();

    // Stop the camera stream when leaving calibration. The provider performs
    // detector teardown once the screen no longer watches it.
    _faceDetectionController?.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final detectionState = ref.watch(faceDetectionProvider);

    // Listen to camera status changes to drive calibration sequence
    ref.listen<FaceDetectionState>(faceDetectionProvider, (previous, next) {
      if (next.hasCameraError || next.status == FaceDetectionStatus.error) {
        _cancelCalibrationSequence();
      } else if (next.isFaceDetected && !_sequenceStarted) {
        _startCalibrationSequence();
      } else if (!next.isFaceDetected && _sequenceStarted) {
        _cancelCalibrationSequence();
      }
    });

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
        child: Stack(
          children: [
            // Top back/exit navigation
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Semantics(
                  label: 'Exit calibration',
                  button: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        try {
                          if (context.canPop()) {
                            context.pop();
                            return;
                          }
                        } catch (_) {}
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          try {
                            context.go('/home');
                          } catch (_) {}
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: const Alignment(0, -0.2),
                child: RepaintBoundary(
                  child: _BiometricTrackingArea(
                    pulse: _pulseCurve,
                    scanner: _scannerController,
                    outerW: _outerW,
                    outerH: _outerH,
                    innerW: _innerW,
                    innerH: _innerH,
                    detectionState: detectionState,
                    onRetry: () => _faceDetectionController?.retry(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomSheet(
                bottomInset: bottomInset,
                faceReady: _faceReady,
                lightingReady: _lightingReady,
                biometricReady: _biometricReady,
                progress: _progressAnimation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Everything below this line is UNCHANGED
// (widgets: _BottomSheet, _StatusCard, _ProgressBar,
//  _LaserSweepPainter, _ScanningReticlePainter, _DashedOvalPainter)
// ==========================================

// ==========================================
// BIOMETRIC TRACKING AREA (extracted widget)
// ==========================================
class _BiometricTrackingArea extends StatelessWidget {
  final Animation<double> pulse;
  final AnimationController scanner;
  final double outerW;
  final double outerH;
  final double innerW;
  final double innerH;
  final FaceDetectionState detectionState;
  final VoidCallback onRetry;

  const _BiometricTrackingArea({
    required this.pulse,
    required this.scanner,
    required this.outerW,
    required this.outerH,
    required this.innerW,
    required this.innerH,
    required this.detectionState,
    required this.onRetry,
  });

  Widget _buildCameraFeedOrDiagnostic() {
    final status = detectionState.cameraStatus;
    final controller = detectionState.cameraController;

    if (detectionState.status == FaceDetectionStatus.error &&
        !detectionState.hasCameraError) {
      final errorMsg = detectionState.error ?? 'Face detection failed.';
      return Semantics(
        label: 'Face Detection Error: $errorMsg',
        container: true,
        child: Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face_retouching_off, color: Colors.redAccent),
              const SizedBox(height: 6),
              const Text(
                'Face Detection Error',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                errorMsg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.helperGrey,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (detectionState.isCameraReady &&
        controller is CameraController &&
        controller.value.isInitialized) {
      return Semantics(
        label: 'Live front camera preview',
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: (controller.value.previewSize?.height ?? outerW).toDouble(),
            height: (controller.value.previewSize?.width ?? outerH).toDouble(),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }

    if (status == CameraStatus.permissionDenied) {
      return Semantics(
        label:
            'Camera Permission Denied: Allow camera access for mouth tracking.',
        container: true,
        child: Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: AppColors.progressStart,
                  size: 28,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Camera Permission Denied',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Allow camera access for mouth tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.helperGrey, fontSize: 9),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Grant camera access',
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.progressStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: const Size(60, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Grant Access',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

    if (status == CameraStatus.permissionPermanentlyDenied) {
      return Semantics(
        label:
            'Camera Access Required: Permission permanently denied. Enable in App Settings.',
        container: true,
        child: Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings_outlined,
                  color: AppColors.checkingGold,
                  size: 28,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Camera Access Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Permission permanently denied. Enable in App Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.helperGrey, fontSize: 9),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Open App Settings',
                  child: ElevatedButton(
                    onPressed: openAppSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dashGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: const Size(60, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Open Settings',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

    if (status == CameraStatus.noFrontCamera) {
      return Semantics(
        label: 'No Front Camera: A front camera is required for gameplay.',
        container: true,
        child: Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.no_photography_rounded,
                  color: AppColors.progressStart,
                  size: 28,
                ),
                SizedBox(height: 4),
                Text(
                  'No Front Camera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'A front camera is required for gameplay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.helperGrey, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (status == CameraStatus.failed) {
      final errorMsg = detectionState.error ?? 'Failed to initialize camera.';
      return Semantics(
        label: 'Camera Error: $errorMsg',
        container: true,
        child: Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Camera Error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  errorMsg,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.helperGrey,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Retry camera initialization',
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.progressStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: const Size(60, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

    return Semantics(
      label: 'Initializing camera feed',
      container: true,
      child: Container(
        color: AppColors.backgroundTop,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.dashGreen),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Initializing camera...',
                style: TextStyle(color: AppColors.helperGrey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labelHeight = 20.0;
    const labelGap = 12.0;
    const margin = 40.0;

    return SizedBox(
      width: outerW + margin,
      height: outerH + labelGap + labelHeight + margin,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // ── "✓ Face Detected" or "Position Your Face" label ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, child) =>
                  Opacity(opacity: 0.7 + 0.3 * pulse.value, child: child),
              child: Text(
                detectionState.hasMultipleFaces
                    ? 'Multiple Faces Detected'
                    : detectionState.isFaceDetected
                    ? '✓ Face Detected'
                    : 'Position Your Face',
                textAlign: TextAlign.center,
                style: detectionState.isFaceDetected
                    ? AppTypography.faceDetected
                    : AppTypography.cardLabel,
              ),
            ),
          ),

          // ── Central scanner stage ──
          Positioned(
            top: labelGap + labelHeight,
            child: SizedBox(
              width: outerW,
              height: outerH,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Mirrored live camera feed or diagnostic placeholder clipped to oval
                  ClipOval(
                    child: SizedBox(
                      width: outerW,
                      height: outerH,
                      child: _buildCameraFeedOrDiagnostic(),
                    ),
                  ),

                  // Outer oval — scale + glow pulse
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (context, child) {
                      final p = pulse.value;
                      return Transform.scale(
                        scale: 1.0 + 0.03 * p,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(outerW / 2, outerH / 2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashGreen.withValues(
                                  alpha: 0.25 + 0.25 * p,
                                ),
                                blurRadius: 20 + 14 * p,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: CustomPaint(
                      size: Size(outerW, outerH),
                      painter: const _DashedOvalPainter(
                        color: AppColors.dashGreen,
                        strokeWidth: 2,
                        dashLength: 8,
                        gapLength: 6,
                      ),
                    ),
                  ),

                  // Tech corner reticles
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _ScanningReticlePainter(
                        color: AppColors.extractionCyan,
                      ),
                    ),
                  ),

                  // Laser sweep (clipped to oval)
                  Positioned.fill(
                    child: ClipOval(
                      child: AnimatedBuilder(
                        animation: scanner,
                        builder: (context, _) => CustomPaint(
                          painter: _LaserSweepPainter(
                            progress: scanner.value,
                            laserColor: AppColors.scanLaser,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Inner target oval (mouth / jaw zone)
                  CustomPaint(
                    size: Size(innerW, innerH),
                    painter: const _DashedOvalPainter(
                      color: AppColors.dashYellow,
                      strokeWidth: 2,
                      dashLength: 6,
                      gapLength: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BOTTOM SHEET (extracted widget)
// ==========================================
class _BottomSheet extends StatelessWidget {
  final double bottomInset;
  final ValueListenable<bool> faceReady;
  final ValueListenable<bool> lightingReady;
  final ValueListenable<bool> biometricReady;
  final Animation<double> progress;

  const _BottomSheet({
    required this.bottomInset,
    required this.faceReady,
    required this.lightingReady,
    required this.biometricReady,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sheetTop, AppColors.sheetBg],
          stops: [0.0, 0.40],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 48, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Each card listens to its own notifier — only THAT card
          // rebuilds when its state flips.
          ValueListenableBuilder<bool>(
            valueListenable: faceReady,
            builder: (_, ready, _) =>
                _StatusCard(label: 'Face Position', isReady: ready),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: lightingReady,
            builder: (_, ready, _) =>
                _StatusCard(label: 'Lighting', isReady: ready),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: biometricReady,
            builder: (_, ready, _) =>
                _StatusCard(label: 'Biometric Features', isReady: ready),
          ),
          const SizedBox(height: 16),

          // Progress bar (isolated repaint)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => _ProgressBar(progress: progress.value),
            ),
          ),
          const SizedBox(height: 8),

          // Progress label (isolated)
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final pct = (progress.value * 100).toInt();
              return Text(
                progress.value >= 1.0
                    ? 'Extraction complete!'
                    : 'Extracting landmarks ($pct%)...',
                style: AppTypography.helper,
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STATUS CARD (extracted, pure widget)
// ==========================================
class _StatusCard extends StatelessWidget {
  final String label;
  final bool isReady;

  const _StatusCard({required this.label, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReady
              ? AppColors.readyGreen.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isReady ? AppColors.readyGreen : AppColors.progressStart,
              shape: BoxShape.circle,
            ),
            child: Text(isReady ? '✓' : '…', style: AppTypography.badgeText),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTypography.cardLabel)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              isReady ? 'Ready' : 'Analyzing…',
              key: ValueKey<bool>(isReady),
              style: isReady
                  ? AppTypography.statusReady
                  : AppTypography.statusChecking,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PROGRESS BAR
// ==========================================
class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.progressTrack,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [AppColors.progressStart, AppColors.progressEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.progressStart.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// LASER SWEEP PAINTER
// ==========================================
class _LaserSweepPainter extends CustomPainter {
  final double progress;
  final Color laserColor;

  const _LaserSweepPainter({required this.progress, required this.laserColor});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // Trail behind the leading edge
    final trailRect = Rect.fromLTWH(0, math.max(0, y - 35), size.width, 35);
    canvas.drawRect(
      trailRect,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            laserColor.withValues(alpha: 0.0),
            laserColor.withValues(alpha: 0.25),
          ],
        ).createShader(trailRect),
    );

    // Bright leading line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..isAntiAlias = true
        ..color = laserColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LaserSweepPainter old) =>
      old.progress != progress || old.laserColor != laserColor;
}

// ==========================================
// RETICLE / HUD BRACKETS PAINTER
// ==========================================
class _ScanningReticlePainter extends CustomPainter {
  final Color color;
  const _ScanningReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const corner = 14.0;
    const pad = -8.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(pad, pad + corner)
        ..lineTo(pad, pad)
        ..lineTo(pad + corner, pad),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - corner, pad)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad, pad + corner),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(pad, size.height - pad - corner)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad + corner, size.height - pad),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - corner, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanningReticlePainter old) => false;
}

// ==========================================
// DASHED OVAL PAINTER
// ==========================================
class _DashedOvalPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const _DashedOvalPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()..addOval(rect);

    canvas.drawPath(
      _dashPath(path),
      Paint()
        ..isAntiAlias = true
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  Path _dashPath(Path source) {
    final dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dashLength, metric.length);
        dest.addPath(metric.extractPath(d, end), Offset.zero);
        d += dashLength + gapLength;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedOvalPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
