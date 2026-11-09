import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../profile/data/player_profile_repository.dart';
import '../../application/achievement_service.dart';
import '../../domain/player_achievement.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});
  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementCategory? _category;

  @override
  Widget build(BuildContext context) {
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
    final progress = ref.watch(playerAchievementProgressProvider(profile.id));
    return Scaffold(
      backgroundColor: const Color(0xFF100C18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191426),
        foregroundColor: Colors.white,
        title: const Text('Achievements'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/profile'),
          icon: const Icon(Icons.chevron_left),
        ),
      ),
      body: SafeArea(
        child: progress.when(
          loading:
              () => const Center(
                key: Key('achievements-loading'),
                child: CircularProgressIndicator(),
              ),
          error:
              (_, _) => Center(
                key: const Key('achievements-error'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Achievements could not be loaded.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed:
                          () => ref.invalidate(
                            playerAchievementProgressProvider(profile.id),
                          ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          data: (evaluation) {
            final visible =
                evaluation.progress
                    .where(
                      (item) =>
                          _category == null ||
                          item.definition.category == _category,
                    )
                    .toList();
            final unlocked =
                evaluation.progress.where((item) => item.isUnlocked).length;
            return ListView(
              key: ValueKey('achievements-${profile.id}'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _identity(
                  profile.avatar,
                  profile.displayName,
                  unlocked,
                  evaluation.progress.length,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final category in AchievementCategory.values)
                      ChoiceChip(
                        key: Key('achievement-filter-${category.name}'),
                        label: Text(_categoryLabel(category)),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const Center(
                    child: Text(
                      'No achievements in this category.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else
                  for (final item in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AchievementCard(item: item),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _identity(String avatar, String name, int unlocked, int total) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF29243D),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(avatar, style: const TextStyle(fontSize: 28)),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '$unlocked of $total badges unlocked',
                    style: const TextStyle(color: Color(0xFFC7BED2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item});
  final PlayerAchievementProgress item;
  @override
  Widget build(BuildContext context) {
    final status =
        item.isUnlocked
            ? 'Unlocked'
            : !item.available
            ? 'Unavailable'
            : item.progress > 0
            ? 'In progress'
            : 'Locked';
    return Semantics(
      label:
          '${item.definition.title}, $status, ${item.boundedProgress} of ${item.definition.target}',
      child: Container(
        key: Key('achievement-${item.definition.id.name}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              item.isUnlocked
                  ? const Color(0xFF2B342F)
                  : const Color(0xFF25213A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                item.isUnlocked
                    ? const Color(0xFF55B77B)
                    : const Color(0xFF403A58),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.definition.badge,
              style: TextStyle(
                fontSize: 30,
                color: item.available ? null : Colors.grey,
              ),
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
                          item.definition.title,
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
                              item.isUnlocked
                                  ? const Color(0xFF72D49A)
                                  : const Color(0xFFFFD45C),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.definition.description,
                    style: const TextStyle(color: Color(0xFFBDB5C9)),
                  ),
                  const SizedBox(height: 9),
                  if (item.available) ...[
                    LinearProgressIndicator(
                      value: item.isUnlocked ? 1 : item.fraction,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item.boundedProgress} / ${item.definition.target}',
                      style: const TextStyle(
                        color: Color(0xFFC7BED2),
                        fontSize: 12,
                      ),
                    ),
                  ] else
                    const Text(
                      'Complete eligible activity to make progress available.',
                      style: TextStyle(color: Color(0xFF8E879B), fontSize: 12),
                    ),
                  if (item.unlock != null)
                    Text(
                      'Unlocked ${_date(item.unlock!.unlockedAt)} · badge earned',
                      style: const TextStyle(
                        color: Color(0xFF72D49A),
                        fontSize: 12,
                      ),
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

String _categoryLabel(AchievementCategory category) => switch (category) {
  AchievementCategory.gameplay => 'Gameplay',
  AchievementCategory.smile => 'Smile',
  AchievementCategory.progress => 'Progress',
};
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
