import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import '../domain/player_profile.dart';

class PlayerProfileRepository {
  PlayerProfileRepository(this.database);
  final GameDatabase database;
  Future<PlayerProfile> loadOrCreate() => database.transaction(() async {
    final row =
        await database
            .customSelect('SELECT payload FROM player_profile WHERE slot = 1')
            .getSingleOrNull();
    if (row != null) {
      return PlayerProfile.fromJson(
        jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
      );
    }
    final profile = PlayerProfile.create();
    await save(profile);
    return profile;
  });
  Future<void> save(PlayerProfile profile) async {
    PlayerProfile.fromJson(profile.toJson());
    await database.customStatement(
      'INSERT INTO player_profile(slot, payload) VALUES(1, ?) ON CONFLICT(slot) DO UPDATE SET payload = excluded.payload',
      [jsonEncode(profile.toJson())],
    );
  }

  Future<PlayerProfile> replaceCorruptProfile() =>
      database.transaction(() async {
        await database.customStatement(
          'DELETE FROM player_profile WHERE slot = 1',
        );
        final replacement = PlayerProfile.create();
        await save(replacement);
        return replacement;
      });
}

final playerProfileRepositoryProvider = Provider(
  (ref) => PlayerProfileRepository(ref.watch(gameDatabaseProvider)),
);
final playerProfileProvider = StateNotifierProvider<
  PlayerProfileController,
  AsyncValue<PlayerProfile>
>((ref) => PlayerProfileController(ref.watch(playerProfileRepositoryProvider)));

class PlayerProfileController extends StateNotifier<AsyncValue<PlayerProfile>> {
  PlayerProfileController(this.repository) : super(const AsyncLoading()) {
    ready = _load();
  }
  final PlayerProfileRepository repository;
  late final Future<void> ready;
  Future<void> _pending = Future.value();
  Future<void> _load() async {
    try {
      final profile = await repository.loadOrCreate();
      if (mounted) state = AsyncData(profile);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> retryLoad() async {
    state = const AsyncLoading();
    await _load();
  }

  Future<void> replaceCorruptProfile() async {
    final replacement = await repository.replaceCorruptProfile();
    if (mounted) state = AsyncData(replacement);
  }

  Future<void> update({String? name, String? avatar, bool? onboarded}) {
    // Serialize edits; a failed write leaves the previous authoritative state intact.
    final operation = _pending.then((_) async {
      await ready;
      final current = state.requireValue;
      final next = current.copyWith(
        displayName: name,
        avatar: avatar,
        onboarded: onboarded,
      );
      await repository.save(next);
      if (mounted) state = AsyncData(next);
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
