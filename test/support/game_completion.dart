import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';

/// Completes a round through the production exhausted-lives terminal condition.
void completeRoundByExhaustingLives(GameSessionNotifier game) {
  while (game.state.state == GameSessionState.playing) {
    game.state = game.state.copyWith(
      activeFoods: const [
        FoodItem(
          type: FoodItemType.tea,
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
    game.updateMouthTracking(isOpen: false, isActionable: true);
  }
}
