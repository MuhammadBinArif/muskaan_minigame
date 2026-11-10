import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/player_profile_repository.dart';
import '../../../../core/domain/game_session.dart';

class PlayerIdentity extends ConsumerWidget {
  const PlayerIdentity({
    super.key,
    this.record,
    this.style,
    this.useResultSnapshot = false,
  });
  final GameSessionRecord? record;
  final TextStyle? style;
  final bool useResultSnapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider).asData?.value;
    final current =
        !useResultSnapshot &&
        (record == null || (profile != null && record!.playerId == profile.id));
    final name = current ? profile?.displayName : record!.playerName;
    final avatar = current ? profile?.avatar : record!.playerAvatar;
    final fallbackName =
        record == null
            ? 'Player unavailable'
            : record!.playerId == null
            ? 'Player not recorded'
            : 'Player unavailable';
    return Text(
      '${avatar ?? '◯'} ${name ?? fallbackName}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
