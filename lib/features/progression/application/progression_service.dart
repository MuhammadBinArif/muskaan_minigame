import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievements/data/achievement_repository.dart';
import '../../game/data/records_repository.dart';
import '../data/progression_repository.dart';
import '../domain/player_progression.dart';

class ProgressionService {
  ProgressionService(this.records, this.achievements, this.repository);
  final GameRecordsRepository records;
  final AchievementRepository achievements;
  final ProgressionRepository repository;
  static const rules = ProgressionRules();

  Future<PlayerProgression> synchronize(String playerId) async {
    final history = await records.getPlayerSessions(playerId);
    final owned =
        history
            .where(
              (record) =>
                  record.playerId == playerId && rules.xpFor(record) > 0,
            )
            .toList();
    for (final record in owned) {
      await repository.awardResult(
        ProgressionAward(
          playerId: playerId,
          resultId: record.id,
          xp: rules.xpFor(record),
          awardedAt: record.endedAt!,
        ),
      );
    }
    var awards = await repository.getAwards(playerId);
    final totalXp = awards.fold<int>(0, (sum, award) => sum + award.xp);
    final level = rules.levelFor(totalXp);
    final achievementIds =
        (await achievements.getUnlocks(
          playerId,
        )).map((unlock) => unlock.achievementId).toSet();
    var unlocks = await repository.getUnlocks(playerId);
    var cosmetics = rules.cosmetics(
      level: level,
      rounds: awards.length,
      achievements: achievementIds,
      persisted: {for (final unlock in unlocks) unlock.cosmeticId: unlock},
    );
    final earnedAt = owned.fold<DateTime>(
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      (latest, record) =>
          record.endedAt!.toUtc().isAfter(latest)
              ? record.endedAt!.toUtc()
              : latest,
    );
    for (final cosmetic in cosmetics.where(
      (item) => item.unlocked && !item.item.isDefault && item.unlock == null,
    )) {
      await repository.unlock(
        CosmeticUnlock(
          playerId: playerId,
          cosmeticId: cosmetic.item.id,
          unlockedAt: earnedAt,
          source: rules.requirement(cosmetic),
        ),
      );
    }
    unlocks = await repository.getUnlocks(playerId);
    cosmetics = rules.cosmetics(
      level: level,
      rounds: awards.length,
      achievements: achievementIds,
      persisted: {for (final unlock in unlocks) unlock.cosmeticId: unlock},
    );
    awards = await repository.getAwards(playerId);
    return PlayerProgression(
      totalXp: totalXp,
      level: level,
      xpIntoLevel: rules.xpIntoLevel(totalXp),
      xpForNextLevel: ProgressionRules.xpPerLevel,
      lifetimeVerifiedRounds: awards.length,
      cosmetics: cosmetics,
      recentUnlocks: unlocks.take(3).toList(growable: false),
    );
  }

  Future<bool> canEquip(String playerId, String symbol) async {
    CosmeticItem? item;
    for (final candidate in cosmeticCatalog) {
      if (candidate.symbol == symbol) {
        item = candidate;
        break;
      }
    }
    final selectedItem = item;
    if (selectedItem == null) return false;
    final progression = await synchronize(playerId);
    return progression.cosmetics
        .singleWhere((entry) => entry.item.id == selectedItem.id)
        .unlocked;
  }
}

final progressionServiceProvider = Provider(
  (ref) => ProgressionService(
    ref.watch(gameRecordsRepositoryProvider),
    ref.watch(achievementRepositoryProvider),
    ref.watch(progressionRepositoryProvider),
  ),
);

final playerProgressionProvider = FutureProvider.autoDispose
    .family<PlayerProgression, String>(
      (ref, playerId) =>
          ref.watch(progressionServiceProvider).synchronize(playerId),
    );
