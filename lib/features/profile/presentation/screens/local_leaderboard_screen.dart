import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../game/data/records_repository.dart';
import '../../../../core/domain/game_session.dart';
import '../widgets/player_identity.dart';

class LocalLeaderboardScreen extends ConsumerWidget {
  const LocalLeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Leaderboard on this device')),
    body: ref
        .watch(allRecordsStreamProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, _) =>
                  const Center(child: Text('Unable to load local scores.')),
          data: (records) {
            final best = <String, GameSessionRecord>{};
            for (final record in records) {
              final key = record.playerId ?? 'legacy-record-${record.id}';
              if (!best.containsKey(key) || record.score > best[key]!.score)
                best[key] = record;
            }
            final ranked =
                best.values.toList()
                  ..sort((a, b) => b.score.compareTo(a.score));
            if (ranked.isEmpty)
              return const Center(
                child: Text('Complete a round to see your local score.'),
              );
            return ListView.builder(
              itemCount: ranked.length,
              itemBuilder:
                  (_, index) => ListTile(
                    leading: Text('${index + 1}'),
                    title: PlayerIdentity(record: ranked[index]),
                    subtitle: Text(
                      ranked[index].playerId == null
                          ? 'Historical record · ownership unknown'
                          : 'Local score · not server verified',
                    ),
                    trailing: Text('${ranked[index].score}'),
                  ),
            );
          },
        ),
  );
}
