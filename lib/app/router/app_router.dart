import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muskaan_minigame/core/providers/game_session_provider.dart';

// ────────────────────────────────────────────────────────────
// 01 – 05   Onboarding
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/splash/presentation/screens/splash_screen.dart';
import 'package:muskaan_minigame/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:muskaan_minigame/features/onboarding/presentation/screens/how_to_play_step1_screen.dart';
import 'package:muskaan_minigame/features/onboarding/presentation/screens/how_to_play_step2_screen.dart';
import 'package:muskaan_minigame/features/onboarding/presentation/screens/how_to_play_step3_screen.dart';

// ────────────────────────────────────────────────────────────
// 06 – 08   Camera + Calibration
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/permissions/presentation/screens/camera_permission_screen.dart';
import 'package:muskaan_minigame/features/permissions/presentation/screens/camera_denied_screen.dart';
import 'package:muskaan_minigame/features/calibration/presentation/screens/calibration_screen.dart';

// ────────────────────────────────────────────────────────────
// 09 – 12   Home, Mode Select, Countdown
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/home/presentation/screens/home_screen.dart';
import 'package:muskaan_minigame/features/home/presentation/screens/home_first_time_screen.dart';
import 'package:muskaan_minigame/features/mode_select/presentation/screens/mode_select_screen.dart';
import 'package:muskaan_minigame/features/countdown/presentation/screens/countdown_screen.dart';

// ────────────────────────────────────────────────────────────
// 13 – 15   Gameplay, Pause, Game Over
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/game/presentation/screen/gameplay_screen.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/pause_overlay_screen.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/game_over_screen.dart';

// ────────────────────────────────────────────────────────────
// 16 – 17   Results, Share
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/results/presentation/screens/results_screen.dart';
import 'package:muskaan_minigame/features/share/presentation/screens/share_sheet_screen.dart';

// ────────────────────────────────────────────────────────────
// 18 – 20   Smile, Challenges, Profile
// ────────────────────────────────────────────────────────────
import 'package:muskaan_minigame/features/smile/presentation/screens/smile_spotlight_screen.dart';
import 'package:muskaan_minigame/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:muskaan_minigame/features/challenges/presentation/screens/challenge_detail_screen.dart';
import 'package:muskaan_minigame/features/profile/presentation/screens/profile_screen.dart';
import 'package:muskaan_minigame/features/settings/presentation/screens/settings_screen.dart';

// ============================================================
// PlaceholderScreen — used for unbuilt destinations
// ============================================================
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1525),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          '$title\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

// ============================================================
// Router
// ============================================================
GoRouter createRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // ───── 01 – 05  Onboarding ─────
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/how-to-play/step1',
        builder: (_, _) => const HowToPlayStep1Screen(),
      ),
      GoRoute(
        path: '/how-to-play/step2',
        builder: (_, _) => const HowToPlayStep2Screen(),
      ),
      GoRoute(
        path: '/how-to-play/step3',
        builder: (_, _) => const HowToPlayStep3Screen(),
      ),

      // ───── 06 – 08  Camera + Calibration ─────
      GoRoute(
        path: '/camera-permission',
        builder: (_, _) => const CameraPermissionScreen(),
      ),
      GoRoute(
        path: '/camera-denied',
        builder: (_, _) => const CameraDeniedScreen(),
      ),
      GoRoute(
        path: '/calibration',
        builder: (_, _) => const CalibrationScreen(),
      ),

      // ───── 09 – 12  Home, Mode Select, Countdown ─────
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/home-first-time',
        builder: (_, _) => const HomeFirstTimeScreen(),
      ),
      GoRoute(
        path: '/mode-select',
        builder: (_, _) => const ModeSelectScreen(),
      ),
      GoRoute(path: '/countdown', builder: (_, _) => const CountdownScreen()),

      // ───── 13 – 15  Gameplay, Pause, Game Over ─────
      GoRoute(path: '/game', builder: (_, _) => const GameplayScreen()),
      GoRoute(path: '/pause', builder: (_, _) => const PauseOverlayScreen()),
      GoRoute(
        path: '/game-over',
        builder: (_, _) => const _GameOverRouteBridge(),
      ),

      // ───── 16 – 17  Results, Share ─────
      GoRoute(path: '/results', builder: (_, _) => const _ResultsRouteBridge()),
      GoRoute(path: '/share', builder: (_, _) => const ShareSheetScreen()),

      // ───── 18  Smile Spotlight ─────
      GoRoute(
        path: '/filmi-smile',
        builder: (_, _) => const SmileSpotlightScreen(),
      ),

      // ───── 19 – 20  Challenges ─────
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesScreen()),
      GoRoute(
        path: '/challenge-detail',
        builder: (_, _) => const ChallengeDetailScreen(),
      ),

      // ───── Bottom-nav destinations ─────
      GoRoute(path: '/games', builder: (_, _) => const GameplayScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
}

// ============================================================
// Bridge widgets
// ============================================================

/// Reads the current game session and renders Game Over with real data.
class _GameOverRouteBridge extends ConsumerWidget {
  const _GameOverRouteBridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    return GameOverScreen(
      nextRoute: '/results',
      gameRecord: session.getGameResults(),
    );
  }
}

/// Reads the current game session and renders Results with real data.
class _ResultsRouteBridge extends ConsumerWidget {
  const _ResultsRouteBridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    return Stack(
      children: [
        ResultsScreen(gameRecord: session.getGameResults()),
        if (session.isSaving || session.saveError != null)
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              child: Material(
                color: const Color(0xFF252542),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.isSaving
                              ? 'Saving your result…'
                              : 'Your result could not be saved.',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (session.saveError != null)
                        TextButton(
                          onPressed:
                              () =>
                                  ref
                                      .read(gameSessionProvider.notifier)
                                      .persistCompletedSession(),
                          child: const Text('Retry save'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Global router used by `main.dart`.
final GoRouter appRouter = createRouter();
