import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'features/ads/ad_service.dart';

/// Emoji font families to try, in order, before Skia falls back to
/// its placeholder (.notdef) glyph.
const List<String> _emojiFallbacks = <String>[
  'Noto Color Emoji', // Android
  'Apple Color Emoji', // iOS / macOS
  'Segoe UI Emoji', // Windows
  'Noto Emoji', // Generic Linux
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-resolve the platform emoji font BEFORE the first frame.
  // Without this, Skia lazily loads NotoColorEmoji (Android) /
  // AppleColorEmoji (iOS) mid-frame on cold launch, causing 1-2 s
  // of tofu boxes for every emoji in the UI.
  await _preloadEmojiFont();

  runApp(const ProviderScope(child: MuskaanApp()));
}

Future<void> _preloadEmojiFont() async {
  // Every emoji that appears anywhere in the app, in screen order
  // (01 Splash → 20 Challenge Detail). When you introduce a new
  // emoji, append it here so it's warm on the next cold launch.
  final emojis =
      const [
        // 01 Splash
        '🫙', '🍵', '⭐',
        // 02 Welcome
        '😜', '🎯',
        // 03 Step 1
        '📱',
        // 04 Step 2
        '😮',
        // 05 Step 3
        '⚡', '📷',
        // 06 Camera Permission
        '✓', '🔒', '👁️', '🛡️',
        // 07 Camera Denied
        '🚫', '⚙️',
        // 09/10 Home
        '👋', '🔥', '😁', '🏋️', '🏆', '🎉',
        // 11 Mode Selection
        '⚔️',
        // 13 Gameplay
        '❤️',
        // 14 Pause
        '⏸', '🔊', '🎵', '▶', '↺',
        // 15 Game Over
        '😵',
        // 16 Results
        '⏱️', '🔄', '📤',
        // 17 Share
        '💬', '📸', '📋',
        // 18 Smile Spotlight
        '😊', '✨', '⚠️',
        // 19/20 Challenges
        '🌊', '✅', '🥇', '🥈', '🥉', '🏅', '⏰',
      ].join();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // ParagraphStyle: layout rules (alignment, line height, etc.)
  // NOTE: ParagraphStyle has NO fontFamilyFallback param — only fontFamily.
  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.left,
    fontSize: 32,
  );

  final paragraphBuilder =
      ui.ParagraphBuilder(paragraphStyle)
        // TextStyle: per-run styling. This is where fontFamilyFallback lives.
        ..pushStyle(
          ui.TextStyle(fontSize: 32, fontFamilyFallback: _emojiFallbacks),
        )
        ..addText(emojis);

  final paragraph =
      paragraphBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: 800));

  // Correct API: draw the paragraph through the canvas, not on
  // the paragraph itself.
  canvas.drawParagraph(paragraph, ui.Offset.zero);

  final picture = recorder.endRecording();

  // 🔑 The `toImage` call is what actually forces the font to load.
  final image = await picture.toImage(800, 64);
  image.dispose();
  picture.dispose();
}

class MuskaanApp extends ConsumerWidget {
  const MuskaanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(adServiceProvider).initialize());
    return MaterialApp.router(
      title: 'Muskaan Minigame',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: appRouter,
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.dark();

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: _emojiFallbacks),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: _emojiFallbacks,
      ),
    );
  }
}
