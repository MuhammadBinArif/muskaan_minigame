import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/audio/audio_service.dart';

import '../support/player_fixture.dart';

void main() {
  test('authoritative game events emit bounded semantic audio cues', () {
    final sounds = <Sound>[];
    final tracks = <String?>[];
    final game = GameSessionNotifier(
      profile: createTestPlayer,
      sound: sounds.add,
      music: tracks.add,
    );
    addTearDown(game.dispose);

    game.startGame(touchOnly: true);
    expect(sounds, contains(Sound.start));
    expect(tracks.last, 'gameplay');

    game.handleFoodCollision(_food(FoodItemType.gold), .5, .5);
    expect(sounds, containsAll(<Sound>[Sound.catchFood, Sound.bonus]));
    game.handleFoodCollision(_food(FoodItemType.teal), .5, .5);
    game.handleFoodCollision(_food(FoodItemType.teal), .5, .5);
    expect(sounds, contains(Sound.combo));
    game.pauseGame();
    expect(sounds.last, Sound.pause);
    expect(tracks.last, isNull);
    game.resumeGame();
    expect(sounds.last, Sound.resume);
    expect(tracks.last, 'gameplay');

    for (var hit = 0; hit < 3; hit++) {
      game.handleFoodCollision(_food(FoodItemType.tea), .5, .5);
    }
    expect(sounds, contains(Sound.hazard));
    expect(sounds, contains(Sound.gameOver));
    expect(tracks.last, 'results');
  });
}

FoodItem _food(FoodItemType type) => FoodItem(
  type: type,
  positionX: .5,
  positionY: .5,
  velocityX: 0,
  velocityY: 0,
  size: .08,
  creationTime: 0,
);
