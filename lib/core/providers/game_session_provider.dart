// Provider for the current game session state.
//
// Exposes [gameSessionProvider] which holds the live [GameSessionStateData]
// and the [GameSessionNotifier] that mutates it.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muskaan_minigame/core/domain/game_session.dart';
import 'package:muskaan_minigame/features/game/data/records_repository.dart';

/// Provider that exposes the current game session state
final gameSessionProvider =
    StateNotifierProvider<GameSessionNotifier, GameSessionStateData>((ref) {
      final repository = ref.watch(gameRecordsRepositoryProvider);
      return GameSessionNotifier(repository: repository);
    });

/// Data class that contains all the information needed by the UI
class GameSessionStateData {
  final GameSessionState state;
  final GameStats stats;
  final List<FoodItem> activeFoods;
  final List<CollisionEvent> recentCollisions;
  final bool isPaused;
  final bool isGameOver;
  final bool isReady;
  final bool isPlaying;
  final GameSessionRecord? completedRecord;
  final bool isSaving;
  final String? saveError;

  const GameSessionStateData({
    required this.state,
    required this.stats,
    required this.activeFoods,
    required this.recentCollisions,
    required this.isPaused,
    required this.isGameOver,
    required this.isReady,
    required this.isPlaying,
    this.completedRecord,
    this.isSaving = false,
    this.saveError,
  });

  /// Create initial state data
  factory GameSessionStateData.initial() {
    return GameSessionStateData(
      state: GameSessionState.ready,
      stats: GameStats.initial(),
      activeFoods: [],
      recentCollisions: [],
      isPaused: false,
      isGameOver: false,
      isReady: true,
      isPlaying: false,
    );
  }

  /// Check if we can start a new game
  bool get canStartGame =>
      state == GameSessionState.ready || state == GameSessionState.gameOver;

  /// Check if we can pause/resume
  bool get canPause => state == GameSessionState.playing;
  bool get canResume => state == GameSessionState.paused;

  /// Check if we can quit
  bool get canQuit => state != GameSessionState.results;

  /// Snapshot of the current round for the results / game-over screens.
  /// Returns null when the session hasn't produced results yet.
  /// Snapshot of the current round for the Results / Game Over screens.
  ///
  /// Returns null while the round is still in progress. Once the
  /// session reaches a terminal state (`gameOver` or `results`),
  /// returns a fully-populated [GameSessionRecord] the router can
  /// hand off to [ResultsScreen] or [GameOverScreen].
  GameSessionRecord? getGameResults() {
    if (state != GameSessionState.gameOver &&
        state != GameSessionState.results) {
      return null;
    }

    return completedRecord;
  }
}

/// Notifier that manages the game session state and applies game logic
class GameSessionNotifier extends StateNotifier<GameSessionStateData> {
  final GameRecordsRepository? repository;

  GameSessionNotifier({
    this.repository,
    this.sessionDuration = const Duration(seconds: 45),
    Stopwatch? clock,
  }) : _clock = clock ?? Stopwatch(),
       super(GameSessionStateData.initial());

  Timer? _foodSpawnTimer;
  Timer? _gameTickTimer;
  Stopwatch get _gameStopwatch => _clock;
  bool _isInitialized = false;
  bool _hasPersisted = false;
  Future<void>? _saveInFlight;
  GameSessionRecord? _session;
  int _lastTickMs = 0;
  bool _biteConsumed = false;
  final Duration sessionDuration;
  final Stopwatch _clock;
  final math.Random _random = math.Random();

  // Game configuration
  int get _gameDurationSeconds => sessionDuration.inSeconds;
  static const int _maxLives = 3;
  static const double _spawnIntervalMs = 1500;
  static const int _foodLifetimeMs = 5000;

  void _initializeGame() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Start food spawning timer
    _foodSpawnTimer = Timer.periodic(
      Duration(milliseconds: _spawnIntervalMs.toInt()),
      (_) => _spawnFood(),
    );

    // Start game tick timer (60 FPS updates)
    _gameTickTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateGame(),
    );
  }

  void _spawnFood() {
    if (state.state != GameSessionState.playing) return;

    // Determine food type based on weights
    final random = _random.nextInt(100000);
    final type = _getRandomFoodType();

    // Spawn at random x position
    final x = 0.1 + (random % 80) / 100.0; // 0.1 to 0.9

    // Start from top of screen
    final y = -0.1; // Slightly above screen

    // Random velocity
    final vx = (random % 200 - 100) / 1000.0; // -0.1 to 0.1
    // Normalized screen units per second: reach the mouth before expiry.
    final progress = 1 - state.stats.timeRemaining / _gameDurationSeconds;
    final vy = 0.20 + progress * 0.12 + (random % 100) / 1000.0;

    final food = FoodItem(
      type: type,
      positionX: x,
      positionY: y,
      velocityX: vx,
      velocityY: vy,
      size:
          0.08 + (type == FoodItemType.gold ? 0.02 : 0), // Gold slightly larger
      creationTime: _gameStopwatch.elapsedMilliseconds,
    );

    state = state.copyWith(activeFoods: [...state.activeFoods, food]);
  }

  FoodItemType _getRandomFoodType() {
    final random = _random.nextInt(100);
    final roll = random % 100;

    if (roll < 40) {
      return FoodItemType.gold; // 40% gold
    } else if (roll < 80) {
      return FoodItemType.teal; // 40% teal
    } else {
      return FoodItemType.tea; // 20% tea (hazard)
    }
  }

  void _updateGame() {
    // Only update during playing state
    if (state.state != GameSessionState.playing) return;

    // Update game time
    final elapsedSeconds = (_gameStopwatch.elapsedMilliseconds / 1000).floor();
    final timeRemaining = (_gameDurationSeconds - elapsedSeconds).clamp(
      0,
      _gameDurationSeconds,
    );

    // Update food positions and remove expired foods
    final currentTime = _gameStopwatch.elapsedMilliseconds;
    final dt = (currentTime - _lastTickMs) / 1000.0;
    _lastTickMs = currentTime;
    final activeFoods = <FoodItem>[];
    var stats = state.stats;

    for (final food in state.activeFoods) {
      if (food.isActive(currentTime, _foodLifetimeMs)) {
        final updatedFood = food.update(
          dt,
          1.0,
          1.0,
        ); // 16ms at 60fps, normalized screen

        // If edible food falls past the mouth zone (y > 0.68) and wasn't caught,
        // treat it as a miss and reset combo
        if (updatedFood.positionY >= 1.0 + updatedFood.size) {
          if (updatedFood.type != FoodItemType.tea) {
            stats = stats.applyMiss();
          }
        }

        if (updatedFood.positionY < 1.0 + updatedFood.size) {
          activeFoods.add(updatedFood);
        }
      }
    }

    state = state.copyWith(
      stats: stats.updateTimeRemaining(timeRemaining),
      activeFoods: activeFoods,
    );

    // Check for game over conditions
    if (state.stats.isGameOver || state.stats.isTimeOut) {
      _endGame();
    }
  }

  void _endGame() {
    if (state.state == GameSessionState.gameOver) return;

    _gameStopwatch.stop();
    final record = getGameResults();
    state = state.copyWith(
      completedRecord: record,
      state: GameSessionState.gameOver,
      isGameOver: true,
      isPlaying: false,
    );

    // Cancel timers
    _foodSpawnTimer?.cancel();
    _gameTickTimer?.cancel();

    unawaited(persistCompletedSession());
  }

  /// Retry the SAME immutable result. Stable IDs make retries idempotent.
  Future<void> persistCompletedSession() {
    if (_saveInFlight != null) return _saveInFlight!;
    final record = state.completedRecord;
    if (_hasPersisted || repository == null || record == null) {
      return Future<void>.value();
    }
    state = state.copyWith(isSaving: true, clearSaveError: true);
    final operation = _saveRecord(record);
    _saveInFlight = operation;
    return operation;
  }

  Future<void> _saveRecord(GameSessionRecord record) async {
    try {
      await repository!.saveSession(record);
      if (mounted && state.completedRecord?.id == record.id) {
        _hasPersisted = true;
        state = state.copyWith(isSaving: false, clearSaveError: true);
      }
    } catch (error) {
      if (mounted && state.completedRecord?.id == record.id) {
        state = state.copyWith(isSaving: false, saveError: error.toString());
      }
    } finally {
      _saveInFlight = null;
    }
  }

  /// Start a new game session
  void startGame() {
    if (!state.canStartGame || state.isSaving || state.saveError != null) {
      return;
    }

    // Reset game
    _resetGame();
    _hasPersisted = false;
    _session = GameSessionRecord.create();
    _lastTickMs = 0;
    _biteConsumed = false;
    state = GameSessionStateData.initial();

    // Set to playing state
    _gameStopwatch.reset();
    _gameStopwatch.start();

    state = state.copyWith(
      state: GameSessionState.playing,
      isPlaying: true,
      isGameOver: false,
      isReady: false,
      stats: GameStats.initial().updateTimeRemaining(_gameDurationSeconds),
    );
  }

  void _resetGame() {
    // Cancel existing timers
    _foodSpawnTimer?.cancel();
    _gameTickTimer?.cancel();
    _gameStopwatch.stop();
    _gameStopwatch.reset();

    _isInitialized = false;

    // Reinitialize timers
    _initializeGame();
  }

  /// Pause the game
  void pauseGame() {
    if (!state.canPause) return;

    _gameStopwatch.stop();
    state = state.copyWith(
      state: GameSessionState.paused,
      isPaused: true,
      isPlaying: false,
    );
  }

  /// Resume the game
  void resumeGame() {
    if (!state.canResume) return;

    _gameStopwatch.start();
    state = state.copyWith(
      state: GameSessionState.playing,
      isPaused: false,
      isPlaying: true,
    );
  }

  /// Stop work immediately; publish route-exit state after widget disposal.
  void leaveGame() {
    _foodSpawnTimer?.cancel();
    _gameTickTimer?.cancel();
    _gameStopwatch.stop();
    final leaving = _session;
    scheduleMicrotask(() {
      if (mounted && identical(_session, leaving)) quitGame();
    });
  }

  /// Quit current game session
  void quitGame() {
    if (state.state == GameSessionState.ready) return;
    if (state.state == GameSessionState.gameOver ||
        state.state == GameSessionState.results) {
      return;
    }
    // End the game if currently playing
    if (state.state == GameSessionState.playing ||
        state.state == GameSessionState.paused) {
      _endGame();
    }

    state = state.copyWith(
      state: GameSessionState.ready,
      isPaused: false,
      isGameOver: false,
      isPlaying: false,
      isReady: true,
    );

    // Cancel timers
    _foodSpawnTimer?.cancel();
    _gameTickTimer?.cancel();
    _gameStopwatch.stop();
  }

  /// Check and process food catching/hazard interactions based on the mouth state.
  ///
  /// Rules:
  /// - Edible food in mouth zone while open -> CATCH (score +, combo +)
  /// - Hot tea hazard in mouth zone while open -> HAZARD HIT (-1 life, combo reset)
  /// - Edible food falling below mouth zone uncaught -> MISS (combo reset)
  void updateMouthTracking({
    required bool isOpen,
    required bool isActionable,
    double mouthX = 0.5,
    double mouthY = 0.52,
  }) {
    if (state.state != GameSessionState.playing) return;

    if (!isActionable) return;
    if (!isOpen) {
      _biteConsumed = false;
      return;
    }
    if (_biteConsumed) return;

    // Mouth collision zone in normalized screen coordinates
    const collisionRadius = 0.14; // ~14% of screen dimensions

    final remainingFoods = <FoodItem>[];
    final recentCollisions = List<CollisionEvent>.from(state.recentCollisions);
    var stats = state.stats;

    for (final food in state.activeFoods) {
      final dx = food.positionX - mouthX;
      final dy = food.positionY - mouthY;
      final distance = (dx * dx + dy * dy);

      if (!_biteConsumed && distance <= collisionRadius * collisionRadius) {
        _biteConsumed = true;
        // Collision inside the open mouth zone!
        final isEdible = food.type != FoodItemType.tea;
        final collision = CollisionEvent(
          foodType: food.type,
          mouthX: mouthX,
          mouthY: mouthY,
          timestamp: _gameStopwatch.elapsedMilliseconds,
          isCatch: isEdible,
        );
        stats = stats.applyCollision(collision);
        recentCollisions.insert(0, collision);
      } else {
        remainingFoods.add(food);
      }
    }

    state = state.copyWith(
      stats: stats,
      activeFoods: remainingFoods,
      recentCollisions: recentCollisions.take(5).toList(),
    );

    if (state.stats.isGameOver || state.stats.isTimeOut) {
      _endGame();
    }
  }

  /// Handle collision between food and mouth (legacy bridge)
  void handleFoodCollision(FoodItem food, double mouthX, double mouthY) {
    if (state.state != GameSessionState.playing) return;

    final isEdible = food.type != FoodItemType.tea;

    // Remove the food from active foods
    final remainingFoods =
        state.activeFoods
            .where(
              (f) =>
                  f.positionX != food.positionX ||
                  f.positionY != food.positionY,
            )
            .toList();

    // Apply collision to stats
    final collision = CollisionEvent(
      foodType: food.type,
      mouthX: mouthX,
      mouthY: mouthY,
      timestamp: _gameStopwatch.elapsedMilliseconds,
      isCatch: isEdible,
    );

    state = state.copyWith(
      stats: state.stats.applyCollision(collision),
      activeFoods: remainingFoods,
      recentCollisions: [collision, ...state.recentCollisions.take(4)],
    );

    if (state.stats.isGameOver || state.stats.isTimeOut) {
      _endGame();
    }
  }

  /// Get final game results for persistence
  GameSessionRecord getGameResults() {
    if (state.completedRecord != null) return state.completedRecord!;
    return (_session ??= GameSessionRecord.create()).complete(
      finalScore: state.stats.score,
      finalLivesLost: _maxLives - state.stats.lives,
      timePlayed: _gameDurationSeconds - state.stats.timeRemaining,
      finalBestCombo: state.stats.maxCombo,
      finalCatches: state.stats.catches,
      finalAccuracy: state.stats.accuracy,
      finalSmileScore: state.stats.smileScore,
    );
  }

  @override
  void dispose() {
    _foodSpawnTimer?.cancel();
    _gameTickTimer?.cancel();
    _gameStopwatch.stop();
    super.dispose();
  }
}

/// Extension to enable copying state data
extension GameSessionStateDataCopy on GameSessionStateData {
  GameSessionStateData copyWith({
    GameSessionState? state,
    GameStats? stats,
    List<FoodItem>? activeFoods,
    List<CollisionEvent>? recentCollisions,
    bool? isPaused,
    bool? isGameOver,
    bool? isReady,
    bool? isPlaying,
    GameSessionRecord? completedRecord,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return GameSessionStateData(
      state: state ?? this.state,
      stats: stats ?? this.stats,
      activeFoods: activeFoods ?? this.activeFoods,
      recentCollisions: recentCollisions ?? this.recentCollisions,
      isPaused: isPaused ?? this.isPaused,
      isGameOver: isGameOver ?? this.isGameOver,
      isReady: isReady ?? this.isReady,
      isPlaying: isPlaying ?? this.isPlaying,
      completedRecord: completedRecord ?? this.completedRecord,
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : saveError ?? this.saveError,
    );
  }
}
