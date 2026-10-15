import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';

class TestClock implements Stopwatch {
  int milliseconds = 0;
  bool running = false;
  @override
  bool get isRunning => running;
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  int get elapsedMicroseconds => milliseconds * 1000;
  @override
  Duration get elapsed => Duration(milliseconds: milliseconds);
  @override
  int get elapsedTicks => milliseconds * 1000;
  @override
  int get frequency => 1000000;
  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }

  @override
  void reset() {
    milliseconds = 0;
  }

  void advance(int ms) {
    if (running) milliseconds += ms;
  }
}

class RetryRepository implements GameRecordsRepository {
  bool fail = true;
  int calls = 0;
  final Map<int, GameSessionRecord> records = {};
  @override
  Future<void> saveSession(GameSessionRecord record) async {
    calls++;
    if (fail) throw StateError('disk temporarily unavailable');
    records[record.id] = record;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const food = FoodItem(
  type: FoodItemType.gold,
  positionX: .5,
  positionY: .52,
  velocityX: 0,
  velocityY: .25,
  size: .08,
  creationTime: 0,
);

void main() {
  test('food enters from above and reaches the mouth before expiry', () {
    var falling = const FoodItem(
      type: FoodItemType.gold,
      positionX: .5,
      positionY: -.1,
      velocityX: 0,
      velocityY: .25,
      size: .08,
      creationTime: 0,
    );
    for (var i = 0; i < 155; i++) {
      falling = falling.update(.016, 1, 1);
    }
    expect(falling.positionY, closeTo(.52, .001));
    expect(falling.velocityY, greaterThan(0));
    expect(falling.isActive(2480, 5000), isTrue);
  });

  test('pause stops elapsed time and restart clears food and collisions', () {
    final clock = TestClock();
    final game = GameSessionNotifier(clock: clock);
    addTearDown(game.dispose);
    game.startGame();
    clock.advance(2000);
    game.pauseGame();
    clock.advance(10000);
    expect(clock.elapsedMilliseconds, 2000);
    game.resumeGame();
    clock.advance(1000);
    expect(clock.elapsedMilliseconds, 3000);
    game.state = game.state.copyWith(activeFoods: [food]);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    game.quitGame();
    game.startGame();
    expect(game.state.activeFoods, isEmpty);
    expect(game.state.recentCollisions, isEmpty);
    expect(game.state.stats.score, 0);
    expect(game.state.stats.timeRemaining, 45);
  });

  test('one sustained opening consumes at most one food', () {
    final game = GameSessionNotifier();
    addTearDown(game.dispose);
    game.startGame();
    game.state = game.state.copyWith(activeFoods: [food, food]);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    expect(game.state.stats.catches, 1);
    expect(game.state.activeFoods, hasLength(1));
    game.updateMouthTracking(isOpen: false, isActionable: true);
    game.updateMouthTracking(isOpen: true, isActionable: true);
    expect(game.state.stats.catches, 2);
  });

  test('collision follows supplied mouth coordinates', () {
    final game = GameSessionNotifier();
    addTearDown(game.dispose);
    game.startGame();
    game.state = game.state.copyWith(activeFoods: [food]);
    game.updateMouthTracking(
      isOpen: true,
      isActionable: true,
      mouthX: .1,
      mouthY: .1,
    );
    expect(game.state.stats.catches, 0);
    game.updateMouthTracking(
      isOpen: true,
      isActionable: true,
      mouthX: .5,
      mouthY: .52,
    );
    expect(game.state.stats.catches, 1);
  });

  test(
    'failed save retries the same immutable session and preserves results',
    () async {
      final repo = RetryRepository();
      final game = GameSessionNotifier(repository: repo);
      addTearDown(game.dispose);
      game.startGame();
      game.quitGame();
      await game.persistCompletedSession();
      expect(game.state.saveError, isNotNull);
      final record = game.state.completedRecord!;
      expect(record.id, greaterThan(0));
      expect(record.state, GameSessionState.results);
      repo.fail = false;
      await Future.wait([
        game.persistCompletedSession(),
        game.persistCompletedSession(),
      ]);
      expect(repo.records, hasLength(1));
      expect(identical(repo.records.values.single, record), isTrue);
      expect(game.state.saveError, isNull);
      final calls = repo.calls;
      await game.persistCompletedSession();
      expect(repo.calls, calls);
    },
  );

  test('session identifiers are unique and completion preserves identity', () {
    final first = GameSessionRecord.create();
    final next = GameSessionRecord.create();
    expect(next.id, greaterThan(first.id));
    final completed = first.complete(
      finalScore: 10,
      finalLivesLost: 0,
      timePlayed: 2,
      finalBestCombo: 1,
      finalCatches: 1,
      finalAccuracy: 1,
      finalSmileScore: 50,
    );
    expect(completed.id, first.id);
    expect(completed.startedAt, first.startedAt);
  });
}
