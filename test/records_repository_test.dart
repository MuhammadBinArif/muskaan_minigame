import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:sqlite3/open.dart';

void main() {
  late GameDatabase db;
  late GameRecordsRepository repo;

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'),
      );
    }
  });

  setUp(() {
    db = GameDatabase.forTesting(NativeDatabase.memory());
    repo = GameRecordsRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('GameRecordsRepository & Database tests', () {
    test('invalid writes are rejected without leaking record values', () async {
      final bad = GameSessionRecord.create().complete(
        finalScore: -500,
        finalLivesLost: 0,
        timePlayed: 30,
        finalBestCombo: 0,
        finalCatches: 0,
        finalAccuracy: double.infinity,
        finalSmileScore: 0,
      );
      await expectLater(
        repo.saveSession(bad),
        throwsA(isA<GameRepositoryException>()),
      );
      expect(await repo.getAllSessions(), isEmpty);
    });

    test('corrupt stored rows fail safely in reads and streams', () async {
      final record = GameSessionRecord.create().complete(
        finalScore: 100,
        finalLivesLost: 0,
        timePlayed: 30,
        finalBestCombo: 1,
        finalCatches: 1,
        finalAccuracy: 1,
        finalSmileScore: 20,
      );
      await repo.saveSession(record);
      await db.customStatement('UPDATE game_records SET accuracy = 2');
      final safeError = isA<GameRepositoryException>().having(
        (e) => e.toString(),
        'public message',
        isNot(contains('accuracy')),
      );
      await expectLater(repo.getAllSessions(), throwsA(safeError));
      await expectLater(repo.watchAllSessions().first, throwsA(safeError));
      await db.customStatement('UPDATE game_records SET state = 999');
      await expectLater(repo.getSessionById(record.id), throwsA(safeError));
      await repo.clearAllSessions();
      expect(await repo.getAllSessions(), isEmpty);
    });

    test('internal exception details are retained but not displayed', () {
      final error = StateError('PRIVATE_SENTINEL');
      final exception = GameRepositoryException(
        'Unable to load history.',
        error,
        StackTrace.current,
      );
      expect(exception.error, same(error));
      expect(exception.toString(), isNot(contains('PRIVATE_SENTINEL')));
    });
    test('saveSession persists a completed session and retrieves it', () async {
      final initialSessions = await repo.getAllSessions();
      expect(initialSessions, isEmpty);

      final record = GameSessionRecord(
        id: 0,
        score: 1250,
        livesLost: 1,
        maxLives: 3,
        timePlayed: 45,
        bestCombo: 6,
        catches: 15,
        accuracy: 0.88,
        smileScore: 90,
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        endedAt: DateTime.now(),
        state: GameSessionState.results,
        isNewBest: true,
      );

      await repo.saveSession(record);

      final sessions = await repo.getAllSessions();
      expect(sessions.length, 1);
      final saved = sessions.first;
      expect(saved.score, 1250);
      expect(saved.catches, 15);
      expect(saved.bestCombo, 6);
      expect(saved.accuracy, closeTo(0.88, 0.001));
      expect(saved.state, GameSessionState.results);
      expect(saved.isNewBest, isTrue);
    });

    test(
      'actual completed round is visible and repeated save is idempotent',
      () async {
        final record = GameSessionRecord.create().complete(
          finalScore: 600,
          finalLivesLost: 1,
          timePlayed: 30,
          finalBestCombo: 3,
          finalCatches: 6,
          finalAccuracy: .8,
          finalSmileScore: 90,
        );
        await repo.saveSession(record);
        await repo.saveSession(record);
        expect(await repo.getAllSessions(), hasLength(1));
        expect((await repo.getBestSession())!.id, record.id);
        expect((await repo.watchAllSessions().first).single.id, record.id);
      },
    );

    test('getBestSession returns the session with highest score', () async {
      final record1 = GameSessionRecord(
        id: 0,
        score: 500,
        livesLost: 2,
        maxLives: 3,
        timePlayed: 25,
        bestCombo: 3,
        catches: 6,
        accuracy: 0.6,
        smileScore: 50,
        startedAt: DateTime.now(),
        state: GameSessionState.results,
        isNewBest: false,
      );
      final record2 = GameSessionRecord(
        id: 0,
        score: 2200,
        livesLost: 0,
        maxLives: 3,
        timePlayed: 45,
        bestCombo: 12,
        catches: 25,
        accuracy: 0.95,
        smileScore: 98,
        startedAt: DateTime.now(),
        state: GameSessionState.results,
        isNewBest: true,
      );

      await repo.saveSession(record1);
      await repo.saveSession(record2);

      final best = await repo.getBestSession();
      expect(best, isNotNull);
      expect(best!.score, 2200);
      expect(best.bestCombo, 12);
    });

    test('clearAllSessions wipes all records', () async {
      final record = GameSessionRecord(
        id: 0,
        score: 300,
        livesLost: 3,
        maxLives: 3,
        timePlayed: 10,
        bestCombo: 1,
        catches: 3,
        accuracy: 0.5,
        smileScore: 30,
        startedAt: DateTime.now(),
        state: GameSessionState.results,
        isNewBest: false,
      );
      await repo.saveSession(record);
      expect((await repo.getAllSessions()).length, 1);

      await repo.clearAllSessions();
      expect(await repo.getAllSessions(), isEmpty);
      expect(await repo.getBestSession(), isNull);
    });
  });
}
