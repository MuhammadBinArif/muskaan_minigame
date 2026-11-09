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
  @override
  Future<Map<String, dynamic>> load() async {
    if (fail) throw const FormatException('corrupt preferences');
    return data;
  }

  @override
  Future<void> save(Map<String, dynamic> value) async {
    data = value;
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
  test('duplicate effect bursts are bounded', () async {
    final backend = Backend();
    final audio = AudioService(backend, Preferences());
    await audio.initialize();
    audio.configure(master: true);
    for (var i = 0; i < 100; i++) {
      audio.play(Sound.catchFood);
    }
    expect(backend.effects, 1);
    audio.dispose();
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
