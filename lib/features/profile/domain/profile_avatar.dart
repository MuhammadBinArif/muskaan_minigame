import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// The existing profile uses a static emoji, not an image or editable parts.
/// A future persisted profile adapter must emit changes through this boundary.
class ProfileAvatar {
  const ProfileAvatar(this.symbol);
  final String symbol;
  static const fallback = ProfileAvatar('🥷');
  static const options = <String>['🧑🏽‍🦱', '👨🏾', '👩🏽', '👩🏻'];

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

abstract interface class WritableProfileAvatarRepository
    implements ProfileAvatarRepository {
  Future<void> selectAvatar(ProfileAvatar avatar);
}

class PreferencesProfileAvatarRepository
    implements WritableProfileAvatarRepository {
  static const key = 'profile_avatar_symbol';
  final StreamController<ProfileAvatar?> _changes =
      StreamController<ProfileAvatar?>.broadcast();

  @override
  Stream<ProfileAvatar?> watchAvatar() => Stream.multi((sink) {
    var changed = false;
    var cancelled = false;
    final subscription = _changes.stream.listen(
      (avatar) {
        changed = true;
        sink.add(avatar);
      },
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.onCancel = () {
      cancelled = true;
      return subscription.cancel();
    };
    SharedPreferences.getInstance().then(
      (preferences) {
        if (changed || cancelled) return;
        final stored = preferences.getString(key);
        sink.add(
          stored != null && ProfileAvatar.options.contains(stored)
              ? ProfileAvatar(stored)
              : null,
        );
      },
      onError: (Object error, StackTrace stack) {
        if (!cancelled) sink.addError(error, stack);
      },
    );
  });

  @override
  Future<void> selectAvatar(ProfileAvatar avatar) async {
    if (!ProfileAvatar.options.contains(avatar.symbol)) {
      throw ArgumentError('Unknown avatar');
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, avatar.symbol)) {
      throw StateError('Avatar could not be saved');
    }
    _changes.add(avatar);
  }

  Future<void> dispose() => _changes.close();
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

final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>((
  ref,
) {
  final repository = PreferencesProfileAvatarRepository();
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final profileAvatarProvider = StreamProvider<ProfileAvatar?>(
  (ref) => ref.watch(profileAvatarRepositoryProvider).watchAvatar(),
);

ProfileAvatar resolveAvatarState(AsyncValue<ProfileAvatar?> state) =>
    ProfileAvatar.resolve(state.asData?.value);
