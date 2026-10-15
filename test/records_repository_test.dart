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
