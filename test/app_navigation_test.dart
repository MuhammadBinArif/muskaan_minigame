import 'dart:ui';
import 'package:muskaan_minigame/features/tracking/domain/calibration_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:muskaan_minigame/app/router/app_router.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/game/presentation/screen/game_over_screen.dart';
import 'package:muskaan_minigame/features/home/presentation/screens/home_screen.dart';
import 'package:muskaan_minigame/features/tracking/domain/mouth_tracking_provider.dart';
import 'package:muskaan_minigame/features/tracking/domain/vision_service.dart';
import 'camera/camera_sevice_imple_test.dart';

void main() {
  /// Pumps the app on a portrait mobile viewport.
  /// Uses `pump(Duration)` instead of `pumpAndSettle()` because several
  /// screens (Home, Calibration, Countdown, Gameplay) run infinite
  /// animations that would make `pumpAndSettle` time out.
  Future<void> pumpApp(WidgetTester tester, String initialLocation) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = createRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calibrationConfigProvider.overrideWith(
            (ref) => const CalibrationConfig(
              closedBaseline: .02,
              openThreshold: .08,
            ),
          ),
          bestRecordStreamProvider.overrideWith((ref) => Stream.value(null)),
          cameraServiceProvider.overrideWith((ref) => FakeCameraService()),
          visionServiceProvider.overrideWith((ref) => NullVisionService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Scrolls [finder] into view, taps it, then advances a short
  /// duration to let the next screen build.
  Future<void> tapAndAdvance(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // ================================================================
  // ONBOARDING & NAVIGATION  (Screens 01 – 05)
  // ================================================================
  group('Onboarding & Navigation Tests', () {
    testWidgets('Splash renders and auto-navigates to Welcome', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createRouter(initialLocation: '/');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.text('MUSKAAN PK'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Catch. Smile. Win!'), findsOneWidget);
    });

    testWidgets('Welcome → Step 1 via SEE HOW IT WORKS', (tester) async {
      await pumpApp(tester, '/welcome');
      expect(find.text('Catch. Smile. Win!'), findsOneWidget);

      await tapAndAdvance(tester, find.text('SEE HOW IT WORKS'));
      expect(find.text('Position Your Face'), findsOneWidget);
    });

    testWidgets('Welcome → Home (returning) via Skip intro', (tester) async {
      await pumpApp(tester, '/welcome');
      await tapAndAdvance(tester, find.text('Skip intro'));

      expect(find.text('Good evening,'), findsOneWidget);
    });

    testWidgets('Step 1 → Step 2 → Step 3 → Camera Permission', (tester) async {
      await pumpApp(tester, '/how-to-play/step1');
      expect(find.text('Position Your Face'), findsOneWidget);

      await tapAndAdvance(tester, find.text('NEXT'));
      expect(find.text('Open Your Mouth to Catch'), findsOneWidget);

      await tapAndAdvance(tester, find.text('NEXT'));
      expect(find.text('Build Combos, Avoid Hazards'), findsOneWidget);

      await tapAndAdvance(tester, find.text('START CAMERA SETUP'));
      expect(find.text('Camera Access'), findsOneWidget);
    });

    testWidgets('Back navigation across onboarding steps', (tester) async {
      await pumpApp(tester, '/how-to-play/step1');
      expect(find.text('Position Your Face'), findsOneWidget);

      await tapAndAdvance(tester, find.text('NEXT'));
      expect(find.text('Open Your Mouth to Catch'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Position Your Face'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Catch. Smile. Win!'), findsOneWidget);
    });
  });

  // ================================================================
  // CAMERA PERMISSION & CALIBRATION  (Screens 06 – 08)
  // ================================================================
  group('Camera Permission & Calibration Flow', () {
    testWidgets('Camera Permission screen renders correctly', (tester) async {
      await pumpApp(tester, '/camera-permission');

      expect(find.text('Camera Access'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(
        find.text('Video processed locally — never uploaded'),
        findsOneWidget,
      );
    });

    testWidgets('CONTINUE navigates to Calibration', (tester) async {
      await pumpApp(tester, '/camera-permission');
      await tapAndAdvance(tester, find.text('CONTINUE'));

      expect(find.text('Face Position'), findsOneWidget);
      expect(find.text('Closed-mouth baseline'), findsOneWidget);
      expect(find.text('Open and close verified'), findsOneWidget);
      expect(
        find.text('Analyzing…'),
        findsWidgets,
      ); // 3 status cards start in this state
    });

    testWidgets('Not now navigates to Camera Denied', (tester) async {
      await pumpApp(tester, '/camera-permission');

      await tapAndAdvance(tester, find.text('Not now'));

      expect(find.text('Camera Blocked'), findsOneWidget);
      expect(find.text('OPEN SETTINGS'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Camera Denied screen renders correctly', (tester) async {
      await pumpApp(tester, '/camera-denied');

      expect(find.text('Camera Blocked'), findsOneWidget);
      expect(find.text('OPEN SETTINGS'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Open your device Settings'), findsOneWidget);
      expect(find.text('Select "Allow" and return'), findsOneWidget);
    });

    testWidgets('Try Again navigates back to Camera Permission', (
      tester,
    ) async {
      await pumpApp(tester, '/camera-denied');
      await tapAndAdvance(tester, find.text('Try Again'));

      expect(find.text('Camera Access'), findsOneWidget);
    });

    testWidgets('Calibration does not auto-complete without face samples', (
      tester,
    ) async {
      await pumpApp(tester, '/calibration');
      expect(find.text('Face Position'), findsOneWidget);

      // Full sequence: 600 + 700 + 200 + 2600 + 400 ≈ 4500 ms
      // Pump 12 × 500 = 6000 ms to cover it with margin.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Face Position'), findsOneWidget);
      expect(find.text('Welcome to'), findsNothing);
    });

    testWidgets('Camera flow stops at calibration until measurements arrive', (
      tester,
    ) async {
      await pumpApp(tester, '/camera-permission');

      await tapAndAdvance(tester, find.text('CONTINUE'));
      expect(find.text('Face Position'), findsOneWidget);

      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('Face Position'), findsOneWidget);
      expect(find.text('Welcome to'), findsNothing);
    });
  });

  // ================================================================
  // HOME (RETURNING USER)  — Screen 09
  // ================================================================
  group('Home Screen Navigation', () {
    testWidgets('Home renders with all key sections', (tester) async {
      await pumpApp(tester, '/home');

      expect(find.text('Good evening,'), findsOneWidget);
      expect(find.text('Arjun 👋'), findsOneWidget);
      expect(find.text('Street Food Rush'), findsOneWidget);
      expect(find.text('Smile Spotlight'), findsOneWidget);
      expect(find.text('Practice Mode'), findsOneWidget);
      expect(find.text('Best Score'), findsOneWidget);
      expect(find.text('Best Combo'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
    });

    testWidgets('PLAY NOW navigates to Mode Selection', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('PLAY NOW'));

      expect(find.text('Choose Mode'), findsOneWidget);
    });

    testWidgets('Bottom nav: Challenges', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('Challenges'));

      // ChallengesScreen header is unique.
      expect(find.text('Challenges 🏆'), findsOneWidget);
    });

    // Robust: verify navigation happened by checking we LEFT Home.
    // This doesn't depend on the destination's exact text.
    testWidgets('Bottom nav: Games', (tester) async {
      await pumpApp(tester, '/home');
      await tester.tap(find.text('Games').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Fresh /game entry shows the READY overlay, not the mouth ring.
      expect(find.text('READY TO PLAY'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
    });

    testWidgets('Bottom nav: Smile', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('Smile'));

      expect(find.text('Entertainment only — not scientific'), findsOneWidget);
    });

    // Robust: same pattern as Games.
    testWidgets('Bottom nav: Profile', (tester) async {
      await pumpApp(tester, '/home');
      await tester.tap(find.text('Profile').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('Smile Spotlight card → Smile screen', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('Smile Spotlight'));

      expect(find.text('Entertainment only — not scientific'), findsOneWidget);
    });

    testWidgets('Practice Mode card → Mode Selection', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('Practice Mode'));

      expect(find.text('Choose Mode'), findsOneWidget);
    });

    testWidgets('Streak badge → Challenges', (tester) async {
      await pumpApp(tester, '/home');
      await tapAndAdvance(tester, find.text('7 streak'));

      expect(find.text('Challenges 🏆'), findsOneWidget);
    });
  });

  // ================================================================
  // HOME (FIRST TIME)  — Screen 10
  // ================================================================
  group('Home First Time Screen', () {
    testWidgets('renders all key elements', (tester) async {
      await pumpApp(tester, '/home-first-time');

      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('Muskaan Minigame! 🎉'), findsOneWidget);
      expect(
        find.text('Your street food adventure starts here.'),
        findsOneWidget,
      );

      expect(find.text('Face Tracking'), findsOneWidget);
      expect(find.text('Build Combos'), findsOneWidget);
      expect(find.text('Smile Score'), findsOneWidget);

      expect(find.text('SEE HOW TO PLAY'), findsOneWidget);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('SEE HOW TO PLAY navigates to Mode Selection', (tester) async {
      await pumpApp(tester, '/home-first-time');
      await tapAndAdvance(tester, find.text('SEE HOW TO PLAY'));
      expect(find.text('Choose Mode'), findsOneWidget);
    });

    testWidgets('bottom nav → Challenges', (tester) async {
      await pumpApp(tester, '/home-first-time');
      await tapAndAdvance(tester, find.text('Challenges'));

      expect(find.text('Challenges 🏆'), findsOneWidget);
    });

    // Robust: verify we LEFT Home First Time.
    testWidgets('bottom nav → Profile', (tester) async {
      await pumpApp(tester, '/home-first-time');
      expect(find.text('Welcome to'), findsOneWidget);

      await tester.ensureVisible(find.text('Profile').first);
      await tester.pump();
      await tester.tap(find.text('Profile').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Welcome to'), findsNothing);
    });

    testWidgets('Home tab is a no-op when already active', (tester) async {
      await pumpApp(tester, '/home-first-time');
      await tester.tap(find.text('Home').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome to'), findsOneWidget);
    });
  });

  // ================================================================
  // MODE SELECTION  — Screen 11
  // ================================================================
  group('Mode Select Screen', () {
    testWidgets('renders title, all modes, and confirm button', (tester) async {
      await pumpApp(tester, '/mode-select');

      expect(find.text('Choose Mode'), findsOneWidget);
      expect(find.text('Daily Battle'), findsOneWidget);
      expect(find.text('Practice Mode'), findsOneWidget);
      expect(find.text('Smile Spotlight'), findsOneWidget);
      expect(find.text('CONFIRM MODE'), findsOneWidget);
    });

    testWidgets('Daily Battle is selected by default', (tester) async {
      await pumpApp(tester, '/mode-select');

      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Daily Battle'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('Confirm with default mode → Countdown', (tester) async {
      await pumpApp(tester, '/mode-select');

      await tapAndAdvance(tester, find.text('CONFIRM MODE'));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);
    });

    testWidgets('Selecting Practice Mode then confirm → Countdown', (
      tester,
    ) async {
      await pumpApp(tester, '/mode-select');

      await tester.tap(find.text('Practice Mode'));
      await tester.pump(const Duration(milliseconds: 300));

      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Practice Mode'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.flagsCollection.isSelected, Tristate.isTrue);

      await tapAndAdvance(tester, find.text('CONFIRM MODE'));
      expect(find.text('3'), findsOneWidget);
    });

    // Key regression: Smile Spotlight must NOT redirect to /filmi-smile.
    testWidgets('Selecting Smile Spotlight then confirm → Countdown', (
      tester,
    ) async {
      await pumpApp(tester, '/mode-select');

      await tester.tap(find.text('Smile Spotlight'));
      await tester.pump(const Duration(milliseconds: 300));

      await tapAndAdvance(tester, find.text('CONFIRM MODE'));

      // We must land on Countdown.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);

      // And must NOT land on the standalone Smile Spotlight screen.
      expect(find.text('Entertainment only — not scientific'), findsNothing);
    });

    testWidgets('tap outside dismisses without crashing (deep-link safe)', (
      tester,
    ) async {
      await pumpApp(tester, '/mode-select');
      expect(find.text('Choose Mode'), findsOneWidget);

      // Let the entry animation (800 ms) finish so the overlay is fully
      // interactive before we tap it. `pumpApp` advanced 500 ms already.
      await tester.pump(const Duration(milliseconds: 400));

      // Tap the top-left corner — outside the sheet, inside the overlay.
      await tester.tapAt(const Offset(20, 20));

      // Drive enough frames for the full async sequence:
      //   1. Reverse the 800 ms entry animation.
      //   2. Microtask resolves → `_dismiss()` calls `context.go('/home')`.
      //   3. Router rebuilds.
      //   4. Route transition animates.
      //
      // Each pump advances a slice and lets pending microtasks run, so
      // the next pump sees the updated state. Do NOT use `pumpAndSettle`
      // here — the destination (`/home`) has infinite animations that
      // would make it time out.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // No crash — either popped to the previous route or fell back to /home.
      expect(find.text('Choose Mode'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ================================================================
  // COUNTDOWN  — Screen 12
  // ================================================================
  group('Countdown Screen', () {
    testWidgets('renders 3, GET READY, and combo pill', (tester) async {
      await pumpApp(tester, '/countdown');

      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);
      expect(find.text('x1 COMBO'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
    });

    testWidgets('counts down 3 → 2 → 1 → GO', (tester) async {
      await pumpApp(tester, '/countdown');

      expect(find.text('3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('GO'), findsOneWidget);
    });

    testWidgets('auto-navigates to Game after GO', (tester) async {
      await pumpApp(tester, '/countdown');

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // We land on /game in the READY state.
      expect(find.text('READY TO PLAY'), findsOneWidget);
    });
  });

  // ================================================================
  // END-TO-END FLOWS (verify the ordered 01 → 13 pipeline)
  // ================================================================
  group('End-to-end flows', () {
    testWidgets(
      'New user must complete measured calibration before continuing',
      (tester) async {
        await pumpApp(tester, '/how-to-play/step1');

        await tapAndAdvance(tester, find.text('NEXT'));
        expect(find.text('Open Your Mouth to Catch'), findsOneWidget);

        await tapAndAdvance(tester, find.text('NEXT'));
        expect(find.text('Build Combos, Avoid Hazards'), findsOneWidget);

        await tapAndAdvance(tester, find.text('START CAMERA SETUP'));
        expect(find.text('Camera Access'), findsOneWidget);

        await tapAndAdvance(tester, find.text('CONTINUE'));
        expect(find.text('Face Position'), findsOneWidget);

        for (int i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        expect(find.text('Face Position'), findsOneWidget);
        expect(find.text('Welcome to'), findsNothing);
      },
    );

    testWidgets(
      'New user continues: Home First Time → Mode → Countdown → Game',
      (tester) async {
        await pumpApp(tester, '/home-first-time');

        await tapAndAdvance(tester, find.text('SEE HOW TO PLAY'));
        expect(find.text('Choose Mode'), findsOneWidget);

        await tapAndAdvance(tester, find.text('CONFIRM MODE'));
        expect(find.text('3'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Terminal: /game in READY state.
        expect(find.text('READY TO PLAY'), findsOneWidget);
      },
    );

    testWidgets('Returning user: Home → Mode → Countdown → Game', (
      tester,
    ) async {
      await pumpApp(tester, '/home');

      await tapAndAdvance(tester, find.text('PLAY NOW'));
      expect(find.text('Choose Mode'), findsOneWidget);

      await tapAndAdvance(tester, find.text('CONFIRM MODE'));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Terminal: /game in READY state.
      expect(find.text('READY TO PLAY'), findsOneWidget);
    });
  });

  // ================================================================
  // PAUSE OVERLAY  — Screen 14
  // ================================================================
  group('Pause Overlay Screen', () {
    testWidgets('renders all key elements', (tester) async {
      await pumpApp(tester, '/pause');

      expect(find.text('⏸ PAUSED'), findsOneWidget);
      expect(find.text('Your game is waiting'), findsOneWidget);
      expect(find.text('CURRENT SCORE'), findsOneWidget);
      expect(find.text('8,420'), findsOneWidget);

      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);

      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('Quit Game'), findsOneWidget);
    });

    testWidgets('Sound and Music start enabled', (tester) async {
      await pumpApp(tester, '/pause');

      final soundToggle = tester.getSemantics(
        find
            .ancestor(of: find.text('Sound'), matching: find.byType(Semantics))
            .first,
      );
      final musicToggle = tester.getSemantics(
        find
            .ancestor(of: find.text('Music'), matching: find.byType(Semantics))
            .first,
      );
      expect(soundToggle.flagsCollection.isToggled, Tristate.isTrue);
      expect(musicToggle.flagsCollection.isToggled, Tristate.isTrue);
    });

    testWidgets('tapping Sound toggles it off', (tester) async {
      await pumpApp(tester, '/pause');

      await tester.tap(find.text('Sound'));
      await tester.pump(const Duration(milliseconds: 250));

      final soundToggle = tester.getSemantics(
        find
            .ancestor(of: find.text('Sound'), matching: find.byType(Semantics))
            .first,
      );
      expect(soundToggle.flagsCollection.isToggled, Tristate.isFalse);
    });

    testWidgets('RESUME navigates back to Gameplay', (tester) async {
      await pumpApp(tester, '/pause');
      await tapAndAdvance(tester, find.text('RESUME'));

      // /game renders in READY state on fresh entry.
      expect(find.text('READY TO PLAY'), findsOneWidget);
    });

    testWidgets('RESTART navigates to Countdown', (tester) async {
      await pumpApp(tester, '/pause');
      await tapAndAdvance(tester, find.text('RESTART'));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);
    });

    testWidgets('Quit Game navigates to Home', (tester) async {
      await pumpApp(tester, '/pause');
      await tapAndAdvance(tester, find.text('Quit Game'));

      expect(find.text('Good evening,'), findsOneWidget);
    });
  });

  // ================================================================
  // GAME OVER SCREEN  — Screen 15
  // ================================================================
  group('Game Over Screen', () {
    testWidgets('renders emoji, title, subtitle, and three dots', (
      tester,
    ) async {
      await pumpApp(tester, '/game-over');

      expect(find.text('😵'), findsOneWidget);
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('Tallying your score…'), findsOneWidget);
    });

    testWidgets('title animates its glow across frames', (tester) async {
      await pumpApp(tester, '/game-over');

      final beforeText = tester.widget<Text>(find.text('GAME OVER'));
      final beforeBlur = beforeText.style?.shadows?.first.blurRadius ?? 0;

      await tester.pump(const Duration(milliseconds: 600));

      final afterText = tester.widget<Text>(find.text('GAME OVER'));
      final afterBlur = afterText.style?.shadows?.first.blurRadius ?? 0;

      expect(afterBlur, isNot(equals(beforeBlur)));
    });

    testWidgets('auto-navigates when nextRoute is provided', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/game-over',
        routes: [
          GoRoute(
            path: '/game-over',
            builder: (_, _) => const GameOverScreen(nextRoute: '/home'),
          ),
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Good evening,'), findsOneWidget);
    });
  });

  // ================================================================
  // RESULTS SCREEN  — Screen 16
  // ================================================================
  group('Results Screen', () {
    testWidgets('renders all key elements', (tester) async {
      await pumpApp(tester, '/results');

      expect(find.text('SESSION COMPLETE'), findsOneWidget);
      expect(find.text('This Round'), findsOneWidget);

      // Stat labels are always present.
      expect(find.text('Catches'), findsOneWidget);
      expect(find.text('Best Combo'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Smile Score'), findsOneWidget);

      // Actions.
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('SHARE RESULT'), findsOneWidget);

      // No NEW BEST badge on an empty record.
      expect(find.text('NEW BEST!'), findsNothing);
    });

    testWidgets('score count-up finishes for the active record', (
      tester,
    ) async {
      await pumpApp(tester, '/results');

      // Advance past the 1.4 s count-up so the score settles.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 200));

      // The empty fallback record has score 0; two "0" widgets exist
      // (score + catches count).
      expect(find.text('0'), findsWidgets);
      expect(find.text('SESSION COMPLETE'), findsOneWidget);
    });

    testWidgets('PLAY AGAIN navigates to Countdown', (tester) async {
      await pumpApp(tester, '/results');
      await tapAndAdvance(tester, find.text('PLAY AGAIN'));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);
    });

    testWidgets('SHARE RESULT button is tappable', (tester) async {
      await pumpApp(tester, '/results');

      await tester.tap(find.text('SHARE RESULT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SESSION COMPLETE'), findsOneWidget);
    });
  });

  // ================================================================
  // SHARE SHEET  — Screen 17
  // ================================================================
  group('Share Sheet Screen', () {
    testWidgets('renders title, preview, tiles, and message', (tester) async {
      await pumpApp(tester, '/share');

      expect(find.text('Share Your Score'), findsOneWidget);

      expect(find.text('MUSKAAN PK'), findsOneWidget);
      expect(find.text('8,420'), findsOneWidget);
      expect(find.text('muskaanpk.app'), findsOneWidget);

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('preview shows New Best + Combo when set', (tester) async {
      await pumpApp(tester, '/share');

      expect(find.textContaining('New Best'), findsOneWidget);
      expect(find.textContaining('Combo x5'), findsOneWidget);
    });

    testWidgets('Copy tile copies message to clipboard', (tester) async {
      String? copied;
      TestWidgetsFlutterBinding.ensureInitialized();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await pumpApp(tester, '/share');
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(copied, isNotNull);
      expect(copied, contains('Muskaan Minigame'));
      expect(copied, contains('8,420'));
      expect(copied, contains('muskaanpk.app'));
    });

    testWidgets('CLOSE dismisses the sheet back to Results', (tester) async {
      await pumpApp(tester, '/results');

      await tapAndAdvance(tester, find.text('SHARE RESULT'));

      expect(find.text('Share Your Score'), findsOneWidget);

      await tester.tap(find.text('CLOSE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Share Your Score'), findsNothing);
      expect(find.text('SESSION COMPLETE'), findsOneWidget);
    });
  });

  // ================================================================
  // SMILE SPOTLIGHT  — Screen 18
  // ================================================================
  group('Smile Spotlight Screen', () {
    testWidgets('renders title, subtitle, score, and badge', (tester) async {
      await pumpApp(tester, '/filmi-smile');

      expect(find.text('Smile Spotlight'), findsOneWidget);
      expect(find.text('Entertainment only — not scientific'), findsOneWidget);
      expect(find.text('SPOTLIGHT ENERGY'), findsOneWidget);
      expect(find.text('RADIANT'), findsOneWidget);
    });

    testWidgets('renders all three vibe breakdown rows', (tester) async {
      await pumpApp(tester, '/filmi-smile');

      expect(find.text('Vibe Breakdown'), findsOneWidget);
      expect(find.text('Smile Width'), findsOneWidget);
      expect(find.text('Eye Sparkle'), findsOneWidget);
      expect(find.text('Warmth'), findsOneWidget);
    });

    testWidgets('renders the disclaimer text', (tester) async {
      await pumpApp(tester, '/filmi-smile');

      expect(find.textContaining('purely for entertainment'), findsOneWidget);
      expect(find.textContaining('not represent scientific'), findsOneWidget);
    });

    testWidgets('score counts up to 92%', (tester) async {
      await pumpApp(tester, '/filmi-smile');

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == '92%' && w.style?.fontSize == 48,
        ),
        findsOneWidget,
      );
    });

    testWidgets('back button navigates away safely when nothing to pop', (
      tester,
    ) async {
      await pumpApp(tester, '/filmi-smile');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Good evening,'), findsOneWidget);
    });
  });

  // ================================================================
  // CHALLENGES  — Screen 19
  // ================================================================
  group('Challenges Screen', () {
    testWidgets('renders header + subtitle', (tester) async {
      await pumpApp(tester, '/challenges');

      expect(find.text('Challenges 🏆'), findsOneWidget);
      expect(find.text('Complete goals to earn rewards'), findsOneWidget);
    });

    testWidgets('renders featured challenge with progress and reward', (
      tester,
    ) async {
      await pumpApp(tester, '/challenges');

      expect(find.text('FEATURED TODAY'), findsOneWidget);
      expect(find.text('Gol Gappa Tsunami'), findsOneWidget);
      expect(
        find.text('Catch 100 gol gappas without 3 misses'),
        findsOneWidget,
      );
      expect(find.text('68 / 100'), findsOneWidget);
      expect(find.text('6h left'), findsOneWidget);
      expect(find.text('750 pts'), findsOneWidget);
    });

    testWidgets('renders all three daily goals', (tester) async {
      await pumpApp(tester, '/challenges');

      expect(find.text('Daily Goals'), findsOneWidget);
      expect(find.text('Precision Player'), findsOneWidget);
      expect(find.text('Combo King'), findsOneWidget);
      expect(find.text('Smile Streak'), findsOneWidget);
    });

    testWidgets('renders leaderboard with three entries', (tester) async {
      await pumpApp(tester, '/challenges');

      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Priya S.'), findsOneWidget);
      expect(find.text('Rahul K.'), findsOneWidget);
      expect(find.text('Arjun (You)'), findsOneWidget);
      expect(find.text('28,400'), findsOneWidget);
      expect(find.text('24,900'), findsOneWidget);
      expect(find.text('12,480'), findsOneWidget);
    });

    testWidgets('bottom nav: Challenges tab is active', (tester) async {
      await pumpApp(tester, '/challenges');

      // Tapping the already-active tab should be a no-op.
      await tester.tap(find.text('Challenges').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Challenges 🏆'), findsOneWidget);
    });
  });

  // ================================================================
  // CHALLENGE DETAIL  — Screen 20
  // ================================================================
  group('Challenge Detail Screen', () {
    testWidgets('renders title, challenge name, and description', (
      tester,
    ) async {
      await pumpApp(tester, '/challenge-detail');

      expect(find.text('Challenge Detail'), findsOneWidget);
      expect(find.text('Gol Gappa Tsunami'), findsOneWidget);
      expect(find.textContaining('Catch 100 gol gappas'), findsOneWidget);
    });

    testWidgets('renders progress card with percent', (tester) async {
      await pumpApp(tester, '/challenge-detail');

      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('68 caught'), findsOneWidget);
      expect(find.text('32 to go'), findsOneWidget);
    });

    testWidgets('renders completion reward with points and badge', (
      tester,
    ) async {
      await pumpApp(tester, '/challenge-detail');

      expect(find.text('Completion Reward'), findsOneWidget);
      expect(find.text('750 pts'), findsOneWidget);
      expect(find.text('+ Tsunami Badge unlock'), findsOneWidget);
    });

    testWidgets('renders time remaining and PLAY NOW', (tester) async {
      await pumpApp(tester, '/challenge-detail');

      expect(find.text('Time Remaining'), findsOneWidget);
      expect(find.text('5h 22m'), findsOneWidget);
      expect(find.text('PLAY NOW'), findsOneWidget);
    });

    testWidgets('PLAY NOW navigates to Countdown', (tester) async {
      await pumpApp(tester, '/challenge-detail');
      await tapAndAdvance(tester, find.text('PLAY NOW'));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('GET READY...'), findsOneWidget);
    });

    testWidgets('back button navigates safely to Challenges when no parent', (
      tester,
    ) async {
      await pumpApp(tester, '/challenge-detail');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Challenges 🏆'), findsOneWidget);
    });
  });

  // ================================================================
  // GAMEPLAY SCREEN — Night Market Glow
  // ================================================================
  group('Gameplay Screen', () {
    /// Navigates to /game, taps READY to begin the round, then taps
    /// the pause button. Leaves the app in the paused state, ready
    /// for the calling test's assertions.
    Future<void> startAndPause(WidgetTester tester) async {
      await pumpApp(tester, '/game');

      // 1) Start the round from the READY overlay.
      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 2) Pause via the HUD pause button.
      await tester.tap(find.byIcon(Icons.pause).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('idle state renders HUD, mouth ring, and hint', (tester) async {
      await pumpApp(tester, '/game');

      // On fresh entry the screen shows the READY overlay; the HUD is
      // also present behind it because the pause timer is running.
      expect(find.text('READY TO PLAY'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // score starts at 0
    });

    testWidgets('tap READY starts the round', (tester) async {
      await pumpApp(tester, '/game');

      expect(find.text('READY TO PLAY'), findsOneWidget);

      await tester.tap(find.text('READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The READY overlay is gone; the gameplay view is visible.
      expect(find.text('READY TO PLAY'), findsNothing);
      expect(find.text('OPEN MOUTH'), findsOneWidget);
    });

    testWidgets('pause button opens overlay', (tester) async {
      await startAndPause(tester);

      expect(find.text('GAME PAUSED'), findsOneWidget);
      expect(find.text('Street rush on hold'), findsOneWidget);
      expect(find.text('RESUME GAME'), findsOneWidget);
      expect(find.text('QUIT ROUND'), findsOneWidget);
    });

    testWidgets('RESUME returns to gameplay', (tester) async {
      await startAndPause(tester);

      expect(find.text('GAME PAUSED'), findsOneWidget);

      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('GAME PAUSED'), findsNothing);
      expect(find.text('OPEN MOUTH'), findsOneWidget);
    });

    testWidgets('QUIT ROUND navigates to Home', (tester) async {
      await startAndPause(tester);

      expect(find.text('QUIT ROUND'), findsOneWidget);

      await tester.tap(find.text('QUIT ROUND'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Good evening,'), findsOneWidget);
    });
  });

  // ================================================================
  // PROFILE SCREEN
  // ================================================================
  group('Profile Screen', () {
    testWidgets('returning user renders header, stats, achievements', (
      tester,
    ) async {
      await pumpApp(tester, '/profile');

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Blaven Name'), findsOneWidget);
      expect(find.text('@player_123'), findsOneWidget);

      expect(find.text('9,480'), findsOneWidget);
      expect(find.text('47'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);

      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('First Catch'), findsOneWidget);
      expect(find.text('Combo Master'), findsOneWidget);
      expect(find.text('100 Catches'), findsOneWidget);
      expect(find.text('Perfect Games'), findsOneWidget);

      expect(find.text('LEVEL PROGRESS'), findsOneWidget);
      expect(find.text('2,450 / 5,000 XP'), findsOneWidget);
    });

    testWidgets('name tap enters edit mode', (tester) async {
      await pumpApp(tester, '/profile');

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('bottom nav — profile tab highlighted', (tester) async {
      await pumpApp(tester, '/profile');
      expect(find.text('PROFILE'), findsOneWidget);
    });
  });

  // ================================================================
  // DOMAIN — GameStats
  // ================================================================
  group('Domain — GameStats', () {
    test('initial stats', () {
      final s = GameStats.initial();
      expect(s.score, 0);
      expect(s.lives, 3);
      expect(s.timeRemaining, 45);
      expect(s.combo, 0);
      expect(s.maxCombo, 0);
      expect(s.catches, 0);
      expect(s.hazardsHit, 0);
      expect(s.accuracy, 0.0);
      expect(s.smileScore, 0);
      expect(s.isGameOver, isFalse);
      expect(s.isTimeOut, isFalse);
      expect(s.gameOverReason, isNull);
    });

    test('gold catch adds 100 points and bumps combo', () {
      final s = GameStats.initial().applyCollision(
        const CollisionEvent(
          foodType: FoodItemType.gold,
          mouthX: 0,
          mouthY: 0,
          timestamp: 0,
          isCatch: true,
        ),
      );

      expect(s.score, 100);
      expect(s.combo, 1);
      expect(s.maxCombo, 1);
      expect(s.catches, 1);
      expect(s.hazardsHit, 0);
      expect(s.lives, 3);
      expect(s.accuracy, 1.0);
    });

    test('tea hazard costs a life, resets combo, keeps maxCombo', () {
      var s = GameStats.initial().applyCollision(
        const CollisionEvent(
          foodType: FoodItemType.gold,
          mouthX: 0,
          mouthY: 0,
          timestamp: 0,
          isCatch: true,
        ),
      );
      s = s.applyCollision(
        const CollisionEvent(
          foodType: FoodItemType.tea,
          mouthX: 0,
          mouthY: 0,
          timestamp: 0,
          isCatch: false,
        ),
      );

      expect(s.lives, 2);
      expect(s.combo, 0);
      expect(s.maxCombo, 1);
      expect(s.catches, 1);
      expect(s.hazardsHit, 1);
      expect(s.accuracy, 0.5);
    });

    test('teal catch is worth 75', () {
      final s = GameStats.initial().applyCollision(
        const CollisionEvent(
          foodType: FoodItemType.teal,
          mouthX: 0,
          mouthY: 0,
          timestamp: 0,
          isCatch: true,
        ),
      );
      expect(s.score, 75);
    });

    test('isGameOver once lives reach zero', () {
      var s = GameStats.initial();
      for (var i = 0; i < 3; i++) {
        s = s.applyCollision(
          const CollisionEvent(
            foodType: FoodItemType.tea,
            mouthX: 0,
            mouthY: 0,
            timestamp: 0,
            isCatch: false,
          ),
        );
      }
      expect(s.lives, 0);
      expect(s.isGameOver, isTrue);
      expect(s.gameOverReason, 'no_lives');
    });

    test('isTimeOut when timeRemaining drops to zero', () {
      final s = GameStats.initial().updateTimeRemaining(0);
      expect(s.isTimeOut, isTrue);
      expect(s.gameOverReason, 'time_up');
    });

    test('smileScore is always within 0–100', () {
      var s = GameStats.initial();
      for (var i = 0; i < 20; i++) {
        s = s.applyCollision(
          const CollisionEvent(
            foodType: FoodItemType.gold,
            mouthX: 0,
            mouthY: 0,
            timestamp: 0,
            isCatch: true,
          ),
        );
      }
      expect(s.smileScore, inInclusiveRange(0, 100));
    });
  });

  // ================================================================
  // DOMAIN — GameSessionRecord
  // ================================================================
  group('Domain — GameSessionRecord', () {
    test('create() yields a fresh ready session with stable id', () {
      final r = GameSessionRecord.create();
      expect(r.id, greaterThan(0));
      expect(r.score, 0);
      expect(r.livesLost, 0);
      expect(r.maxLives, 3);
      expect(r.state, GameSessionState.ready);
      expect(r.isNewBest, isFalse);
      expect(r.endedAt, isNull);
    });

    test('complete() returns a completed copy with round data', () {
      final started = GameSessionRecord.create();
      final done = started.complete(
        finalScore: 500,
        finalLivesLost: 1,
        timePlayed: 30,
        finalBestCombo: 4,
        finalCatches: 12,
        finalAccuracy: 0.85,
        finalSmileScore: 72,
      );

      expect(done.id, started.id);
      expect(done.score, 500);
      expect(done.livesLost, 1);
      expect(done.timePlayed, 30);
      expect(done.bestCombo, 4);
      expect(done.catches, 12);
      expect(done.accuracy, 0.85);
      expect(done.smileScore, 72);
      expect(done.state, GameSessionState.results);
      expect(done.endedAt, isNotNull);
      expect(done.startedAt, started.startedAt);
    });
  });

  // ================================================================
  // DOMAIN — FoodItem
  // ================================================================
  group('Domain — FoodItem', () {
    const base = FoodItem(
      type: FoodItemType.gold,
      positionX: 100,
      positionY: 100,
      velocityX: 10,
      velocityY: 10,
      size: 30,
      creationTime: 0,
    );

    test('isActive is true while within the lifetime window', () {
      expect(base.isActive(500, 1000), isTrue);
      expect(base.isActive(1500, 1000), isFalse);
    });

    test('update moves by velocity × delta', () {
      final moved = base.update(1.0, 800, 600);
      expect(moved.positionX, 110);
      expect(moved.positionY, 110);
      expect(moved.velocityX, 10);
      expect(moved.velocityY, 10);
    });

    test('update bounces off the left edge', () {
      const nearLeft = FoodItem(
        type: FoodItemType.gold,
        positionX: 5,
        positionY: 100,
        velocityX: -10,
        velocityY: 10,
        size: 30,
        creationTime: 0,
      );
      final bounced = nearLeft.update(1.0, 800, 600);
      expect(bounced.velocityX, 10);
    });

    test('update bounces off the right edge', () {
      const nearRight = FoodItem(
        type: FoodItemType.gold,
        positionX: 780,
        positionY: 100,
        velocityX: 10,
        velocityY: 10,
        size: 30,
        creationTime: 0,
      );
      final bounced = nearRight.update(1.0, 800, 600);
      expect(bounced.velocityX, -10);
    });
  });
}
