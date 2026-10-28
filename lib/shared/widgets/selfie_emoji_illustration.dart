import 'package:flutter/material.dart';

/// The bundled Google Noto Color Emoji artwork for the selfie emoji (🤳).
class SelfieEmojiIllustration extends StatelessWidget {
  const SelfieEmojiIllustration({super.key, this.size = 150});

  static const String assetPath = 'assets/onboarding/noto_selfie_emoji.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      key: const Key('onboarding-selfie-emoji'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Person taking a selfie',
    );
  }
}
