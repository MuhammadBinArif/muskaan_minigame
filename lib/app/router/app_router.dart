import 'package:flutter/material.dart';
import '../../features/game/domain/play_mode.dart';
import '../../features/profile/presentation/screens/player_setup_screen.dart';
import '../../features/profile/presentation/screens/local_leaderboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';

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
import 'package:muskaan_minigame/features/smile/presentation/screens/smile_analytics_screen.dart';
import 'package:muskaan_minigame/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:muskaan_minigame/features/profile/presentation/screens/profile_screen.dart';
import 'package:muskaan_minigame/features/settings/presentation/screens/settings_screen.dart';
import 'package:muskaan_minigame/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:muskaan_minigame/features/progression/presentation/screens/player_progress_screen.dart';

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
      GoRoute(
        path: '/player-setup',
        builder: (_, _) => const PlayerSetupScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (_, _) => const LocalLeaderboardScreen(),
      ),
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
      GoRoute(
        path: '/game',
        builder:
            (_, state) => Consumer(
              builder:
                  (_, ref, _) => GameplayScreen(
                    key: ValueKey(state.uri.toString()),
                    touchOnly:
                        state.uri.queryParameters['touch'] == 'true' ||
                        (state.uri.queryParameters['touch'] == null &&
                            ref.read(touchOnlyModeProvider)),
                  ),
            ),
      ),
      GoRoute(path: '/pause', builder: (_, _) => const PauseOverlayScreen()),
      GoRoute(
        path: '/game-over',
        builder: (_, _) => const _GameOverRouteBridge(),
      ),

      // ───── 16 – 17  Results, Share ─────
      GoRoute(
        path: '/results',
        builder:
            (_, state) => _ResultsRouteBridge(
              resultId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
            ),
      ),
      GoRoute(
        path: '/share',
        builder: (_, state) {
          final record = state.extra;
          return record is GameSessionRecord
              ? ShareSheetScreen(
                score: record.score,
                isNewBest: record.isNewBest,
                combo: 'x${record.bestCombo}',
                resultId: record.id,
              )
              : const ShareSheetScreen();
        },
      ),

      // ───── 18  Smile Spotlight ─────
      GoRoute(
        path: '/filmi-smile',
        builder: (_, _) => const SmileSpotlightScreen(),
      ),
      GoRoute(
        path: '/smile-analytics',
        builder: (_, _) => const SmileAnalyticsScreen(),
      ),

      // ───── 19 – 20  Challenges ─────
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesScreen()),
      GoRoute(path: '/challenge-detail', redirect: (_, _) => '/challenges'),

      // ───── Bottom-nav destinations ─────
      GoRoute(path: '/games', builder: (_, _) => const GameplayScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/achievements',
        builder: (_, _) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/player-progress',
        builder: (_, _) => const PlayerProgressScreen(),
      ),
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
    final resultId = session.completedRecord?.id;
    return GameOverScreen(
      nextRoute: resultId == null ? '/results' : '/results?id=$resultId',
      gameRecord: session.completedRecord,
    );
  }
}

/// Resolves a completed result by ID and verifies ownership before rendering it.
class _ResultsRouteBridge extends ConsumerWidget {
  const _ResultsRouteBridge({required this.resultId});

  final int? resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = resultId;
    if (id == null || id <= 0) return const _ResultUnavailable();

    final session = ref.watch(gameSessionProvider);
    final profile = ref.watch(playerProfileProvider);
    final activePlayer = profile.asData?.value;
    if (profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (activePlayer == null) return const _ResultUnavailable();

    final pending = session.completedRecord;
    if ((session.isSaving || session.saveError != null) &&
        pending != null &&
        pending.id == id &&
        _isOwnedCompletion(pending, activePlayer.id)) {
      return _resultWithSaveStatus(ref, session, pending);
    }

    final persisted = ref.watch(resultByIdProvider(id));
    return persisted.when(
      loading:
          () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
      error: (_, _) => const _ResultUnavailable(),
      data:
          (record) =>
              record != null && _isOwnedCompletion(record, activePlayer.id)
                  ? ResultsScreen(gameRecord: record)
                  : const _ResultUnavailable(),
    );
  }

  static bool _isOwnedCompletion(GameSessionRecord record, String playerId) =>
      record.playerId == playerId &&
      record.state == GameSessionState.results &&
      record.endedAt != null;

  static Widget _resultWithSaveStatus(
    WidgetRef ref,
    GameSessionStateData session,
    GameSessionRecord record,
  ) {
    return Stack(
      children: [
        ResultsScreen(gameRecord: record),
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

class _ResultUnavailable extends StatelessWidget {
  const _ResultUnavailable();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('result-unavailable'),
    backgroundColor: const Color(0xFF0D0D1A),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Result unavailable',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
              const SizedBox(height: 8),
              const Text(
                'This result is missing, incomplete, or belongs to another player.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('GO HOME'),
              ),
              TextButton(
                onPressed: () => context.go('/smile-analytics'),
                child: const Text('VIEW HISTORY'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Global router used by `main.dart`.
final GoRouter appRouter = createRouter();
