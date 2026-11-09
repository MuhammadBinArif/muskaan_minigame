import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../profile/data/player_profile_repository.dart';
import '../../application/progression_service.dart';
import '../../domain/player_progression.dart';

class PlayerProgressScreen extends ConsumerWidget {
  const PlayerProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(playerProfileProvider);
    final profile = profileState.asData?.value;
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF100C18),
        body: Center(
          child:
              profileState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Player profile unavailable.'),
        ),
      );
    }
    final progression = ref.watch(playerProgressionProvider(profile.id));
    return Scaffold(
      backgroundColor: const Color(0xFF100C18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191426),
        foregroundColor: Colors.white,
        title: const Text('Player Progress'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/profile'),
          icon: const Icon(Icons.chevron_left),
        ),
      ),
      body: SafeArea(
        child: progression.when(
          loading:
              () => const Center(
                key: Key('progression-loading'),
                child: CircularProgressIndicator(),
              ),
          error:
              (_, _) => Center(
                key: const Key('progression-error'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Progress could not be loaded.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed:
                          () => ref.invalidate(
                            playerProgressionProvider(profile.id),
                          ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          data:
              (state) => ListView(
                key: ValueKey('progress-${profile.id}'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _LevelCard(
                    avatar: profile.avatar,
                    name: profile.displayName,
                    state: state,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cosmetic collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final cosmetic in state.cosmetics)
                    Card(
                      color: const Color(0xFF25213A),
                      child: ListTile(
                        leading: Text(
                          cosmetic.item.symbol,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          cosmetic.item.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          cosmetic.unlocked
                              ? cosmetic.item.isDefault
                                  ? 'Available by default'
                                  : 'Unlocked · ${cosmetic.unlock?.source ?? 'Milestone earned'}'
                              : '${ProgressionService.rules.requirement(cosmetic)} · ${ProgressionService.rules.progress(cosmetic)}',
                          style: const TextStyle(color: Color(0xFFBDB5C9)),
                        ),
                        trailing: Icon(
                          cosmetic.unlocked
                              ? Icons.check_circle
                              : Icons.lock_outline,
                          color:
                              cosmetic.unlocked
                                  ? const Color(0xFF72D49A)
                                  : const Color(0xFFFFD45C),
                        ),
                      ),
                    ),
                  if (state.recentUnlocks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Recently unlocked',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final unlock in state.recentUnlocks)
                      Text(
                        '• ${unlock.cosmeticId} · ${_date(unlock.unlockedAt)}',
                        style: const TextStyle(color: Color(0xFFC7BED2)),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/achievements'),
                          child: const Text('Achievements'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/challenges'),
                          child: const Text('Challenges'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.avatar,
    required this.name,
    required this.state,
  });
  final String avatar;
  final String name;
  final PlayerProgression state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3D2517), Color(0xFF25213A)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x66FFD700)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              child: Text(avatar, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Level ${state.level}',
                    style: const TextStyle(
                      color: Color(0xFFFFD45C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              '${state.xpIntoLevel} of ${state.xpForNextLevel} experience points toward the next level',
          child: LinearProgressIndicator(
            value: state.levelFraction,
            minHeight: 9,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${state.totalXp} XP total · ${state.xpIntoLevel} / ${state.xpForNextLevel} to next level',
          style: const TextStyle(color: Color(0xFFC7BED2)),
        ),
        Text(
          '${state.lifetimeVerifiedRounds} lifetime verified rounds',
          style: const TextStyle(color: Color(0xFFC7BED2)),
        ),
      ],
    ),
  );
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
