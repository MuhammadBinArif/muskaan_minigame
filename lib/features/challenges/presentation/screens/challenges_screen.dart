import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../profile/data/player_profile_repository.dart';
import '../../application/daily_challenge_service.dart';
import '../../domain/daily_challenge.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(playerProfileProvider);
    final profile = profileState.asData?.value;
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0816),
        body: Center(
          child:
              profileState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                    'Player profile unavailable.',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      );
    }
    final engagement = ref.watch(dailyEngagementProvider(profile.id));
    return Scaffold(
      backgroundColor: const Color(0xFF0D0816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1525),
        foregroundColor: Colors.white,
        title: const Text('Daily Challenges'),
        actions: [
          IconButton(
            tooltip: 'Achievements',
            onPressed: () => context.push('/achievements'),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: engagement.when(
          loading:
              () => const Center(
                key: Key('challenges-loading'),
                child: CircularProgressIndicator(),
              ),
          error:
              (_, _) => Center(
                key: const Key('challenges-error'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Challenges could not be loaded.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed:
                          () => ref.invalidate(
                            dailyEngagementProvider(profile.id),
                          ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          data:
              (state) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dailyEngagementProvider(profile.id));
                  await ref.read(dailyEngagementProvider(profile.id).future);
                },
                child: ListView(
                  key: ValueKey(
                    'daily-challenges-${profile.id}-${state.dateKey}',
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _PlayerHeader(
                      avatar: profile.avatar,
                      name: profile.displayName,
                      state: state,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Today's challenges",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          state.dateKey,
                          style: const TextStyle(color: Color(0xFF9A92AA)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Assignments stay fixed for the effective local day. Resets after the next valid date boundary.',
                      style: TextStyle(color: Color(0xFF9A92AA), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    if (state.challenges.isEmpty)
                      const _Message(
                        title: 'No challenges assigned',
                        detail:
                            'Pull down to retry. Your verified results remain safe.',
                      )
                    else
                      for (final challenge in state.challenges)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChallengeCard(challenge: challenge),
                        ),
                    const SizedBox(height: 8),
                    const _Message(
                      title: 'Private, verified progress',
                      detail:
                          'Only completed local results count. Smile challenges use valid calibrated observations and never measure emotion.',
                    ),
                  ],
                ),
              ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.avatar,
    required this.name,
    required this.state,
  });
  final String avatar;
  final String name;
  final DailyEngagementState state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3D2517), Color(0xFF25213A)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x66FFD700)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 29,
          child: Text(avatar, style: const TextStyle(fontSize: 29)),
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
                '${state.challenges.where((item) => item.isComplete).length} of ${state.challenges.length} complete today',
                style: const TextStyle(color: Color(0xFFC9C3D8)),
              ),
            ],
          ),
        ),
        Semantics(
          label:
              'Current streak ${state.streak.current} days, longest streak ${state.streak.longest} days',
          child: Column(
            children: [
              Text(
                '🔥 ${state.streak.current}',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Best ${state.streak.longest}',
                style: const TextStyle(color: Color(0xFFC9C3D8), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});
  final DailyChallengeProgress challenge;
  @override
  Widget build(BuildContext context) {
    final status =
        !challenge.available
            ? 'Unavailable'
            : challenge.isComplete
            ? 'Complete'
            : challenge.progress > 0
            ? 'In progress'
            : 'Not started';
    return Semantics(
      label:
          '${challenge.definition.title}, $status, ${challenge.boundedProgress} of ${challenge.definition.target}',
      child: Container(
        key: Key('daily-${challenge.definition.id.name}'),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              challenge.isComplete
                  ? const Color(0xFF24362F)
                  : const Color(0xFF25213A),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color:
                challenge.isComplete
                    ? const Color(0xFF4DB77A)
                    : const Color(0xFF403A58),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.definition.badge,
              style: const TextStyle(fontSize: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          challenge.definition.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color:
                              challenge.isComplete
                                  ? const Color(0xFF72D49A)
                                  : const Color(0xFFFFD45C),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    challenge.definition.description,
                    style: const TextStyle(color: Color(0xFFBDB5C9)),
                  ),
                  const SizedBox(height: 9),
                  if (challenge.available) ...[
                    LinearProgressIndicator(
                      value: challenge.isComplete ? 1 : challenge.fraction,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${challenge.boundedProgress} / ${challenge.definition.target} · Cosmetic badge ${challenge.definition.badge}',
                      style: const TextStyle(
                        color: Color(0xFFC7BED2),
                        fontSize: 12,
                      ),
                    ),
                  ] else
                    const Text(
                      'Valid calibrated smile measurements are unavailable.',
                      style: TextStyle(color: Color(0xFF9A92AA), fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1729),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9A92AA)),
        ),
      ],
    ),
  );
}
