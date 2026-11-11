import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:muskaan_minigame/features/game/data/game_database.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';
import 'package:muskaan_minigame/features/profile/data/player_profile_repository.dart';
import 'package:muskaan_minigame/features/profile/domain/player_profile.dart';
import 'package:muskaan_minigame/features/profile/domain/profile_avatar.dart';
import 'package:muskaan_minigame/core/providers/game_session_provider.dart';
import 'package:muskaan_minigame/features/smile/domain/smile_measurement.dart';
import '../support/player_fixture.dart';
import '../support/game_completion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    if (Platform.isLinux)
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
  });
  test(
    'generated identity persists, restores and keeps ID after Unicode name edits',
    () async {
      final db = GameDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = PlayerProfileRepository(db);
      final first = await repository.loadOrCreate();
      expect(first.id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(
        first.displayName,
        matches(RegExp(r'^[A-Za-z]+ [A-Za-z]+ [0-9]{4}$')),
      );
      final restored = await PlayerProfileRepository(db).loadOrCreate();
      expect(restored.toJson(), first.toJson());
      await repository.save(
        first.copyWith(displayName: '  مسکان 王 👨‍👩‍👧  ', avatar: '👩🏽'),
      );
      final edited = await repository.loadOrCreate();
      expect(edited.id, first.id);
      expect(edited.createdAt, first.createdAt);
      expect(edited.displayName, 'مسکان 王 👨‍👩‍👧');
      expect(edited.avatar, '👩🏽');
    },
  );
  test(
    'name validation rejects invalid inputs and permits international names',
    () {
      for (final name in [
        '',
        '   ',
        'a' * 31,
        'Alice\nBob',
        '\u202EHidden',
        '\u0000',
      ]) {
        expect(() => validatePlayerName(name), throwsFormatException);
      }
      expect(validatePlayerName('  Élodie 王  '), 'Élodie 王');
      expect(validatePlayerName('👨‍👩‍👧' * 10), '👨‍👩‍👧' * 10);
    },
  );
  test(
    'corrupt saved profile fails safely without silently replacing it',
    () async {
      final db = GameDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = PlayerProfileRepository(db);
      await repository.loadOrCreate();
      await db.customStatement('UPDATE player_profile SET payload = ?', [
        '{"id":"broken"}',
      ]);
      await expectLater(repository.loadOrCreate(), throwsA(anything));
      final row =
          await db
              .customSelect('SELECT payload FROM player_profile')
              .getSingle();
      expect(jsonDecode(row.read<String>('payload')), {'id': 'broken'});
    },
  );
  test(
    'reactive edits and avatar propagate; failed writes retain last valid state',
    () async {
      final repository = MemoryPlayerRepository();
      final container = ProviderContainer(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ready;
      final seen = <String>[];
      container.listen(playerProfileProvider, (_, next) {
        if (next.hasValue) seen.add(next.requireValue.displayName);
      });
      final avatarSubscription = container.listen(
        profileAvatarProvider,
        (_, _) {},
      );
      addTearDown(avatarSubscription.close);
      final controller = container.read(playerProfileProvider.notifier);
      await controller.update(name: 'Smile King');
      await controller.update(avatar: '👩🏽');
      await Future<void>.delayed(Duration.zero);
      expect(seen, contains('Smile King'));
      expect(
        resolveAvatarState(container.read(profileAvatarProvider)).symbol,
        '👩🏽',
      );
      expect(
        container.read(playerProfileProvider).requireValue.id,
        repository.saved.id,
      );
      repository.failWrites = true;
      await expectLater(
        controller.update(name: 'Lost update'),
        throwsStateError,
      );
      expect(
        container.read(playerProfileProvider).requireValue.displayName,
        'Smile King',
      );
      await expectLater(controller.update(name: ' '), throwsFormatException);
    },
  );
  test('separate repositories do not share generated identity state', () async {
    final a = GameDatabase.forTesting(NativeDatabase.memory());
    final b = GameDatabase.forTesting(NativeDatabase.memory());
    addTearDown(a.close);
    addTearDown(b.close);
    final one = await PlayerProfileRepository(a).loadOrCreate();
    final two = await PlayerProfileRepository(b).loadOrCreate();
    expect(one.id, isNot(two.id));
  });
  test(
    'round captures stable ownership and measured raw average; scoring stays collision driven',
    () async {
      final db = GameDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      var player = await PlayerProfileRepository(db).loadOrCreate();
      final repository = GameRecordsRepositoryImpl(db);
      final game = GameSessionNotifier(
        repository: repository,
        profile: () => player,
      );
      addTearDown(game.dispose);
      game.startGame();
      expect(game.activePlayerId, player.id);
      game.pauseGame();
      expect(game.activePlayerId, player.id);
      game.resumeGame();
      expect(game.activePlayerId, player.id);
      final engine = SmileMeasurementEngine(
        calibration: const SmileCalibration(
          neutralProbability: .18,
          naturalSmileProbability: .83,
        ),
      );
      final time = DateTime.now().subtract(const Duration(milliseconds: 30));
      for (var i = 0; i < 3; i++) {
        final at = time.add(Duration(milliseconds: i));
        game.observeSmile(
          engine.observe(
            [.18, .47, .83][i],
            capturedAt: at,
            now: DateTime.now(),
          ),
        );
      }
      expect(game.state.stats.score, 0);
      player = player.copyWith(displayName: 'Smile King', avatar: '👩🏽');
      completeRoundByExhaustingLives(game);
      await game.persistCompletedSession();
      final record = (await repository.getAllSessions()).single;
      expect(record.playerId, player.id);
      expect(record.playerName, 'Smile King');
      expect(record.playerAvatar, '👩🏽');
      expect(record.smileSampleCount, 3);
      expect(
        record.averageSmileProbability,
        closeTo((.18 + .47 + .83) / 3, .0001),
      );
      expect(record.peakSmileProbability, .83);
      expect(record.calibratedSmileAttempted, isTrue);
      expect(record.calibratedSmileSampleCount, 3);
      expect(
        record.averageCalibratedSmileIntensity,
        closeTo((0 + ((.47 - .18) / (.83 - .18) * 100) + 100) / 3, .0001),
      );
      expect(record.peakCalibratedSmileIntensity, 100);
    },
  );
  test(
    'actual profile provider change cannot alter failed result ownership on retry',
    () async {
      final db = GameDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final profiles = PlayerProfileRepository(db);
      final records = GameRecordsRepositoryImpl(db);
      final container = ProviderContainer(
        overrides: [
          playerProfileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ready;
      final playerA = container.read(playerProfileProvider).requireValue;
      final game = GameSessionNotifier(
        repository: records,
        profile: () => container.read(playerProfileProvider).requireValue,
      );
      addTearDown(game.dispose);
      game.startGame();
      expect(game.activePlayerId, playerA.id);
      game.pauseGame();
      expect(game.activePlayerId, playerA.id);
      game.resumeGame();
      expect(game.activePlayerId, playerA.id);
      await db.customStatement(
        "CREATE TRIGGER fail_first_result BEFORE INSERT ON game_records BEGIN SELECT RAISE(FAIL, 'forced insert failure'); END",
      );
      completeRoundByExhaustingLives(game);
      await game.persistCompletedSession();
      final original = game.state.completedRecord!;
      expect(original.playerId, playerA.id);
      expect(await records.getAllSessions(), isEmpty);

      await db.customStatement('DROP TRIGGER fail_first_result');
      final playerB = PlayerProfile(
        id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        displayName: 'Player B',
        avatar: '🧑🏽',
        createdAt: DateTime.utc(2026, 2),
        updatedAt: DateTime.utc(2026, 2),
        onboarded: true,
      );
      await profiles.save(playerB);
      await container.read(playerProfileProvider.notifier).retryLoad();
      expect(container.read(playerProfileProvider).requireValue.id, playerB.id);

      await Future.wait([
        game.persistCompletedSession(),
        game.persistCompletedSession(),
      ]);
      final saved = await records.getAllSessions();
      expect(saved, hasLength(1));
      expect(saved.single.playerId, playerA.id);
      expect(saved.single.id, original.id);
      expect(saved.single.score, original.score);
      expect(saved.single.startedAt, original.startedAt);
      expect(saved.single.state, original.state);
      final count =
          await db
              .customSelect('SELECT COUNT(*) AS count FROM game_records')
              .getSingle();
      expect(count.read<int>('count'), 1);
    },
  );
}
