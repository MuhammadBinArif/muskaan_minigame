import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/player_profile_repository.dart';

/// Presentation boundary for the authoritative profile’s persisted emoji.
class ProfileAvatar {
  const ProfileAvatar(this.symbol);
  final String symbol;
  static const fallback = ProfileAvatar('🥷');

  static ProfileAvatar resolve(ProfileAvatar? value) {
    final symbol = value?.symbol.trim() ?? '';
    if (symbol.isEmpty ||
        symbol.runes.length > 16 ||
        symbol.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      return fallback;
    }
    return ProfileAvatar(symbol);
  }
}

abstract interface class ProfileAvatarRepository {
  Stream<ProfileAvatar?> watchAvatar();
}

final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>(
  (ref) => _PlayerAvatarRepository(
    ref.watch(
      playerProfileProvider.select((state) => state.asData?.value.avatar),
    ),
  ),
);
final profileAvatarProvider = StreamProvider<ProfileAvatar?>(
  (ref) => ref.watch(profileAvatarRepositoryProvider).watchAvatar(),
);

ProfileAvatar resolveAvatarState(AsyncValue<ProfileAvatar?> state) =>
    ProfileAvatar.resolve(state.asData?.value);

class _PlayerAvatarRepository implements ProfileAvatarRepository {
  _PlayerAvatarRepository(this.symbol);
  final String? symbol;
  @override
  Stream<ProfileAvatar?> watchAvatar() {
    // Provider dependency invalidation recreates this stream after a profile edit.
    return Stream.value(symbol == null ? null : ProfileAvatar(symbol!));
  }
}
