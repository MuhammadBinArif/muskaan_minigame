import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/achievements/domain/player_achievement.dart';
import 'package:muskaan_minigame/features/progression/domain/player_progression.dart';

void main() {
  const rules = ProgressionRules();
  const player = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'XP is deterministic, bounded, and requires a completed owned result',
    () {
      expect(rules.xpFor(_record(id: 1, score: 1200, catches: 12)), 162);
      expect(rules.xpFor(_record(id: 2, score: 300, catches: 2)), 113);
      expect(rules.xpFor(_record(id: 5, score: 5000, catches: 10)), 200);
      expect(rules.xpFor(_record(id: 6, score: -100, catches: -1)), 100);
      expect(rules.xpFor(_record(id: 3, state: GameSessionState.gameOver)), 0);
      expect(rules.xpFor(_record(id: 4, playerId: null)), 0);
    },
  );

  test('Touch-Only and Smile rounds earn the same gameplay XP formula', () {
    final touch = _record(id: 1, score: 500, catches: 4, touch: true);
    final smile = _record(id: 2, score: 500, catches: 4, smile: true);
    expect(rules.xpFor(touch), rules.xpFor(smile));
  });

  test('level thresholds and next-level progress handle boundaries', () {
    expect(rules.levelFor(0), 1);
    expect(rules.levelFor(499), 1);
    expect(rules.levelFor(500), 2);
    expect(rules.levelFor(1000), 3);
    expect(rules.xpIntoLevel(999), 499);
  });

  test(
    'default, level, round, and achievement cosmetics unlock deterministically',
    () {
      final cosmetics = rules.cosmetics(
        level: 2,
        rounds: 5,
        achievements: {AchievementId.firstCatch},
        persisted: const {},
      );
      bool unlocked(String id) =>
          cosmetics.singleWhere((item) => item.item.id == id).unlocked;
      expect(unlocked('ninja'), isTrue);
      expect(unlocked('superhero'), isTrue);
      expect(unlocked('wizard'), isFalse);
      expect(unlocked('glasses'), isTrue);
      expect(unlocked('mask'), isTrue);
      expect(unlocked('crown'), isFalse);
    },
  );

  test(
    'persisted ownership unlock remains available without deleting defaults',
    () {
      final unlock = CosmeticUnlock(
        playerId: player,
        cosmeticId: 'wizard',
        unlockedAt: DateTime.utc(2026),
        source: 'earned',
      );
      final cosmetics = rules.cosmetics(
        level: 1,
        rounds: 0,
        achievements: const {},
        persisted: {'wizard': unlock},
      );
      expect(
        cosmetics.singleWhere((item) => item.item.id == 'wizard').unlocked,
        isTrue,
      );
      expect(
        cosmetics
            .where((item) => item.item.isDefault)
            .every((item) => item.unlocked),
        isTrue,
      );
    },
  );
}

GameSessionRecord _record({
  required int id,
  int score = 0,
  int catches = 0,
  String? playerId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  bool touch = false,
  bool smile = false,
  GameSessionState state = GameSessionState.results,
}) => GameSessionRecord(
  playerId: playerId,
  playerName: playerId == null ? null : 'Player',
  playerAvatar: playerId == null ? null : '🥷',
  usedTouchMode: touch,
  usedSmileMode: smile,
  id: id,
  score: score,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 10,
  bestCombo: catches,
  catches: catches,
  accuracy: catches == 0 ? 0 : 1,
  smileScore: 0,
  startedAt: DateTime.utc(2026),
  endedAt: DateTime.utc(2026, 1, 1, 0, 1),
  state: state,
  isNewBest: false,
);
