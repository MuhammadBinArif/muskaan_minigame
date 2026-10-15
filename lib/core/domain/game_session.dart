// GameSession manages the complete lifecycle and state of a Muskaan Minigame
// game session.
//
// This is a pure Dart class that encapsulates game logic, the state
// machine, and gameplay rules. It is independent of Flutter UI and
// can be tested deterministically.

/// Game session lifecycle states.
enum GameSessionState { ready, preparing, playing, paused, gameOver, results }

/// Food item types for the game.
enum FoodItemType { gold, tea, teal }

/// Game session record for persistence.
class GameSessionRecord {
  final int id;
  final int score;
  final int livesLost;
  final int maxLives;
  final int timePlayed; // seconds
  final int bestCombo;
  final int catches;
  final double accuracy; // 0.0 – 1.0
  final int smileScore; // 0 – 100
  final DateTime startedAt;
  final DateTime? endedAt;
  final GameSessionState state;
  final bool isNewBest;

  const GameSessionRecord({
    required this.id,
    required this.score,
    required this.livesLost,
    required this.maxLives,
    required this.timePlayed,
    required this.bestCombo,
    required this.catches,
    required this.accuracy,
    required this.smileScore,
    required this.startedAt,
    this.endedAt,
    required this.state,
    required this.isNewBest,
  });

  /// Create a brand-new, unpersisted session record.
  ///
  /// `id = 0` signals "let the database assign an auto-increment id".
  factory GameSessionRecord.create() {
    return GameSessionRecord(
      id: 0,
      score: 0,
      livesLost: 0,
      maxLives: 3,
      timePlayed: 0,
      bestCombo: 0,
      catches: 0,
      accuracy: 0.0,
      smileScore: 0,
      startedAt: DateTime.now(),
      endedAt: null,
      state: GameSessionState.ready,
      isNewBest: false,
    );
  }

  /// Create a completed copy of this session.
  GameSessionRecord complete({
    required int finalScore,
    required int finalLivesLost,
    required int timePlayed,
    required int finalBestCombo,
    required int finalCatches,
    required double finalAccuracy,
    required int finalSmileScore,
  }) {
    return GameSessionRecord(
      id: id,
      score: finalScore,
      livesLost: finalLivesLost,
      maxLives: maxLives,
      timePlayed: timePlayed,
      bestCombo: finalBestCombo,
      catches: finalCatches,
      accuracy: finalAccuracy,
      smileScore: finalSmileScore,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      state: GameSessionState.gameOver,
      isNewBest: false, // determined by persistence layer
    );
  }
}

/// Active food item in the game.
class FoodItem {
  final FoodItemType type;
  final double positionX;
  final double positionY;
  final double velocityX;
  final double velocityY;
  final double size;
  final int creationTime;

  const FoodItem({
    required this.type,
    required this.positionX,
    required this.positionY,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.creationTime,
  });

  bool isActive(int currentTimeMs, int foodLifetimeMs) =>
      currentTimeMs - creationTime <= foodLifetimeMs;

  FoodItem update(double dt, double screenWidth, double screenHeight) {
    final newX = positionX + velocityX * dt;
    final newY = positionY + velocityY * dt;

    var newVX = velocityX;
    var newVY = velocityY;

    if (newX <= 0 || newX >= screenWidth - size) newVX = -velocityX;
    if (newY <= 0 || newY >= screenHeight - size) newVY = -velocityY;

    return FoodItem(
      type: type,
      positionX: newX,
      positionY: newY,
      velocityX: newVX,
      velocityY: newVY,
      size: size,
      creationTime: creationTime,
    );
  }
}

/// Collision event between food and the mouth region.
class CollisionEvent {
  final FoodItemType foodType;
  final double mouthX;
  final double mouthY;
  final int timestamp;
  final bool isCatch;

  const CollisionEvent({
    required this.foodType,
    required this.mouthX,
    required this.mouthY,
    required this.timestamp,
    required this.isCatch,
  });
}

/// Complete game statistics.
class GameStats {
  final int score;
  final int lives;
  final int timeRemaining;
  final int combo;
  final int maxCombo;
  final int catches;
  final int hazardsHit;
  final int totalFoodsSpawned;
  final double accuracy;
  final int smileScore;

  const GameStats({
    required this.score,
    required this.lives,
    required this.timeRemaining,
    required this.combo,
    required this.maxCombo,
    required this.catches,
    required this.hazardsHit,
    required this.totalFoodsSpawned,
    required this.accuracy,
    required this.smileScore,
  });

  factory GameStats.initial() => const GameStats(
    score: 0,
    lives: 3,
    timeRemaining: 45,
    combo: 0,
    maxCombo: 0,
    catches: 0,
    hazardsHit: 0,
    totalFoodsSpawned: 0,
    accuracy: 0.0,
    smileScore: 0,
  );

  GameStats applyCollision(CollisionEvent event) {
    final isCatch = event.isCatch;
    final points = isCatch ? _pointsFor(event.foodType) : 0;
    final newScore = score + points;
    final newCombo = isCatch ? combo + 1 : 0;
    final newCatches = catches + (isCatch ? 1 : 0);
    final newHazards = hazardsHit + (isCatch ? 0 : 1);
    final denom = (newCatches + newHazards).clamp(1, 1 << 30);
    final newAccuracy = newCatches / denom;
    final newMaxCombo = newCombo > maxCombo ? newCombo : maxCombo;

    return GameStats(
      score: newScore,
      lives: isCatch ? lives : (lives - 1),
      timeRemaining: timeRemaining,
      combo: newCombo,
      maxCombo: newMaxCombo,
      catches: newCatches,
      hazardsHit: newHazards,
      totalFoodsSpawned: totalFoodsSpawned,
      accuracy: newAccuracy,
      smileScore: _smileScore(newScore, newCombo, newAccuracy),
    );
  }

  GameStats applyMiss() {
    return GameStats(
      score: score,
      lives: lives,
      timeRemaining: timeRemaining,
      combo: 0,
      maxCombo: maxCombo,
      catches: catches,
      hazardsHit: hazardsHit,
      totalFoodsSpawned: totalFoodsSpawned,
      accuracy: accuracy,
      smileScore: _smileScore(score, 0, accuracy),
    );
  }

  GameStats updateTimeRemaining(int newTimeRemaining) => GameStats(
    score: score,
    lives: lives,
    timeRemaining: newTimeRemaining,
    combo: combo,
    maxCombo: maxCombo,
    catches: catches,
    hazardsHit: hazardsHit,
    totalFoodsSpawned: totalFoodsSpawned,
    accuracy: accuracy,
    smileScore: smileScore,
  );

  bool get isGameOver => lives <= 0;
  bool get isTimeOut => timeRemaining <= 0;
  String? get gameOverReason {
    if (isGameOver) return 'no_lives';
    if (isTimeOut) return 'time_up';
    return null;
  }

  static int _smileScore(int score, int combo, double accuracy) {
    final raw = score + (combo * 100) + (accuracy * 100).toInt();
    return raw.clamp(0, 100);
  }

  static int _pointsFor(FoodItemType type) {
    switch (type) {
      case FoodItemType.gold:
        return 100;
      case FoodItemType.teal:
        return 75;
      case FoodItemType.tea:
        return 50;
    }
  }
}
