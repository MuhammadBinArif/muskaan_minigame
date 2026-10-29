import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/domain/face_game_control.dart';
import 'package:muskaan_minigame/features/game/presentation/flame/muskaan_flame_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('external movement and catch request reach the gameplay callback', () {
    (bool, bool, double)? frame;
    final game = MuskaanFlameGame(
      controlConfig: const FaceGameControlConfig(
        neutralX: .5,
        horizontalRange: .22,
      ),
      onControlFrame: (request, ready, x) => frame = (request, ready, x),
      onControlStatusChanged: (_) {},
    );
    game.onGameResize(Vector2(400, 800));
    game.syncSession(
      foods: const [],
      recentCollisions: const [],
      isPlaying: true,
    );
    game.setMovementInput(.8, faceReady: true);
    game.setMouthOpen(true);
    game.update(.016);
    expect(frame!.$1, isTrue);
    expect(frame!.$2, isTrue);
    expect(frame!.$3, closeTo(.8, .001));
    game.setMovementInput(.8, faceReady: false);
    game.update(.016);
    expect(frame!.$2, isFalse);
    game.avatar.dispose();
  });

  test(
    'game renders supplied food artwork and releases its drawing cache',
    () async {
      final game = createGame();
      game.onGameResize(Vector2(400, 800));
      game.syncSession(
        foods: [
          for (final type in FoodItemType.values)
            FoodItem(
              type: type,
              positionX: .25 + type.index * .25,
              positionY: .2,
              velocityX: 0,
              velocityY: 0,
              size: .1,
              creationTime: 1,
            ),
        ],
        recentCollisions: const [],
        isPlaying: false,
      );
      for (var i = 0; i < 2; i++) {
        final recorder = ui.PictureRecorder();
        game.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 250);
        final bytes = await image.toByteData();
        expect(bytes!.buffer.asUint8List().any((b) => b != 0), isTrue);
        image.dispose();
        picture.dispose();
        game.onRemove();
      }
      game.avatar.dispose();
    },
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
