// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_database.dart';

// ignore_for_file: type=lint
class $GameRecordsTable extends GameRecords
    with TableInfo<$GameRecordsTable, GameRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _livesLostMeta = const VerificationMeta(
    'livesLost',
  );
  @override
  late final GeneratedColumn<int> livesLost = GeneratedColumn<int>(
    'lives_lost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxLivesMeta = const VerificationMeta(
    'maxLives',
  );
  @override
  late final GeneratedColumn<int> maxLives = GeneratedColumn<int>(
    'max_lives',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timePlayedMeta = const VerificationMeta(
    'timePlayed',
  );
  @override
  late final GeneratedColumn<int> timePlayed = GeneratedColumn<int>(
    'time_played',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestComboMeta = const VerificationMeta(
    'bestCombo',
  );
  @override
  late final GeneratedColumn<int> bestCombo = GeneratedColumn<int>(
    'best_combo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _catchesMeta = const VerificationMeta(
    'catches',
  );
  @override
  late final GeneratedColumn<int> catches = GeneratedColumn<int>(
    'catches',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smileScoreMeta = const VerificationMeta(
    'smileScore',
  );
  @override
  late final GeneratedColumn<int> smileScore = GeneratedColumn<int>(
    'smile_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNewBestMeta = const VerificationMeta(
    'isNewBest',
  );
  @override
  late final GeneratedColumn<bool> isNewBest = GeneratedColumn<bool>(
    'is_new_best',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new_best" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    score,
    livesLost,
    maxLives,
    timePlayed,
    bestCombo,
    catches,
    accuracy,
    smileScore,
    startedAt,
    endedAt,
    state,
    isNewBest,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('lives_lost')) {
      context.handle(
        _livesLostMeta,
        livesLost.isAcceptableOrUnknown(data['lives_lost']!, _livesLostMeta),
      );
    } else if (isInserting) {
      context.missing(_livesLostMeta);
    }
    if (data.containsKey('max_lives')) {
      context.handle(
        _maxLivesMeta,
        maxLives.isAcceptableOrUnknown(data['max_lives']!, _maxLivesMeta),
      );
    } else if (isInserting) {
      context.missing(_maxLivesMeta);
    }
    if (data.containsKey('time_played')) {
      context.handle(
        _timePlayedMeta,
        timePlayed.isAcceptableOrUnknown(data['time_played']!, _timePlayedMeta),
      );
    } else if (isInserting) {
      context.missing(_timePlayedMeta);
    }
    if (data.containsKey('best_combo')) {
      context.handle(
        _bestComboMeta,
        bestCombo.isAcceptableOrUnknown(data['best_combo']!, _bestComboMeta),
      );
    } else if (isInserting) {
      context.missing(_bestComboMeta);
    }
    if (data.containsKey('catches')) {
      context.handle(
        _catchesMeta,
        catches.isAcceptableOrUnknown(data['catches']!, _catchesMeta),
      );
    } else if (isInserting) {
      context.missing(_catchesMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('smile_score')) {
      context.handle(
        _smileScoreMeta,
        smileScore.isAcceptableOrUnknown(data['smile_score']!, _smileScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_smileScoreMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('is_new_best')) {
      context.handle(
        _isNewBestMeta,
        isNewBest.isAcceptableOrUnknown(data['is_new_best']!, _isNewBestMeta),
      );
    } else if (isInserting) {
      context.missing(_isNewBestMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      score:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}score'],
          )!,
      livesLost:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lives_lost'],
          )!,
      maxLives:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}max_lives'],
          )!,
      timePlayed:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}time_played'],
          )!,
      bestCombo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}best_combo'],
          )!,
      catches:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}catches'],
          )!,
      accuracy:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}accuracy'],
          )!,
      smileScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}smile_score'],
          )!,
      startedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_at'],
          )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      state:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}state'],
          )!,
      isNewBest:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_new_best'],
          )!,
    );
  }

  @override
  $GameRecordsTable createAlias(String alias) {
    return $GameRecordsTable(attachedDatabase, alias);
  }
}

class GameRecord extends DataClass implements Insertable<GameRecord> {
  final int id;
  final int score;
  final int livesLost;
  final int maxLives;
  final int timePlayed;
  final int bestCombo;
  final int catches;
  final double accuracy;
  final int smileScore;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int state;
  final bool isNewBest;
  const GameRecord({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['score'] = Variable<int>(score);
    map['lives_lost'] = Variable<int>(livesLost);
    map['max_lives'] = Variable<int>(maxLives);
    map['time_played'] = Variable<int>(timePlayed);
    map['best_combo'] = Variable<int>(bestCombo);
    map['catches'] = Variable<int>(catches);
    map['accuracy'] = Variable<double>(accuracy);
    map['smile_score'] = Variable<int>(smileScore);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['state'] = Variable<int>(state);
    map['is_new_best'] = Variable<bool>(isNewBest);
    return map;
  }

  GameRecordsCompanion toCompanion(bool nullToAbsent) {
    return GameRecordsCompanion(
      id: Value(id),
      score: Value(score),
      livesLost: Value(livesLost),
      maxLives: Value(maxLives),
      timePlayed: Value(timePlayed),
      bestCombo: Value(bestCombo),
      catches: Value(catches),
      accuracy: Value(accuracy),
      smileScore: Value(smileScore),
      startedAt: Value(startedAt),
      endedAt:
          endedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(endedAt),
      state: Value(state),
      isNewBest: Value(isNewBest),
    );
  }

  factory GameRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRecord(
      id: serializer.fromJson<int>(json['id']),
      score: serializer.fromJson<int>(json['score']),
      livesLost: serializer.fromJson<int>(json['livesLost']),
      maxLives: serializer.fromJson<int>(json['maxLives']),
      timePlayed: serializer.fromJson<int>(json['timePlayed']),
      bestCombo: serializer.fromJson<int>(json['bestCombo']),
      catches: serializer.fromJson<int>(json['catches']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      smileScore: serializer.fromJson<int>(json['smileScore']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      state: serializer.fromJson<int>(json['state']),
      isNewBest: serializer.fromJson<bool>(json['isNewBest']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'score': serializer.toJson<int>(score),
      'livesLost': serializer.toJson<int>(livesLost),
      'maxLives': serializer.toJson<int>(maxLives),
      'timePlayed': serializer.toJson<int>(timePlayed),
      'bestCombo': serializer.toJson<int>(bestCombo),
      'catches': serializer.toJson<int>(catches),
      'accuracy': serializer.toJson<double>(accuracy),
      'smileScore': serializer.toJson<int>(smileScore),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'state': serializer.toJson<int>(state),
      'isNewBest': serializer.toJson<bool>(isNewBest),
    };
  }

  GameRecord copyWith({
    int? id,
    int? score,
    int? livesLost,
    int? maxLives,
    int? timePlayed,
    int? bestCombo,
    int? catches,
    double? accuracy,
    int? smileScore,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? state,
    bool? isNewBest,
  }) => GameRecord(
    id: id ?? this.id,
    score: score ?? this.score,
    livesLost: livesLost ?? this.livesLost,
    maxLives: maxLives ?? this.maxLives,
    timePlayed: timePlayed ?? this.timePlayed,
    bestCombo: bestCombo ?? this.bestCombo,
    catches: catches ?? this.catches,
    accuracy: accuracy ?? this.accuracy,
    smileScore: smileScore ?? this.smileScore,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    state: state ?? this.state,
    isNewBest: isNewBest ?? this.isNewBest,
  );
  GameRecord copyWithCompanion(GameRecordsCompanion data) {
    return GameRecord(
      id: data.id.present ? data.id.value : this.id,
      score: data.score.present ? data.score.value : this.score,
      livesLost: data.livesLost.present ? data.livesLost.value : this.livesLost,
      maxLives: data.maxLives.present ? data.maxLives.value : this.maxLives,
      timePlayed:
          data.timePlayed.present ? data.timePlayed.value : this.timePlayed,
      bestCombo: data.bestCombo.present ? data.bestCombo.value : this.bestCombo,
      catches: data.catches.present ? data.catches.value : this.catches,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      smileScore:
          data.smileScore.present ? data.smileScore.value : this.smileScore,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      state: data.state.present ? data.state.value : this.state,
      isNewBest: data.isNewBest.present ? data.isNewBest.value : this.isNewBest,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRecord(')
          ..write('id: $id, ')
          ..write('score: $score, ')
          ..write('livesLost: $livesLost, ')
          ..write('maxLives: $maxLives, ')
          ..write('timePlayed: $timePlayed, ')
          ..write('bestCombo: $bestCombo, ')
          ..write('catches: $catches, ')
          ..write('accuracy: $accuracy, ')
          ..write('smileScore: $smileScore, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('state: $state, ')
          ..write('isNewBest: $isNewBest')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    score,
    livesLost,
    maxLives,
    timePlayed,
    bestCombo,
    catches,
    accuracy,
    smileScore,
    startedAt,
    endedAt,
    state,
    isNewBest,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRecord &&
          other.id == this.id &&
          other.score == this.score &&
          other.livesLost == this.livesLost &&
          other.maxLives == this.maxLives &&
          other.timePlayed == this.timePlayed &&
          other.bestCombo == this.bestCombo &&
          other.catches == this.catches &&
          other.accuracy == this.accuracy &&
          other.smileScore == this.smileScore &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.state == this.state &&
          other.isNewBest == this.isNewBest);
}

class GameRecordsCompanion extends UpdateCompanion<GameRecord> {
  final Value<int> id;
  final Value<int> score;
  final Value<int> livesLost;
  final Value<int> maxLives;
  final Value<int> timePlayed;
  final Value<int> bestCombo;
  final Value<int> catches;
  final Value<double> accuracy;
  final Value<int> smileScore;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> state;
  final Value<bool> isNewBest;
  const GameRecordsCompanion({
    this.id = const Value.absent(),
    this.score = const Value.absent(),
    this.livesLost = const Value.absent(),
    this.maxLives = const Value.absent(),
    this.timePlayed = const Value.absent(),
    this.bestCombo = const Value.absent(),
    this.catches = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.smileScore = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.state = const Value.absent(),
    this.isNewBest = const Value.absent(),
  });
  GameRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int score,
    required int livesLost,
    required int maxLives,
    required int timePlayed,
    required int bestCombo,
    required int catches,
    required double accuracy,
    required int smileScore,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required int state,
    required bool isNewBest,
  }) : score = Value(score),
       livesLost = Value(livesLost),
       maxLives = Value(maxLives),
       timePlayed = Value(timePlayed),
       bestCombo = Value(bestCombo),
       catches = Value(catches),
       accuracy = Value(accuracy),
       smileScore = Value(smileScore),
       startedAt = Value(startedAt),
       state = Value(state),
       isNewBest = Value(isNewBest);
  static Insertable<GameRecord> custom({
    Expression<int>? id,
    Expression<int>? score,
    Expression<int>? livesLost,
    Expression<int>? maxLives,
    Expression<int>? timePlayed,
    Expression<int>? bestCombo,
    Expression<int>? catches,
    Expression<double>? accuracy,
    Expression<int>? smileScore,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? state,
    Expression<bool>? isNewBest,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (score != null) 'score': score,
      if (livesLost != null) 'lives_lost': livesLost,
      if (maxLives != null) 'max_lives': maxLives,
      if (timePlayed != null) 'time_played': timePlayed,
      if (bestCombo != null) 'best_combo': bestCombo,
      if (catches != null) 'catches': catches,
      if (accuracy != null) 'accuracy': accuracy,
      if (smileScore != null) 'smile_score': smileScore,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (state != null) 'state': state,
      if (isNewBest != null) 'is_new_best': isNewBest,
    });
  }

  GameRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? score,
    Value<int>? livesLost,
    Value<int>? maxLives,
    Value<int>? timePlayed,
    Value<int>? bestCombo,
    Value<int>? catches,
    Value<double>? accuracy,
    Value<int>? smileScore,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? state,
    Value<bool>? isNewBest,
  }) {
    return GameRecordsCompanion(
      id: id ?? this.id,
      score: score ?? this.score,
      livesLost: livesLost ?? this.livesLost,
      maxLives: maxLives ?? this.maxLives,
      timePlayed: timePlayed ?? this.timePlayed,
      bestCombo: bestCombo ?? this.bestCombo,
      catches: catches ?? this.catches,
      accuracy: accuracy ?? this.accuracy,
      smileScore: smileScore ?? this.smileScore,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      state: state ?? this.state,
      isNewBest: isNewBest ?? this.isNewBest,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (livesLost.present) {
      map['lives_lost'] = Variable<int>(livesLost.value);
    }
    if (maxLives.present) {
      map['max_lives'] = Variable<int>(maxLives.value);
    }
    if (timePlayed.present) {
      map['time_played'] = Variable<int>(timePlayed.value);
    }
    if (bestCombo.present) {
      map['best_combo'] = Variable<int>(bestCombo.value);
    }
    if (catches.present) {
      map['catches'] = Variable<int>(catches.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (smileScore.present) {
      map['smile_score'] = Variable<int>(smileScore.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (isNewBest.present) {
      map['is_new_best'] = Variable<bool>(isNewBest.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameRecordsCompanion(')
          ..write('id: $id, ')
          ..write('score: $score, ')
          ..write('livesLost: $livesLost, ')
          ..write('maxLives: $maxLives, ')
          ..write('timePlayed: $timePlayed, ')
          ..write('bestCombo: $bestCombo, ')
          ..write('catches: $catches, ')
          ..write('accuracy: $accuracy, ')
          ..write('smileScore: $smileScore, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('state: $state, ')
          ..write('isNewBest: $isNewBest')
          ..write(')'))
        .toString();
  }
}

abstract class _$GameDatabase extends GeneratedDatabase {
  _$GameDatabase(QueryExecutor e) : super(e);
  $GameDatabaseManager get managers => $GameDatabaseManager(this);
  late final $GameRecordsTable gameRecords = $GameRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [gameRecords];
}

typedef $$GameRecordsTableCreateCompanionBuilder =
    GameRecordsCompanion Function({
      Value<int> id,
      required int score,
      required int livesLost,
      required int maxLives,
      required int timePlayed,
      required int bestCombo,
      required int catches,
      required double accuracy,
      required int smileScore,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required int state,
      required bool isNewBest,
    });
typedef $$GameRecordsTableUpdateCompanionBuilder =
    GameRecordsCompanion Function({
      Value<int> id,
      Value<int> score,
      Value<int> livesLost,
      Value<int> maxLives,
      Value<int> timePlayed,
      Value<int> bestCombo,
      Value<int> catches,
      Value<double> accuracy,
      Value<int> smileScore,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> state,
      Value<bool> isNewBest,
    });

class $$GameRecordsTableFilterComposer
    extends Composer<_$GameDatabase, $GameRecordsTable> {
  $$GameRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get livesLost => $composableBuilder(
    column: $table.livesLost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxLives => $composableBuilder(
    column: $table.maxLives,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timePlayed => $composableBuilder(
    column: $table.timePlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestCombo => $composableBuilder(
    column: $table.bestCombo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catches => $composableBuilder(
    column: $table.catches,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smileScore => $composableBuilder(
    column: $table.smileScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNewBest => $composableBuilder(
    column: $table.isNewBest,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameRecordsTableOrderingComposer
    extends Composer<_$GameDatabase, $GameRecordsTable> {
  $$GameRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get livesLost => $composableBuilder(
    column: $table.livesLost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxLives => $composableBuilder(
    column: $table.maxLives,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timePlayed => $composableBuilder(
    column: $table.timePlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestCombo => $composableBuilder(
    column: $table.bestCombo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catches => $composableBuilder(
    column: $table.catches,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smileScore => $composableBuilder(
    column: $table.smileScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNewBest => $composableBuilder(
    column: $table.isNewBest,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameRecordsTableAnnotationComposer
    extends Composer<_$GameDatabase, $GameRecordsTable> {
  $$GameRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get livesLost =>
      $composableBuilder(column: $table.livesLost, builder: (column) => column);

  GeneratedColumn<int> get maxLives =>
      $composableBuilder(column: $table.maxLives, builder: (column) => column);

  GeneratedColumn<int> get timePlayed => $composableBuilder(
    column: $table.timePlayed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bestCombo =>
      $composableBuilder(column: $table.bestCombo, builder: (column) => column);

  GeneratedColumn<int> get catches =>
      $composableBuilder(column: $table.catches, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<int> get smileScore => $composableBuilder(
    column: $table.smileScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get isNewBest =>
      $composableBuilder(column: $table.isNewBest, builder: (column) => column);
}

class $$GameRecordsTableTableManager
    extends
        RootTableManager<
          _$GameDatabase,
          $GameRecordsTable,
          GameRecord,
          $$GameRecordsTableFilterComposer,
          $$GameRecordsTableOrderingComposer,
          $$GameRecordsTableAnnotationComposer,
          $$GameRecordsTableCreateCompanionBuilder,
          $$GameRecordsTableUpdateCompanionBuilder,
          (
            GameRecord,
            BaseReferences<_$GameDatabase, $GameRecordsTable, GameRecord>,
          ),
          GameRecord,
          PrefetchHooks Function()
        > {
  $$GameRecordsTableTableManager(_$GameDatabase db, $GameRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$GameRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$GameRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$GameRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> livesLost = const Value.absent(),
                Value<int> maxLives = const Value.absent(),
                Value<int> timePlayed = const Value.absent(),
                Value<int> bestCombo = const Value.absent(),
                Value<int> catches = const Value.absent(),
                Value<double> accuracy = const Value.absent(),
                Value<int> smileScore = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<bool> isNewBest = const Value.absent(),
              }) => GameRecordsCompanion(
                id: id,
                score: score,
                livesLost: livesLost,
                maxLives: maxLives,
                timePlayed: timePlayed,
                bestCombo: bestCombo,
                catches: catches,
                accuracy: accuracy,
                smileScore: smileScore,
                startedAt: startedAt,
                endedAt: endedAt,
                state: state,
                isNewBest: isNewBest,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int score,
                required int livesLost,
                required int maxLives,
                required int timePlayed,
                required int bestCombo,
                required int catches,
                required double accuracy,
                required int smileScore,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required int state,
                required bool isNewBest,
              }) => GameRecordsCompanion.insert(
                id: id,
                score: score,
                livesLost: livesLost,
                maxLives: maxLives,
                timePlayed: timePlayed,
                bestCombo: bestCombo,
                catches: catches,
                accuracy: accuracy,
                smileScore: smileScore,
                startedAt: startedAt,
                endedAt: endedAt,
                state: state,
                isNewBest: isNewBest,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$GameDatabase,
      $GameRecordsTable,
      GameRecord,
      $$GameRecordsTableFilterComposer,
      $$GameRecordsTableOrderingComposer,
      $$GameRecordsTableAnnotationComposer,
      $$GameRecordsTableCreateCompanionBuilder,
      $$GameRecordsTableUpdateCompanionBuilder,
      (
        GameRecord,
        BaseReferences<_$GameDatabase, $GameRecordsTable, GameRecord>,
      ),
      GameRecord,
      PrefetchHooks Function()
    >;

class $GameDatabaseManager {
  final _$GameDatabase _db;
  $GameDatabaseManager(this._db);
  $$GameRecordsTableTableManager get gameRecords =>
      $$GameRecordsTableTableManager(_db, _db.gameRecords);
}
