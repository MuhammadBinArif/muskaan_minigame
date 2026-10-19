import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';
import 'package:muskaan_minigame/features/game/presentation/flame/muskaan_flame_game.dart';

void main() {
  MuskaanFlameGame createGame() => MuskaanFlameGame(
    controlConfig: const FaceGameControlConfig(
      neutralX: .5,
      horizontalRange: .22,
    ),
    onControlFrame: (_, _, _) {},
    onControlStatusChanged: (_) {},
  );

  const catchEvent = CollisionEvent(
    foodType: FoodItemType.gold,
    mouthX: .5,
    mouthY: .52,
    timestamp: 10,
    isCatch: true,
  );

  test(
    'collision feedback is event-driven, bounded, and reset with control',
    () {
      final game = createGame();
      game.syncSession(
        foods: const [],
        recentCollisions: const [],
        isPlaying: false,
      );
      expect(game.hasActiveFeedback, isFalse);

      game.syncSession(
        foods: const [],
        recentCollisions: const [catchEvent],
        isPlaying: false,
      );
      expect(game.hasActiveFeedback, isTrue);
      game.update(.3);
      game.syncSession(
        foods: const [],
        recentCollisions: const [catchEvent],
        isPlaying: false,
      );
      game.update(.36);
      expect(game.hasActiveFeedback, isFalse);

      game.syncSession(
        foods: const [],
        recentCollisions: const [catchEvent],
        isPlaying: false,
      );
      expect(game.hasActiveFeedback, isFalse);
      game.resetControl();
      expect(game.hasActiveFeedback, isFalse);
    },
  );

  test('a distinct hazard event starts its own short feedback window', () {
    final game = createGame();
    game.syncSession(
      foods: const [],
      recentCollisions: const [catchEvent],
      isPlaying: false,
    );
    game.update(.65);
    const hazard = CollisionEvent(
      foodType: FoodItemType.tea,
      mouthX: .4,
      mouthY: .52,
      timestamp: 11,
      isCatch: false,
    );
    game.syncSession(
      foods: const [],
      recentCollisions: const [hazard, catchEvent],
      isPlaying: false,
    );
    expect(game.hasActiveFeedback, isTrue);
  });
}
