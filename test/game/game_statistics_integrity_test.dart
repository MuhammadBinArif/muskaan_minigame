import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';

import '../support/player_fixture.dart';

const edibleCatch = CollisionEvent(
  foodType: FoodItemType.gold,
  mouthX: .5,
  mouthY: .52,
  timestamp: 1,
  isCatch: true,
);

const hazardHit = CollisionEvent(
  foodType: FoodItemType.tea,
  mouthX: .5,
  mouthY: .52,
  timestamp: 2,
  isCatch: false,
);

void main() {
  test('one edible catch and no misses is 100 percent', () {
    final stats = GameStats.initial()
        .recordSpawn(FoodItemType.gold)
        .applyCollision(edibleCatch);
    expect(stats.totalFoodsSpawned, 1);
    expect(stats.catches, 1);
    expect(stats.accuracy, 1);
  });

  test('one edible miss and no catches is zero percent', () {
    final stats = GameStats.initial()
        .recordSpawn(FoodItemType.gold)
        .applyMiss();
    expect(stats.totalFoodsSpawned, 1);
    expect(stats.catches, 0);
    expect(stats.accuracy, 0);
  });

  test('catches and multiple misses use every edible spawn once', () {
    var stats = GameStats.initial();
    for (var index = 0; index < 3; index++) {
      stats = stats.recordSpawn(FoodItemType.teal);
    }
    stats = stats.applyCollision(
      const CollisionEvent(
        foodType: FoodItemType.teal,
        mouthX: .5,
        mouthY: .52,
        timestamp: 3,
        isCatch: true,
      ),
    );
    stats = stats.applyMiss().applyMiss();
    expect(stats.totalFoodsSpawned, 3);
    expect(stats.catches, 1);
    expect(stats.accuracy, closeTo(1 / 3, .000001));
  });

  test('multiple catches and misses remain within zero and one', () {
    var stats = GameStats.initial();
    for (var index = 0; index < 5; index++) {
      stats = stats.recordSpawn(FoodItemType.gold);
    }
    stats = stats.applyCollision(edibleCatch).applyCollision(edibleCatch);
    stats = stats.applyMiss().applyMiss().applyMiss();
    expect(stats.catches, 2);
    expect(stats.accuracy, .4);
    expect(stats.accuracy, inInclusiveRange(0, 1));
  });

  test('hazards hit or avoided never enter edible accuracy', () {
    var stats = GameStats.initial().recordSpawn(FoodItemType.gold);
    stats = stats.applyCollision(edibleCatch);
    stats = stats.recordSpawn(FoodItemType.tea);
    stats = stats.applyCollision(hazardHit);
    stats = stats.recordSpawn(FoodItemType.tea);
    expect(stats.totalFoodsSpawned, 1);
    expect(stats.hazardsHit, 1);
    expect(stats.accuracy, 1);
  });

  test('zero eligible edible attempts has neutral zero accuracy', () {
    final stats = GameStats.initial()
        .recordSpawn(FoodItemType.tea)
        .applyCollision(hazardHit);
    expect(stats.totalFoodsSpawned, 0);
    expect(stats.accuracy, 0);
  });

  test('duplicate control callbacks cannot catch one food twice', () {
    final game = GameSessionNotifier(profile: createTestPlayer);
    addTearDown(game.dispose);
    game.startGame();
    game.state = game.state.copyWith(
      stats: game.state.stats.recordSpawn(FoodItemType.gold),
      activeFoods: const [
        FoodItem(
          type: FoodItemType.gold,
          positionX: .5,
          positionY: .52,
          velocityX: 0,
          velocityY: 0,
          size: .08,
          creationTime: 0,
        ),
      ],
    );
    game.updateMouthTracking(isOpen: true, isActionable: true);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    game.updateMouthTracking(isOpen: false, isActionable: true);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    expect(game.state.stats.catches, 1);
    expect(game.state.stats.totalFoodsSpawned, 1);
    expect(game.state.stats.accuracy, 1);
  });

  test('pause and resume do not change attempt accounting', () {
    final game = GameSessionNotifier(profile: createTestPlayer);
    addTearDown(game.dispose);
    game.startGame();
    game.state = game.state.copyWith(
      stats: game.state.stats.recordSpawn(FoodItemType.gold),
    );
    game.pauseGame();
    game.resumeGame();
    expect(game.state.stats.totalFoodsSpawned, 1);
    expect(game.state.stats.accuracy, 0);
  });

  test('timer expiry accounts active edible items as misses', () async {
    final game = GameSessionNotifier(
      profile: createTestPlayer,
      sessionDuration: const Duration(milliseconds: 20),
    );
    addTearDown(game.dispose);
    game.startGame();
    game.state = game.state.copyWith(
      stats: game.state.stats
          .recordSpawn(FoodItemType.gold)
          .recordSpawn(FoodItemType.teal),
      activeFoods: const [
        FoodItem(
          type: FoodItemType.gold,
          positionX: .2,
          positionY: .2,
          velocityX: 0,
          velocityY: 0,
          size: .08,
          creationTime: 0,
        ),
        FoodItem(
          type: FoodItemType.teal,
          positionX: .8,
          positionY: .2,
          velocityX: 0,
          velocityY: 0,
          size: .08,
          creationTime: 0,
        ),
        FoodItem(
          type: FoodItemType.tea,
          positionX: .5,
          positionY: .2,
          velocityX: 0,
          velocityY: 0,
          size: .08,
          creationTime: 0,
        ),
      ],
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(game.state.completedRecord, isNotNull);
    expect(game.state.completedRecord!.accuracy, 0);
    expect(game.state.missCount, 2);
    expect(game.state.activeFoods, isEmpty);
  });
}
