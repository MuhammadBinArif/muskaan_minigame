import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/game/presentation/flame/avatar_presentation.dart';
import 'package:muskaan_minigame/features/profile/domain/profile_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session_regression_test.dart' show TestClock;

class AvatarRepository implements ProfileAvatarRepository {
  final changes = StreamController<ProfileAvatar?>();
  @override
  Stream<ProfileAvatar?> watchAvatar() => changes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('avatar selection persists and is restored safely', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PreferencesProfileAvatarRepository();
    await first.selectAvatar(const ProfileAvatar('👩🏽'));
    await first.dispose();
    final second = PreferencesProfileAvatarRepository();
    expect((await second.watchAvatar().first)?.symbol, '👩🏽');
    await second.dispose();
    SharedPreferences.setMockInitialValues({
      PreferencesProfileAvatarRepository.key: 'invalid',
    });
    final invalid = PreferencesProfileAvatarRepository();
    expect(await invalid.watchAvatar().first, isNull);
    await invalid.dispose();
  });
  test(
    'repository selection, live changes, missing and failed reads',
    () async {
      final repository = AvatarRepository();
      final container = ProviderContainer(
        overrides: [
          profileAvatarRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(profileAvatarProvider, (_, _) {});
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '🥷',
      );
      repository.changes.add(const ProfileAvatar('🐱'));
      await Future<void>.delayed(Duration.zero);
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '🐱',
      );
      repository.changes.add(const ProfileAvatar('🦊'));
      await Future<void>.delayed(Duration.zero);
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '🦊',
      );
      repository.changes.add(const ProfileAvatar('\n'));
      await Future<void>.delayed(Duration.zero);
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '🥷',
      );
      repository.changes.addError(StateError('unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '🥷',
      );
      subscription.close();
      container.dispose();
      expect(repository.changes.hasListener, isFalse);
      await repository.changes.close();
    },
  );

  test('catch, combo, hazard, miss, terminal transition and deduplication', () {
    final avatar = AvatarPresentation();
    addTearDown(avatar.dispose);
    var state = GameSessionStateData.initial().copyWith(
      state: GameSessionState.playing,
    );
    avatar.sync(state);
    for (var i = 1; i <= 3; i++) {
      state = state.copyWith(
        stats: state.stats.applyCollision(
          const CollisionEvent(
            foodType: FoodItemType.gold,
            mouthX: .5,
            mouthY: .52,
            timestamp: 0,
            isCatch: true,
          ),
        ),
      );
      avatar.sync(state);
      expect(
        avatar.reaction,
        i == 3 ? AvatarReaction.combo : AvatarReaction.catchFood,
      );
      avatar.update(.2);
      avatar.sync(state);
      expect(avatar.age, .2);
    }
    expect(state.stats.score, 300);
    state = state.copyWith(missCount: 1, stats: state.stats.applyMiss());
    avatar.sync(state);
    expect(avatar.reaction, AvatarReaction.miss);
    avatar.update(.6);
    expect(avatar.reaction, AvatarReaction.idle);
    state = state.copyWith(missCount: 2);
    avatar.sync(state);
    expect(avatar.reaction, AvatarReaction.miss);
    state = state.copyWith(
      stats: state.stats.applyCollision(
        const CollisionEvent(
          foodType: FoodItemType.tea,
          mouthX: .5,
          mouthY: .52,
          timestamp: 0,
          isCatch: false,
        ),
      ),
    );
    avatar.sync(state);
    expect(avatar.reaction, AvatarReaction.miss);
    expect(state.stats.lives, 2);
    avatar.sync(state.copyWith(state: GameSessionState.gameOver));
    avatar.update(.3);
    avatar.sync(
      state.copyWith(state: GameSessionState.gameOver, isSaving: true),
    );
    expect(avatar.reaction, AvatarReaction.gameOver);
    expect(avatar.age, .3);
  });

  test('pause freezes, reduced motion suppresses scale, restart resets', () {
    final avatar = AvatarPresentation();
    addTearDown(avatar.dispose);
    avatar.update(.2);
    avatar.sync(
      GameSessionStateData.initial().copyWith(state: GameSessionState.paused),
    );
    avatar.update(5);
    expect(avatar.age, .2);
    avatar.reducedMotion = true;
    expect(avatar.scale, 1);
    avatar.sync(GameSessionStateData.initial());
    expect(avatar.age, 0);
    expect(avatar.reaction, AvatarReaction.idle);
    expect(avatar.paused, isFalse);
  });

  test(
    'portrait renders pixels and can be replaced and disposed safely',
    () async {
      final avatar = AvatarPresentation();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      avatar.render(canvas, const ui.Offset(64, 64), 50);
      avatar.setAvatar(const ProfileAvatar('🐱'));
      avatar.render(canvas, const ui.Offset(64, 64), 50);
      final picture = recorder.endRecording();
      final image = await picture.toImage(128, 128);
      final bytes = await image.toByteData();
      expect(bytes!.buffer.asUint8List().any((byte) => byte != 0), isTrue);
      image.dispose();
      picture.dispose();
      avatar.dispose();
      avatar.dispose();
      avatar.update(1);
      avatar.setAvatar(const ProfileAvatar('🦊'));
    },
  );

  test('saved avatar styles produce distinct gameplay portraits', () async {
    final avatar = AvatarPresentation()..reducedMotion = true;
    Future<List<int>> render(int index) async {
      avatar.setAvatar(ProfileAvatar(ProfileAvatar.options[index]));
      final recorder = ui.PictureRecorder();
      avatar.render(ui.Canvas(recorder), const ui.Offset(64, 64), 50);
      final picture = recorder.endRecording();
      final image = await picture.toImage(128, 128);
      final bytes =
          (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return bytes;
    }

    final first = await render(0);
    final same = await render(0);
    final different = await render(3);
    expect(first, same);
    expect(first, isNot(different));
    avatar.dispose();
  });

  testWidgets(
    'actual falling miss emits once without changing score or lives',
    (tester) async {
      final clock = TestClock();
      final game = GameSessionNotifier(clock: clock);
      game.startGame();
      game.state = game.state.copyWith(
        activeFoods: [
          const FoodItem(
            type: FoodItemType.gold,
            positionX: .5,
            positionY: 1.07,
            velocityX: 0,
            velocityY: .25,
            size: .08,
            creationTime: 0,
          ),
        ],
      );
      clock.advance(100);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.state.missCount, 1);
      expect(game.state.stats.score, 0);
      expect(game.state.stats.lives, 3);
      clock.advance(100);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.state.missCount, 1);
      game.dispose();
    },
  );
}
