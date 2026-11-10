import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:muskaan_minigame/features/audio/audio_service.dart';

class Backend implements AudioBackend {
  String? track;
  double musicVolume = 0;
  int effects = 0;
  int silenced = 0;
  bool closed = false;
  bool fail = false;
  @override
  Future<void> music(String? value, double volume) async {
    if (fail) throw StateError('backend unavailable');
    track = value;
    musicVolume = volume;
  }

  @override
  Future<void> effect(Sound sound, double volume) async {
    if (fail) throw StateError('missing asset');
    effects++;
  }

  @override
  Future<void> silenceEffects() async {
    silenced++;
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }
}

class Preferences implements AudioPreferences {
  Map<String, dynamic> data = {};
  bool fail = false;
  int loads = 0;
  @override
  Future<Map<String, dynamic>> load() async {
    loads++;
    if (fail) throw const FormatException('corrupt preferences');
    return data;
  }

  @override
  Future<void> save(Map<String, dynamic> value) async {
    data = value;
  }
}

class EffectPlayer implements EffectPlayback {
  final completedController = StreamController<void>.broadcast(sync: true);
  int plays = 0;
  int stops = 0;
  int disposals = 0;
  bool fail = false;

  @override
  Stream<void> get completed => completedController.stream;

  @override
  Future<void> play(String asset, double volume) async {
    if (fail) throw StateError('missing asset');
    plays++;
  }

  void complete() => completedController.add(null);

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await completedController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('opt-in mute, preferences, music switching and lifecycle', () async {
    final backend = Backend();
    final prefs = Preferences();
    final audio = AudioService(backend, prefs);
    await audio.initialize();
    audio.play(Sound.catchFood);
    expect(backend.effects, 0);
    audio.configure(master: true);
    audio.selectMusic('gameplay');
    await audio.settled;
    expect(backend.track, 'gameplay');
    audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    await audio.settled;
    expect(backend.track, isNull);
    expect(backend.silenced, 1);
    audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await audio.settled;
    expect(backend.track, 'gameplay');
    final restored = AudioService(Backend(), prefs);
    await restored.initialize();
    expect(restored.enabled, isTrue);
    audio.dispose();
    restored.dispose();
  });
  test('two rapid effects use independent players without truncation', () async {
    final players = <EffectPlayer>[];
    final pool = EffectPlayerPool(
      size: 2,
      createPlayer: () {
        final player = EffectPlayer();
        players.add(player);
        return player;
      },
    );
    expect(await pool.play(Sound.catchFood, .6), isTrue);
    expect(await pool.play(Sound.bonus, .6), isTrue);
    expect(players.map((player) => player.plays), [1, 1]);
    expect(players.every((player) => player.stops == 0), isTrue);
    await pool.dispose();
  });

  test('completed players are reused', () async {
    final players = <EffectPlayer>[];
    final pool = EffectPlayerPool(
      size: 1,
      createPlayer: () {
        final player = EffectPlayer();
        players.add(player);
        return player;
      },
    );
    expect(await pool.play(Sound.catchFood, .6), isTrue);
    expect(await pool.play(Sound.combo, .6), isFalse);
    players.single.complete();
    expect(await pool.play(Sound.combo, .6), isTrue);
    expect(players.single.plays, 2);
    await pool.dispose();
  });

  test('pool exhaustion drops incoming effects and never grows', () async {
    final players = <EffectPlayer>[];
    final pool = EffectPlayerPool(
      size: 4,
      createPlayer: () {
        final player = EffectPlayer();
        players.add(player);
        return player;
      },
    );
    final accepted = <bool>[];
    for (var index = 0; index < 100; index++) {
      accepted.add(await pool.play(Sound.catchFood, .6));
    }
    expect(accepted.where((value) => value), hasLength(4));
    expect(players, hasLength(4));
    expect(pool.capacity, 4);
    expect(pool.activeCount, 4);
    await pool.dispose();
  });

  test('master and independent controls apply immediately', () async {
    final backend = Backend();
    final audio = AudioService(backend, Preferences());
    await audio.initialize();
    audio.configure(master: true, musicLevel: .4, effectsLevel: .7);
    await audio.settled;
    expect(backend.track, 'menu');
    expect(backend.musicVolume, .4);
    audio.configure(music: false);
    await audio.settled;
    expect(backend.track, isNull);
    audio.play(Sound.catchFood);
    expect(backend.effects, 1);
    audio.configure(music: true, effects: false);
    await audio.settled;
    expect(backend.track, 'menu');
    audio.play(Sound.hazard);
    expect(backend.effects, 1);
    audio.configure(master: false);
    audio.play(Sound.hazard);
    expect(backend.effects, 1);
    audio.dispose();
  });

  test('backend and corrupt preference failures do not escape', () async {
    final backend = Backend()..fail = true;
    final preferences = Preferences()..fail = true;
    final audio = AudioService(backend, preferences);
    await audio.initialize();
    expect(audio.error, isNotNull);
    audio.configure(master: true);
    await audio.settled;
    audio.play(Sound.start);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(audio.error, isNotNull);
    audio.dispose();
  });

  test('missing effect assets free the slot for later playback', () async {
    final player = EffectPlayer()..fail = true;
    final pool = EffectPlayerPool(size: 1, createPlayer: () => player);
    await expectLater(
      pool.play(Sound.catchFood, .6),
      throwsA(isA<StateError>()),
    );
    expect(pool.activeCount, 0);
    player.fail = false;
    expect(await pool.play(Sound.catchFood, .6), isTrue);
    await pool.dispose();
  });

  test('dispose releases the backend after pending work', () async {
    final backend = Backend();
    final audio = AudioService(backend, Preferences());
    await audio.initialize();
    audio.configure(master: true);
    await audio.settled;
    audio.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(backend.closed, isTrue);
  });

  test('initialization is idempotent', () async {
    final preferences = Preferences();
    final audio = AudioService(Backend(), preferences);
    await Future.wait([audio.initialize(), audio.initialize()]);
    expect(preferences.loads, 1);
    audio.dispose();
  });

  test('pool disposal is idempotent and a new pool can initialize', () async {
    final firstPlayer = EffectPlayer();
    final first = EffectPlayerPool(size: 1, createPlayer: () => firstPlayer);
    await first.dispose();
    await first.dispose();
    expect(firstPlayer.disposals, 1);
    expect(await first.play(Sound.tap, .6), isFalse);

    final secondPlayer = EffectPlayer();
    final second = EffectPlayerPool(size: 1, createPlayer: () => secondPlayer);
    expect(await second.play(Sound.tap, .6), isTrue);
    await second.dispose();
  });

  test('persisted rewards map to their dedicated cues', () {
    expect(
      persistedRewardSounds(
        personalBest: true,
        achievementUnlocked: true,
        challengeCompleted: true,
        levelIncreased: true,
        cosmeticUnlocked: true,
      ),
      <Sound>[
        Sound.best,
        Sound.achievement,
        Sound.challenge,
        Sound.level,
        Sound.cosmetic,
      ],
    );
  });

  test('route music policy selects exactly one appropriate track', () {
    expect(musicTrackForPath('/home'), 'menu');
    expect(musicTrackForPath('/game'), 'gameplay');
    expect(musicTrackForPath('/results'), 'results');
    expect(musicTrackForPath('/pause'), isNull);
  });
}
