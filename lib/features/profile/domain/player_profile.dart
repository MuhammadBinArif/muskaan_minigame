import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';
import 'player_name_generator.dart';

String validatePlayerName(String input) {
  if (RegExp(
    r'[\x00-\x1F\x7F-\x9F\u200B\u2060\uFEFF\u2028\u2029\u202A-\u202E\u2066-\u2069]',
  ).hasMatch(input)) {
    throw const FormatException(
      'Names cannot contain control or invisible formatting characters.',
    );
  }
  final name = input.trim();
  if (name.isEmpty ||
      RegExp(r'^[\s\u200B-\u200D\u2060\uFEFF]+$').hasMatch(name)) {
    throw const FormatException('Enter a visible player name.');
  }
  if (name.characters.length > 30 || name.length > 120) {
    throw const FormatException('Use 30 characters or fewer.');
  }
  return name;
}

@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.onboarded = false,
  });
  final String id;
  final String displayName;
  final String avatar;
  final DateTime createdAt, updatedAt;
  final bool onboarded;
  factory PlayerProfile.create() {
    final random = Random.secure();
    final id =
        List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    final name = FriendlyPlayerNameGenerator(random: random).generate();
    final now = DateTime.now().toUtc();
    return PlayerProfile(
      id: id,
      displayName: name,
      avatar: '🥷',
      createdAt: now,
      updatedAt: now,
    );
  }
  PlayerProfile copyWith({
    String? displayName,
    String? avatar,
    bool? onboarded,
  }) => PlayerProfile(
    id: id,
    displayName: validatePlayerName(displayName ?? this.displayName),
    avatar: avatar ?? this.avatar,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
    onboarded: onboarded ?? this.onboarded,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatar': avatar,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'onboarded': onboarded,
  };
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final avatar = json['avatar'] as String;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
        avatar.isEmpty ||
        avatar.runes.length > 16 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(avatar)) {
      throw const FormatException('Invalid saved player profile.');
    }
    return PlayerProfile(
      id: id,
      displayName: validatePlayerName(json['displayName'] as String),
      avatar: avatar,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      onboarded: json['onboarded'] as bool,
    );
  }
}
