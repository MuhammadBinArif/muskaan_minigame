import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';

import '../support/game_completion.dart';
import '../support/player_fixture.dart';

GameSessionRecord completed({
  required int id,
  required String playerId,
  required int score,
  bool smile = false,
  bool touch = true,
}) => GameSessionRecord(
  playerId: playerId,
  playerName: 'Player',
  playerAvatar: '🥷',
  id: id,
  score: score,
  livesLost: 0,
  maxLives: 3,
  timePlayed: 45,
  bestCombo: 0,
  catches: 0,
  accuracy: 0,
  smileScore: 0,
  usedSmileMode: smile,
  usedTouchMode: touch,
  startedAt: DateTime.utc(2026, 1, 1, 0, 0, id),
  endedAt: DateTime.utc(2026, 1, 1, 0, 1, id),
  state: GameSessionState.results,
  isNewBest: false,
);

void main() {
  const playerA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const playerB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late GameDatabase database;
  late GameRecordsRepositoryImpl repository;

  setUp(() {
    database = GameDatabase.forTesting(NativeDatabase.memory());
    repository = GameRecordsRepositoryImpl(database);
  });

  tearDown(() => database.close());

  test('first, higher, equal and lower scores have canonical flags', () async {
    final first = await repository.saveSession(
      completed(id: 1, playerId: playerA, score: 0),
    );
    final higher = await repository.saveSession(
      completed(id: 2, playerId: playerA, score: 200),
    );
    final equal = await repository.saveSession(
      completed(id: 3, playerId: playerA, score: 200),
    );
    final lower = await repository.saveSession(
      completed(id: 4, playerId: playerA, score: 100),
    );

    expect(first.isNewBest, isTrue);
    expect(higher.isNewBest, isTrue);
    expect(equal.isNewBest, isFalse);
    expect(lower.isNewBest, isFalse);
    expect(
      (await repository.getAllSessions()).map((record) => record.isNewBest),
      containsAll(<bool>[true, true, false, false]),
    );
  });

  test('different players have independent personal bests', () async {
    final a = await repository.saveSession(
      completed(id: 1, playerId: playerA, score: 500),
    );
    final b = await repository.saveSession(
      completed(id: 2, playerId: playerB, score: 10),
    );
    expect(a.isNewBest, isTrue);
    expect(b.isNewBest, isTrue);
  });

  test('Smile, Touch and mixed rounds share the existing score board', () async {
    final touch = await repository.saveSession(
      completed(id: 1, playerId: playerA, score: 100),
    );
    final smile = await repository.saveSession(
      completed(
        id: 2,
        playerId: playerA,
        score: 90,
        smile: true,
        touch: false,
      ),
    );
    final mixed = await repository.saveSession(
      completed(
        id: 3,
        playerId: playerA,
        score: 110,
        smile: true,
      ),
    );
    expect(touch.isNewBest, isTrue);
    expect(smile.isNewBest, isFalse);
    expect(mixed.isNewBest, isTrue);
  });

  test('retry is idempotent and persisted flag survives reload', () async {
    final record = completed(id: 7, playerId: playerA, score: 300);
    final first = await repository.saveSession(record);
    await repository.saveSession(
      completed(id: 8, playerId: playerA, score: 400),
    );
    final retry = await repository.saveSession(record);
    final reloaded = await repository.getSessionById(record.id);
    expect(first.isNewBest, isTrue);
    expect(retry.isNewBest, isTrue);
    expect(reloaded!.isNewBest, isTrue);
    expect(await repository.getAllSessions(), hasLength(2));
  });

  test('session state receives the same canonical flag as SQLite', () async {
    final game = GameSessionNotifier(
      repository: repository,
      profile: createTestPlayer,
    );
    addTearDown(game.dispose);
    game.startGame();
    completeRoundByExhaustingLives(game);
    await game.persistCompletedSession();
    final persisted = await repository.getSessionById(
      game.state.completedRecord!.id,
    );
    expect(game.state.completedRecord!.isNewBest, isTrue);
    expect(persisted!.isNewBest, game.state.completedRecord!.isNewBest);
  });

  test('concurrent equal scores cannot both become personal bests', () async {
    final saved = await Future.wait([
      repository.saveSession(
        completed(id: 1, playerId: playerA, score: 100),
      ),
      repository.saveSession(
        completed(id: 2, playerId: playerA, score: 100),
      ),
    ]);
    expect(saved.where((record) => record.isNewBest), hasLength(1));
    expect(await repository.getAllSessions(), hasLength(2));
  });

  test('incomplete records never establish a personal best', () async {
    final incomplete = GameSessionRecord(
      playerId: playerA,
      playerName: 'Player',
      playerAvatar: '🥷',
      id: 1,
      score: 999,
      livesLost: 0,
      maxLives: 3,
      timePlayed: 1,
      bestCombo: 0,
      catches: 0,
      accuracy: 0,
      smileScore: 0,
      startedAt: DateTime.utc(2026),
      state: GameSessionState.results,
      isNewBest: false,
    );
    final saved = await repository.saveSession(incomplete);
    final firstCompleted = await repository.saveSession(
      completed(id: 2, playerId: playerA, score: 1),
    );
    expect(saved.isNewBest, isFalse);
    expect(firstCompleted.isNewBest, isTrue);
  });

  test('metadata failure rolls back score and personal-best writes', () async {
    await database.customStatement(
      "CREATE TRIGGER fail_statistics_metadata BEFORE INSERT ON session_details BEGIN SELECT RAISE(FAIL, 'forced metadata failure'); END",
    );
    await expectLater(
      repository.saveSession(
        completed(id: 1, playerId: playerA, score: 100),
      ),
      throwsA(isA<GameRepositoryException>()),
    );
    expect(await repository.getAllSessions(), isEmpty);
    final count = await database
        .customSelect('SELECT COUNT(*) AS count FROM game_records')
        .getSingle();
    expect(count.read<int>('count'), 0);
  });
}
