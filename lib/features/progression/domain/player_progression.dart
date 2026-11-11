import '../../../core/domain/game_session.dart';
import '../../achievements/domain/player_achievement.dart';

enum CosmeticRequirementType { defaultItem, level, rounds, achievement }

class CosmeticItem {
  final String id;
  final String symbol;
  final String name;
  final CosmeticRequirementType requirementType;
  final int target;
  final AchievementId? achievementId;

  const CosmeticItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.requirementType,
    this.target = 0,
    this.achievementId,
  });
  bool get isDefault => requirementType == CosmeticRequirementType.defaultItem;
}

const cosmeticCatalog = <CosmeticItem>[
  CosmeticItem(
    id: 'ninja',
    symbol: '🥷',
    name: 'Ninja',
    requirementType: CosmeticRequirementType.defaultItem,
  ),
  CosmeticItem(
    id: 'curly',
    symbol: '🧑🏽‍🦱',
    name: 'Curly Hero',
    requirementType: CosmeticRequirementType.defaultItem,
  ),
  CosmeticItem(
    id: 'classic_man',
    symbol: '👨🏾',
    name: 'Classic Hero',
    requirementType: CosmeticRequirementType.defaultItem,
  ),
  CosmeticItem(
    id: 'classic_woman',
    symbol: '👩🏽',
    name: 'Classic Star',
    requirementType: CosmeticRequirementType.defaultItem,
  ),
  CosmeticItem(
    id: 'bright_star',
    symbol: '👩🏻',
    name: 'Bright Star',
    requirementType: CosmeticRequirementType.defaultItem,
  ),
  CosmeticItem(
    id: 'superhero',
    symbol: '🦸',
    name: 'Super Hero',
    requirementType: CosmeticRequirementType.level,
    target: 2,
  ),
  CosmeticItem(
    id: 'wizard',
    symbol: '🧙',
    name: 'Smile Wizard',
    requirementType: CosmeticRequirementType.level,
    target: 3,
  ),
  CosmeticItem(
    id: 'glasses',
    symbol: '🤓',
    name: 'Smart Glasses',
    requirementType: CosmeticRequirementType.rounds,
    target: 5,
  ),
  CosmeticItem(
    id: 'crown',
    symbol: '👑',
    name: 'Champion Crown',
    requirementType: CosmeticRequirementType.achievement,
    achievementId: AchievementId.dedicatedPlayer,
  ),
  CosmeticItem(
    id: 'mask',
    symbol: '🎭',
    name: 'Festival Mask',
    requirementType: CosmeticRequirementType.achievement,
    achievementId: AchievementId.firstCatch,
  ),
];

class ProgressionAward {
  final String playerId;
  final int resultId;
  final int xp;
  final DateTime awardedAt;
  const ProgressionAward({
    required this.playerId,
    required this.resultId,
    required this.xp,
    required this.awardedAt,
  });
}

class CosmeticUnlock {
  final String playerId;
  final String cosmeticId;
  final DateTime unlockedAt;
  final String source;
  const CosmeticUnlock({
    required this.playerId,
    required this.cosmeticId,
    required this.unlockedAt,
    required this.source,
  });
}

class CosmeticProgress {
  final CosmeticItem item;
  final bool unlocked;
  final int progress;
  final CosmeticUnlock? unlock;
  const CosmeticProgress({
    required this.item,
    required this.unlocked,
    required this.progress,
    this.unlock,
  });
  int get boundedProgress =>
      progress < 0
          ? 0
          : progress > item.target
          ? item.target
          : progress;
}

class PlayerProgression {
  final int totalXp;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int lifetimeVerifiedRounds;
  final List<CosmeticProgress> cosmetics;
  final List<CosmeticUnlock> recentUnlocks;

  const PlayerProgression({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.lifetimeVerifiedRounds,
    required this.cosmetics,
    required this.recentUnlocks,
  });
  double get levelFraction =>
      xpForNextLevel == 0 ? 0 : xpIntoLevel / xpForNextLevel;
}

class ProgressionRules {
  const ProgressionRules();
  static const xpPerLevel = 500;

  int xpFor(GameSessionRecord record) {
    if (record.playerId == null ||
        record.state != GameSessionState.results ||
        record.endedAt == null ||
        record.id <= 0) {
      return 0;
    }
    final rawScoreBonus = record.score ~/ 100;
    final scoreBonus =
        rawScoreBonus < 0
            ? 0
            : rawScoreBonus > 50
            ? 50
            : rawScoreBonus;
    final rawCatchBonus = record.catches * 5;
    final catchBonus =
        rawCatchBonus < 0
            ? 0
            : rawCatchBonus > 50
            ? 50
            : rawCatchBonus;
    return 100 + scoreBonus + catchBonus;
  }

  int levelFor(int xp) => xp < 0 ? 1 : xp ~/ xpPerLevel + 1;
  int xpIntoLevel(int xp) => xp < 0 ? 0 : xp % xpPerLevel;

  List<CosmeticProgress> cosmetics({
    required int level,
    required int rounds,
    required Set<AchievementId> achievements,
    required Map<String, CosmeticUnlock> persisted,
  }) {
    return [
      for (final item in cosmeticCatalog)
        _cosmetic(
          item,
          level: level,
          rounds: rounds,
          achievements: achievements,
          persisted: persisted[item.id],
        ),
    ];
  }

  CosmeticProgress _cosmetic(
    CosmeticItem item, {
    required int level,
    required int rounds,
    required Set<AchievementId> achievements,
    CosmeticUnlock? persisted,
  }) {
    final progress = switch (item.requirementType) {
      CosmeticRequirementType.defaultItem => 1,
      CosmeticRequirementType.level => level,
      CosmeticRequirementType.rounds => rounds,
      CosmeticRequirementType.achievement =>
        achievements.contains(item.achievementId) ? 1 : 0,
    };
    final target =
        item.isDefault
            ? 1
            : item.requirementType == CosmeticRequirementType.achievement
            ? 1
            : item.target;
    return CosmeticProgress(
      item: item,
      unlocked: item.isDefault || persisted != null || progress >= target,
      progress: progress,
      unlock: persisted,
    );
  }

  String requirement(CosmeticProgress cosmetic) => switch (cosmetic
      .item
      .requirementType) {
    CosmeticRequirementType.defaultItem => 'Available by default',
    CosmeticRequirementType.level => 'Reach level ${cosmetic.item.target}',
    CosmeticRequirementType.rounds =>
      'Complete ${cosmetic.item.target} verified rounds',
    CosmeticRequirementType.achievement =>
      'Unlock ${_achievementTitle(cosmetic.item.achievementId!)}',
  };

  String progress(CosmeticProgress cosmetic) => switch (cosmetic
      .item
      .requirementType) {
    CosmeticRequirementType.defaultItem => 'Available',
    CosmeticRequirementType.level =>
      'Level ${cosmetic.boundedProgress} of ${cosmetic.item.target}',
    CosmeticRequirementType.rounds =>
      '${cosmetic.boundedProgress} of ${cosmetic.item.target} rounds',
    CosmeticRequirementType.achievement =>
      cosmetic.unlocked ? 'Achievement complete' : 'Achievement incomplete',
  };

  String _achievementTitle(AchievementId id) =>
      achievementDefinitions.singleWhere((item) => item.id == id).title;
}
