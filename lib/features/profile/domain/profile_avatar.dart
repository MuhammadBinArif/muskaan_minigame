import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The existing profile uses a static emoji, not an image or editable parts.
/// A future persisted profile adapter must emit changes through this boundary.
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

/// No avatar selection or persistence exists yet. Do not manufacture a saved
/// selection or add a second database. Replace this adapter when it exists.
class UnconfiguredProfileAvatarRepository implements ProfileAvatarRepository {
  const UnconfiguredProfileAvatarRepository();
  @override
  Stream<ProfileAvatar?> watchAvatar() => Stream.value(null);
}

final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>(
  (ref) => const UnconfiguredProfileAvatarRepository(),
);
final profileAvatarProvider = StreamProvider<ProfileAvatar?>(
  (ref) => ref.watch(profileAvatarRepositoryProvider).watchAvatar(),
);

ProfileAvatar resolveAvatarState(AsyncValue<ProfileAvatar?> state) =>
    ProfileAvatar.resolve(state.asData?.value);
