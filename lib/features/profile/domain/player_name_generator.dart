import 'dart:math';

/// An allowlisted vocabulary and numeric suffix reduce accidental collisions.
/// Display names remain labels, never authentication or ownership identifiers.
class FriendlyPlayerNameGenerator {
  FriendlyPlayerNameGenerator({Random? random})
    : _random = random ?? Random.secure();
  final Random _random;
  static const _adjectives = [
    'Happy',
    'Sunny',
    'Joyful',
    'Friendly',
    'Bright',
    'Cheerful',
  ];
  static const _nouns = [
    'Panda',
    'Explorer',
    'Star',
    'Champion',
    'Otter',
    'Player',
  ];
  String generate() =>
      '${_adjectives[_random.nextInt(_adjectives.length)]} ${_nouns[_random.nextInt(_nouns.length)]} ${1000 + _random.nextInt(9000)}';
}
