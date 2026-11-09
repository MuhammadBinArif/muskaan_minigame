import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/domain/player_profile.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';

PlayerProfile createTestPlayer({
  String id = '0123456789abcdef0123456789abcdef',
  String name = 'Happy Panda',
  String avatar = '🥷',
}) => PlayerProfile(
  id: id,
  displayName: name,
  avatar: avatar,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  onboarded: true,
);

GameSessionRecord createTestSession() {
  final player = createTestPlayer();
  return GameSessionRecord.create(
    playerId: player.id,
    playerName: player.displayName,
    playerAvatar: player.avatar,
  );
}

class MemoryPlayerRepository implements PlayerProfileRepository {
  MemoryPlayerRepository({PlayerProfile? profile})
    : saved = profile ?? createTestPlayer();
  PlayerProfile saved;
  bool failWrites = false;
  @override
  GameDatabase get database =>
      throw UnsupportedError('No database in this test adapter');
  @override
  Future<PlayerProfile> loadOrCreate() async => saved;
  @override
  Future<void> save(PlayerProfile profile) async {
    if (failWrites) throw StateError('disk full');
    saved = profile;
  }

  @override
  Future<PlayerProfile> replaceCorruptProfile() async {
    saved = PlayerProfile.create();
    return saved;
  }
}
