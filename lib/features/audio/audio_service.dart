import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum Sound {
  catchFood,
  miss,
  hazard,
  combo,
  bonus,
  countdown,
  start,
  pause,
  resume,
  gameOver,
  best,
  achievement,
  challenge,
  level,
  cosmetic,
  tap,
}

List<Sound> persistedRewardSounds({
  required bool personalBest,
  required bool achievementUnlocked,
  required bool challengeCompleted,
  required bool levelIncreased,
  required bool cosmeticUnlocked,
}) => <Sound>[
  if (personalBest) Sound.best,
  if (achievementUnlocked) Sound.achievement,
  if (challengeCompleted) Sound.challenge,
  if (levelIncreased) Sound.level,
  if (cosmeticUnlocked) Sound.cosmetic,
];

String? musicTrackForPath(String path) => switch (path) {
  '/game' || '/games' => 'gameplay',
  '/game-over' || '/results' || '/share' => 'results',
  '/pause' => null,
  _ => 'menu',
};

abstract class AudioBackend {
  Future<void> music(String? track, double volume);
  Future<void> effect(Sound sound, double volume);
  Future<void> silenceEffects();
  Future<void> dispose();
}

class PlayerAudioBackend implements AudioBackend {
  final _music = AudioPlayer();
  final _effects = AudioPlayer();
  String? _track;
  double _appliedMusicVolume = 0;
  bool _musicPlaying = false;

  Future<void> _fadeTo(double target) async {
    final start = _appliedMusicVolume;
    const steps = 8;
    for (var step = 1; step <= steps; step++) {
      final value = start + (target - start) * step / steps;
      await _music.setVolume(value);
      _appliedMusicVolume = value;
      await Future<void>.delayed(const Duration(milliseconds: 18));
    }
  }

  @override
  Future<void> music(String? track, double volume) async {
    if (track == null || volume == 0) {
      if (_musicPlaying) {
        await _fadeTo(0);
        await _music.pause();
        _musicPlaying = false;
      }
      return;
    }
    if (_track != track) {
      if (_musicPlaying) await _fadeTo(0);
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource('audio/music/$track.wav'), volume: 0);
      _track = track;
      _appliedMusicVolume = 0;
      _musicPlaying = true;
      await _fadeTo(volume);
    } else {
      if (!_musicPlaying) {
        await _music.resume();
        _musicPlaying = true;
      }
      await _fadeTo(volume);
    }
  }

  @override
  Future<void> effect(Sound sound, double volume) async {
    await _effects.stop();
    await _effects.play(
      AssetSource('audio/sfx/${sound.name}.wav'),
      volume: volume,
    );
  }

  @override
  Future<void> silenceEffects() => _effects.stop();

  @override
  Future<void> dispose() async {
    await _music.dispose();
    await _effects.dispose();
  }
}

abstract class AudioPreferences {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> value);
}

class FileAudioPreferences implements AudioPreferences {
  Future<File> get _file async =>
      File('${(await getApplicationSupportDirectory()).path}/audio.json');
  @override
  Future<Map<String, dynamic>> load() async {
    final file = await _file;
    if (!await file.exists()) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> value) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }
}

class AudioService extends ChangeNotifier with WidgetsBindingObserver {
  AudioService(this.backend, this.preferences);
  final AudioBackend backend;
  final AudioPreferences preferences;
  bool enabled = false, musicEnabled = true, effectsEnabled = true;
  double musicVolume = .35, effectsVolume = .6;
  bool _active = true, _disposed = false, _effectBusy = false;
  final List<Sound> _pendingEffects = [];
  int _activePriority = -1;
  String? _track = 'menu';
  DateTime? _lastEffect;
  Future<void> _pending = Future.value();
  Future<void>? _initialization;
  Timer? _saveTimer;
  Completer<void>? _saveCompleter;
  Map<String, dynamic>? _pendingPreferences;
  bool _syncQueued = false;
  bool _syncAgain = false;
  String? error;
  Future<void> initialize() => _initialization ??= _load();
  Future<void> _load() async {
    try {
      final data = await preferences.load();
      enabled = data['enabled'] == true;
      musicEnabled = data['music'] != false;
      effectsEnabled = data['effects'] != false;
      musicVolume = _volume(data['musicVolume'], .35);
      effectsVolume = _volume(data['effectsVolume'], .6);
    } catch (_) {
      error = 'Audio preferences could not be loaded.';
    }
    if (!_disposed) {
      notifyListeners();
      _sync();
    }
  }

  static double _volume(dynamic value, double fallback) =>
      value is num && value.isFinite
          ? value.toDouble().clamp(0, 1).toDouble()
          : fallback;
  void configure({
    bool? master,
    bool? music,
    bool? effects,
    double? musicLevel,
    double? effectsLevel,
  }) {
    enabled = master ?? enabled;
    musicEnabled = music ?? musicEnabled;
    effectsEnabled = effects ?? effectsEnabled;
    musicVolume = _volume(musicLevel, musicVolume);
    effectsVolume = _volume(effectsLevel, effectsVolume);
    notifyListeners();
    final data = <String, dynamic>{
      'enabled': enabled,
      'music': musicEnabled,
      'effects': effectsEnabled,
      'musicVolume': musicVolume,
      'effectsVolume': effectsVolume,
    };
    if (!enabled || !effectsEnabled) {
      _pendingEffects.clear();
      _enqueue(backend.silenceEffects);
    }
    _sync();
    _scheduleSave(data);
  }

  void selectMusic(String? track) {
    if (_track == track) return;
    _track = track;
    _sync();
  }

  void _sync() {
    _syncAgain = true;
    if (_syncQueued) return;
    _syncQueued = true;
    _enqueue(() async {
      try {
        while (_syncAgain && !_disposed) {
          _syncAgain = false;
          await backend.music(
            _active && enabled && musicEnabled ? _track : null,
            musicVolume,
          );
        }
      } finally {
        _syncQueued = false;
        if (_syncAgain && !_disposed) _sync();
      }
    });
  }

  void _scheduleSave(Map<String, dynamic> data) {
    _pendingPreferences = data;
    _saveTimer?.cancel();
    if (_saveCompleter == null || _saveCompleter!.isCompleted) {
      _saveCompleter = Completer<void>();
    }
    _saveTimer = Timer(const Duration(milliseconds: 180), () async {
      final value = _pendingPreferences;
      _pendingPreferences = null;
      if (value != null) _enqueue(() => preferences.save(value));
      await _pending;
      if (!(_saveCompleter?.isCompleted ?? true)) _saveCompleter!.complete();
    });
  }

  void _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        error = 'Audio unavailable. Gameplay can continue.';
      }
    });
  }

  Future<void> get settled async {
    await (_saveCompleter?.future ?? Future<void>.value());
    await _pending;
  }

  void play(Sound sound) {
    if (_disposed || !enabled || !effectsEnabled || !_active) return;
    final now = DateTime.now();
    if (_lastEffect != null &&
        now.difference(_lastEffect!) < const Duration(milliseconds: 80) &&
        _priority(sound) <= _activePriority) {
      return;
    }
    _lastEffect = now;
    if (_effectBusy) {
      if (!_pendingEffects.contains(sound)) {
        _pendingEffects.add(sound);
        _pendingEffects.sort((a, b) => _priority(b).compareTo(_priority(a)));
        if (_pendingEffects.length > 6) _pendingEffects.removeLast();
      }
      return;
    }
    unawaited(_playEffects(sound));
  }

  Future<void> _playEffects(Sound first) async {
    _effectBusy = true;
    var sound = first;
    while (!_disposed) {
      _activePriority = _priority(sound);
      try {
        await backend.effect(sound, effectsVolume);
      } catch (_) {
        error = 'Sound unavailable.';
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (_pendingEffects.isEmpty) break;
      sound = _pendingEffects.removeAt(0);
    }
    _activePriority = -1;
    _effectBusy = false;
  }

  static int _priority(Sound sound) => switch (sound) {
    Sound.gameOver || Sound.best || Sound.achievement || Sound.level => 3,
    Sound.hazard || Sound.challenge || Sound.cosmetic || Sound.start => 2,
    Sound.combo || Sound.bonus || Sound.catchFood || Sound.miss => 1,
    _ => 0,
  };

  void handleInterruption(bool began) {
    _active = !began;
    if (began) {
      _pendingEffects.clear();
      _enqueue(backend.silenceEffects);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleInterruption(state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final preferencesToSave = _pendingPreferences;
    _pendingPreferences = null;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _pending
          .then((_) async {
            if (preferencesToSave != null) {
              try {
                await preferences.save(preferencesToSave);
              } catch (_) {}
            }
            if (!(_saveCompleter?.isCompleted ?? true)) {
              _saveCompleter!.complete();
            }
            await backend.dispose();
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}

final audioServiceProvider = ChangeNotifierProvider<AudioService>((ref) {
  final service = AudioService(PlayerAudioBackend(), FileAudioPreferences());
  WidgetsBinding.instance.addObserver(service);
  unawaited(service.initialize());
  return service;
});

class AudioInteractionScope extends ConsumerStatefulWidget {
  const AudioInteractionScope({
    super.key,
    required this.child,
    this.allowFeedback,
  });
  final Widget child;
  final bool Function()? allowFeedback;

  @override
  ConsumerState<AudioInteractionScope> createState() =>
      _AudioInteractionScopeState();
}

class _AudioInteractionScopeState extends ConsumerState<AudioInteractionScope> {
  Offset? _downPosition;
  DateTime? _downAt;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      _downPosition = event.position;
      _downAt = DateTime.now();
    },
    onPointerCancel: (_) {
      _downPosition = null;
      _downAt = null;
    },
    onPointerUp: (event) {
      final origin = _downPosition;
      final started = _downAt;
      _downPosition = null;
      _downAt = null;
      if (origin == null || started == null) return;
      if (widget.allowFeedback?.call() == false) return;
      if ((event.position - origin).distance > 10 ||
          DateTime.now().difference(started) > const Duration(seconds: 1)) {
        return;
      }
      ref.read(audioServiceProvider).play(Sound.tap);
    },
    child: widget.child,
  );
}

class AudioRouteScope extends ConsumerStatefulWidget {
  const AudioRouteScope({
    super.key,
    required this.routes,
    required this.path,
    required this.child,
  });
  final Listenable routes;
  final String Function() path;
  final Widget child;

  @override
  ConsumerState<AudioRouteScope> createState() => _AudioRouteScopeState();
}

class _AudioRouteScopeState extends ConsumerState<AudioRouteScope> {
  @override
  void initState() {
    super.initState();
    widget.routes.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeChanged());
  }

  @override
  void didUpdateWidget(covariant AudioRouteScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes == widget.routes) return;
    oldWidget.routes.removeListener(_routeChanged);
    widget.routes.addListener(_routeChanged);
    _routeChanged();
  }

  void _routeChanged() {
    if (!mounted) return;
    final path = widget.path();
    ref.read(audioServiceProvider).selectMusic(musicTrackForPath(path));
  }

  @override
  void dispose() {
    widget.routes.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
