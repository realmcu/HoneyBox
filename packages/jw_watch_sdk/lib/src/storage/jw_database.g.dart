// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jw_database.dart';

// ignore_for_file: type=lint
class $JwActivitiesTable extends JwActivities
    with TableInfo<$JwActivitiesTable, JwActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
      'steps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _distanceMeta =
      const VerificationMeta('distance');
  @override
  late final GeneratedColumn<int> distance = GeneratedColumn<int>(
      'distance', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
      'energy', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _activeTimeMeta =
      const VerificationMeta('activeTime');
  @override
  late final GeneratedColumn<int> activeTime = GeneratedColumn<int>(
      'active_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
      'mode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, deviceMac, time, steps, distance, energy, activeTime, mode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_activity';
  @override
  VerificationContext validateIntegrity(Insertable<JwActivity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
          _stepsMeta, steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta));
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta,
          distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    } else if (isInserting) {
      context.missing(_distanceMeta);
    }
    if (data.containsKey('energy')) {
      context.handle(_energyMeta,
          energy.isAcceptableOrUnknown(data['energy']!, _energyMeta));
    } else if (isInserting) {
      context.missing(_energyMeta);
    }
    if (data.containsKey('active_time')) {
      context.handle(
          _activeTimeMeta,
          activeTime.isAcceptableOrUnknown(
              data['active_time']!, _activeTimeMeta));
    } else if (isInserting) {
      context.missing(_activeTimeMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwActivity(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      steps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}steps'])!,
      distance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}distance'])!,
      energy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}energy'])!,
      activeTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}active_time'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mode'])!,
    );
  }

  @override
  $JwActivitiesTable createAlias(String alias) {
    return $JwActivitiesTable(attachedDatabase, alias);
  }
}

class JwActivity extends DataClass implements Insertable<JwActivity> {
  final String userId;
  final String deviceMac;
  final int time;
  final int steps;
  final int distance;
  final int energy;
  final int activeTime;
  final int mode;
  const JwActivity(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.steps,
      required this.distance,
      required this.energy,
      required this.activeTime,
      required this.mode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['steps'] = Variable<int>(steps);
    map['distance'] = Variable<int>(distance);
    map['energy'] = Variable<int>(energy);
    map['active_time'] = Variable<int>(activeTime);
    map['mode'] = Variable<int>(mode);
    return map;
  }

  JwActivitiesCompanion toCompanion(bool nullToAbsent) {
    return JwActivitiesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      steps: Value(steps),
      distance: Value(distance),
      energy: Value(energy),
      activeTime: Value(activeTime),
      mode: Value(mode),
    );
  }

  factory JwActivity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwActivity(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      steps: serializer.fromJson<int>(json['steps']),
      distance: serializer.fromJson<int>(json['distance']),
      energy: serializer.fromJson<int>(json['energy']),
      activeTime: serializer.fromJson<int>(json['activeTime']),
      mode: serializer.fromJson<int>(json['mode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'steps': serializer.toJson<int>(steps),
      'distance': serializer.toJson<int>(distance),
      'energy': serializer.toJson<int>(energy),
      'activeTime': serializer.toJson<int>(activeTime),
      'mode': serializer.toJson<int>(mode),
    };
  }

  JwActivity copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? steps,
          int? distance,
          int? energy,
          int? activeTime,
          int? mode}) =>
      JwActivity(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        steps: steps ?? this.steps,
        distance: distance ?? this.distance,
        energy: energy ?? this.energy,
        activeTime: activeTime ?? this.activeTime,
        mode: mode ?? this.mode,
      );
  JwActivity copyWithCompanion(JwActivitiesCompanion data) {
    return JwActivity(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      steps: data.steps.present ? data.steps.value : this.steps,
      distance: data.distance.present ? data.distance.value : this.distance,
      energy: data.energy.present ? data.energy.value : this.energy,
      activeTime:
          data.activeTime.present ? data.activeTime.value : this.activeTime,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwActivity(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('steps: $steps, ')
          ..write('distance: $distance, ')
          ..write('energy: $energy, ')
          ..write('activeTime: $activeTime, ')
          ..write('mode: $mode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId, deviceMac, time, steps, distance, energy, activeTime, mode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwActivity &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.steps == this.steps &&
          other.distance == this.distance &&
          other.energy == this.energy &&
          other.activeTime == this.activeTime &&
          other.mode == this.mode);
}

class JwActivitiesCompanion extends UpdateCompanion<JwActivity> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> steps;
  final Value<int> distance;
  final Value<int> energy;
  final Value<int> activeTime;
  final Value<int> mode;
  final Value<int> rowid;
  const JwActivitiesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.steps = const Value.absent(),
    this.distance = const Value.absent(),
    this.energy = const Value.absent(),
    this.activeTime = const Value.absent(),
    this.mode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwActivitiesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int steps,
    required int distance,
    required int energy,
    required int activeTime,
    required int mode,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        steps = Value(steps),
        distance = Value(distance),
        energy = Value(energy),
        activeTime = Value(activeTime),
        mode = Value(mode);
  static Insertable<JwActivity> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? steps,
    Expression<int>? distance,
    Expression<int>? energy,
    Expression<int>? activeTime,
    Expression<int>? mode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (steps != null) 'steps': steps,
      if (distance != null) 'distance': distance,
      if (energy != null) 'energy': energy,
      if (activeTime != null) 'active_time': activeTime,
      if (mode != null) 'mode': mode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwActivitiesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? steps,
      Value<int>? distance,
      Value<int>? energy,
      Value<int>? activeTime,
      Value<int>? mode,
      Value<int>? rowid}) {
    return JwActivitiesCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      energy: energy ?? this.energy,
      activeTime: activeTime ?? this.activeTime,
      mode: mode ?? this.mode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distance.present) {
      map['distance'] = Variable<int>(distance.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (activeTime.present) {
      map['active_time'] = Variable<int>(activeTime.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwActivitiesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('steps: $steps, ')
          ..write('distance: $distance, ')
          ..write('energy: $energy, ')
          ..write('activeTime: $activeTime, ')
          ..write('mode: $mode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwSleepsTable extends JwSleeps with TableInfo<$JwSleepsTable, JwSleep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwSleepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
      'mode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, mode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_sleep';
  @override
  VerificationContext validateIntegrity(Insertable<JwSleep> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwSleep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwSleep(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mode'])!,
    );
  }

  @override
  $JwSleepsTable createAlias(String alias) {
    return $JwSleepsTable(attachedDatabase, alias);
  }
}

class JwSleep extends DataClass implements Insertable<JwSleep> {
  final String userId;
  final String deviceMac;
  final int time;
  final int mode;
  const JwSleep(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.mode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['mode'] = Variable<int>(mode);
    return map;
  }

  JwSleepsCompanion toCompanion(bool nullToAbsent) {
    return JwSleepsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      mode: Value(mode),
    );
  }

  factory JwSleep.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwSleep(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      mode: serializer.fromJson<int>(json['mode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'mode': serializer.toJson<int>(mode),
    };
  }

  JwSleep copyWith({String? userId, String? deviceMac, int? time, int? mode}) =>
      JwSleep(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        mode: mode ?? this.mode,
      );
  JwSleep copyWithCompanion(JwSleepsCompanion data) {
    return JwSleep(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwSleep(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, mode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwSleep &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.mode == this.mode);
}

class JwSleepsCompanion extends UpdateCompanion<JwSleep> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> mode;
  final Value<int> rowid;
  const JwSleepsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.mode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwSleepsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int mode,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        mode = Value(mode);
  static Insertable<JwSleep> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? mode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (mode != null) 'mode': mode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwSleepsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? mode,
      Value<int>? rowid}) {
    return JwSleepsCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwSleepsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwHeartRatesTable extends JwHeartRates
    with TableInfo<$JwHeartRatesTable, JwHeartRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwHeartRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _heartRateMeta =
      const VerificationMeta('heartRate');
  @override
  late final GeneratedColumn<int> heartRate = GeneratedColumn<int>(
      'heart_rate', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, heartRate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_heart_rate';
  @override
  VerificationContext validateIntegrity(Insertable<JwHeartRate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('heart_rate')) {
      context.handle(_heartRateMeta,
          heartRate.isAcceptableOrUnknown(data['heart_rate']!, _heartRateMeta));
    } else if (isInserting) {
      context.missing(_heartRateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwHeartRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwHeartRate(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      heartRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heart_rate'])!,
    );
  }

  @override
  $JwHeartRatesTable createAlias(String alias) {
    return $JwHeartRatesTable(attachedDatabase, alias);
  }
}

class JwHeartRate extends DataClass implements Insertable<JwHeartRate> {
  final String userId;
  final String deviceMac;
  final int time;
  final int heartRate;
  const JwHeartRate(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.heartRate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['heart_rate'] = Variable<int>(heartRate);
    return map;
  }

  JwHeartRatesCompanion toCompanion(bool nullToAbsent) {
    return JwHeartRatesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      heartRate: Value(heartRate),
    );
  }

  factory JwHeartRate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwHeartRate(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      heartRate: serializer.fromJson<int>(json['heartRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'heartRate': serializer.toJson<int>(heartRate),
    };
  }

  JwHeartRate copyWith(
          {String? userId, String? deviceMac, int? time, int? heartRate}) =>
      JwHeartRate(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        heartRate: heartRate ?? this.heartRate,
      );
  JwHeartRate copyWithCompanion(JwHeartRatesCompanion data) {
    return JwHeartRate(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      heartRate: data.heartRate.present ? data.heartRate.value : this.heartRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwHeartRate(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('heartRate: $heartRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, heartRate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwHeartRate &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.heartRate == this.heartRate);
}

class JwHeartRatesCompanion extends UpdateCompanion<JwHeartRate> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> heartRate;
  final Value<int> rowid;
  const JwHeartRatesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwHeartRatesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int heartRate,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        heartRate = Value(heartRate);
  static Insertable<JwHeartRate> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? heartRate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (heartRate != null) 'heart_rate': heartRate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwHeartRatesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? heartRate,
      Value<int>? rowid}) {
    return JwHeartRatesCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      heartRate: heartRate ?? this.heartRate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (heartRate.present) {
      map['heart_rate'] = Variable<int>(heartRate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwHeartRatesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('heartRate: $heartRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwBloodPressuresTable extends JwBloodPressures
    with TableInfo<$JwBloodPressuresTable, JwBloodPressure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwBloodPressuresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _systolicMeta =
      const VerificationMeta('systolic');
  @override
  late final GeneratedColumn<int> systolic = GeneratedColumn<int>(
      'systolic', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _diastolicMeta =
      const VerificationMeta('diastolic');
  @override
  late final GeneratedColumn<int> diastolic = GeneratedColumn<int>(
      'diastolic', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, deviceMac, time, systolic, diastolic];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_blood_pressure';
  @override
  VerificationContext validateIntegrity(Insertable<JwBloodPressure> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('systolic')) {
      context.handle(_systolicMeta,
          systolic.isAcceptableOrUnknown(data['systolic']!, _systolicMeta));
    } else if (isInserting) {
      context.missing(_systolicMeta);
    }
    if (data.containsKey('diastolic')) {
      context.handle(_diastolicMeta,
          diastolic.isAcceptableOrUnknown(data['diastolic']!, _diastolicMeta));
    } else if (isInserting) {
      context.missing(_diastolicMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwBloodPressure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwBloodPressure(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      systolic: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}systolic'])!,
      diastolic: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}diastolic'])!,
    );
  }

  @override
  $JwBloodPressuresTable createAlias(String alias) {
    return $JwBloodPressuresTable(attachedDatabase, alias);
  }
}

class JwBloodPressure extends DataClass implements Insertable<JwBloodPressure> {
  final String userId;
  final String deviceMac;
  final int time;
  final int systolic;
  final int diastolic;
  const JwBloodPressure(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.systolic,
      required this.diastolic});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['systolic'] = Variable<int>(systolic);
    map['diastolic'] = Variable<int>(diastolic);
    return map;
  }

  JwBloodPressuresCompanion toCompanion(bool nullToAbsent) {
    return JwBloodPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      systolic: Value(systolic),
      diastolic: Value(diastolic),
    );
  }

  factory JwBloodPressure.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwBloodPressure(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      systolic: serializer.fromJson<int>(json['systolic']),
      diastolic: serializer.fromJson<int>(json['diastolic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'systolic': serializer.toJson<int>(systolic),
      'diastolic': serializer.toJson<int>(diastolic),
    };
  }

  JwBloodPressure copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? systolic,
          int? diastolic}) =>
      JwBloodPressure(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        systolic: systolic ?? this.systolic,
        diastolic: diastolic ?? this.diastolic,
      );
  JwBloodPressure copyWithCompanion(JwBloodPressuresCompanion data) {
    return JwBloodPressure(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      systolic: data.systolic.present ? data.systolic.value : this.systolic,
      diastolic: data.diastolic.present ? data.diastolic.value : this.diastolic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodPressure(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('systolic: $systolic, ')
          ..write('diastolic: $diastolic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, systolic, diastolic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwBloodPressure &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.systolic == this.systolic &&
          other.diastolic == this.diastolic);
}

class JwBloodPressuresCompanion extends UpdateCompanion<JwBloodPressure> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> systolic;
  final Value<int> diastolic;
  final Value<int> rowid;
  const JwBloodPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.systolic = const Value.absent(),
    this.diastolic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwBloodPressuresCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int systolic,
    required int diastolic,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        systolic = Value(systolic),
        diastolic = Value(diastolic);
  static Insertable<JwBloodPressure> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? systolic,
    Expression<int>? diastolic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwBloodPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? systolic,
      Value<int>? diastolic,
      Value<int>? rowid}) {
    return JwBloodPressuresCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (systolic.present) {
      map['systolic'] = Variable<int>(systolic.value);
    }
    if (diastolic.present) {
      map['diastolic'] = Variable<int>(diastolic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodPressuresCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('systolic: $systolic, ')
          ..write('diastolic: $diastolic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwBloodOxygensTable extends JwBloodOxygens
    with TableInfo<$JwBloodOxygensTable, JwBloodOxygen> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwBloodOxygensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
      'value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<int> high = GeneratedColumn<int>(
      'high', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<int> low = GeneratedColumn<int>(
      'low', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, deviceMac, time, value, high, low];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_blood_oxygen';
  @override
  VerificationContext validateIntegrity(Insertable<JwBloodOxygen> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('high')) {
      context.handle(
          _highMeta, high.isAcceptableOrUnknown(data['high']!, _highMeta));
    }
    if (data.containsKey('low')) {
      context.handle(
          _lowMeta, low.isAcceptableOrUnknown(data['low']!, _lowMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwBloodOxygen map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwBloodOxygen(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value'])!,
      high: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}high']),
      low: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}low']),
    );
  }

  @override
  $JwBloodOxygensTable createAlias(String alias) {
    return $JwBloodOxygensTable(attachedDatabase, alias);
  }
}

class JwBloodOxygen extends DataClass implements Insertable<JwBloodOxygen> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  final int? high;
  final int? low;
  const JwBloodOxygen(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.value,
      this.high,
      this.low});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['value'] = Variable<int>(value);
    if (!nullToAbsent || high != null) {
      map['high'] = Variable<int>(high);
    }
    if (!nullToAbsent || low != null) {
      map['low'] = Variable<int>(low);
    }
    return map;
  }

  JwBloodOxygensCompanion toCompanion(bool nullToAbsent) {
    return JwBloodOxygensCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
    );
  }

  factory JwBloodOxygen.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwBloodOxygen(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      value: serializer.fromJson<int>(json['value']),
      high: serializer.fromJson<int?>(json['high']),
      low: serializer.fromJson<int?>(json['low']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'value': serializer.toJson<int>(value),
      'high': serializer.toJson<int?>(high),
      'low': serializer.toJson<int?>(low),
    };
  }

  JwBloodOxygen copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? value,
          Value<int?> high = const Value.absent(),
          Value<int?> low = const Value.absent()}) =>
      JwBloodOxygen(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
        high: high.present ? high.value : this.high,
        low: low.present ? low.value : this.low,
      );
  JwBloodOxygen copyWithCompanion(JwBloodOxygensCompanion data) {
    return JwBloodOxygen(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
      high: data.high.present ? data.high.value : this.high,
      low: data.low.present ? data.low.value : this.low,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodOxygen(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('high: $high, ')
          ..write('low: $low')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, value, high, low);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwBloodOxygen &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value &&
          other.high == this.high &&
          other.low == this.low);
}

class JwBloodOxygensCompanion extends UpdateCompanion<JwBloodOxygen> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int?> high;
  final Value<int?> low;
  final Value<int> rowid;
  const JwBloodOxygensCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwBloodOxygensCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<JwBloodOxygen> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? value,
    Expression<int>? high,
    Expression<int>? low,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (value != null) 'value': value,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwBloodOxygensCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int?>? high,
      Value<int?>? low,
      Value<int>? rowid}) {
    return JwBloodOxygensCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      value: value ?? this.value,
      high: high ?? this.high,
      low: low ?? this.low,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (high.present) {
      map['high'] = Variable<int>(high.value);
    }
    if (low.present) {
      map['low'] = Variable<int>(low.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodOxygensCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwHrvsTable extends JwHrvs with TableInfo<$JwHrvsTable, JwHrv> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwHrvsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sdnnMeta = const VerificationMeta('sdnn');
  @override
  late final GeneratedColumn<int> sdnn = GeneratedColumn<int>(
      'sdnn', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, sdnn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_hrv';
  @override
  VerificationContext validateIntegrity(Insertable<JwHrv> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('sdnn')) {
      context.handle(
          _sdnnMeta, sdnn.isAcceptableOrUnknown(data['sdnn']!, _sdnnMeta));
    } else if (isInserting) {
      context.missing(_sdnnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwHrv map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwHrv(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      sdnn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sdnn'])!,
    );
  }

  @override
  $JwHrvsTable createAlias(String alias) {
    return $JwHrvsTable(attachedDatabase, alias);
  }
}

class JwHrv extends DataClass implements Insertable<JwHrv> {
  final String userId;
  final String deviceMac;
  final int time;
  final int sdnn;
  const JwHrv(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.sdnn});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['sdnn'] = Variable<int>(sdnn);
    return map;
  }

  JwHrvsCompanion toCompanion(bool nullToAbsent) {
    return JwHrvsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      sdnn: Value(sdnn),
    );
  }

  factory JwHrv.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwHrv(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      sdnn: serializer.fromJson<int>(json['sdnn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'sdnn': serializer.toJson<int>(sdnn),
    };
  }

  JwHrv copyWith({String? userId, String? deviceMac, int? time, int? sdnn}) =>
      JwHrv(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        sdnn: sdnn ?? this.sdnn,
      );
  JwHrv copyWithCompanion(JwHrvsCompanion data) {
    return JwHrv(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      sdnn: data.sdnn.present ? data.sdnn.value : this.sdnn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwHrv(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('sdnn: $sdnn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, sdnn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwHrv &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.sdnn == this.sdnn);
}

class JwHrvsCompanion extends UpdateCompanion<JwHrv> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> sdnn;
  final Value<int> rowid;
  const JwHrvsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.sdnn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwHrvsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int sdnn,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        sdnn = Value(sdnn);
  static Insertable<JwHrv> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? sdnn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (sdnn != null) 'sdnn': sdnn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwHrvsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? sdnn,
      Value<int>? rowid}) {
    return JwHrvsCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      sdnn: sdnn ?? this.sdnn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (sdnn.present) {
      map['sdnn'] = Variable<int>(sdnn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwHrvsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('sdnn: $sdnn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwPressuresTable extends JwPressures
    with TableInfo<$JwPressuresTable, JwPressure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwPressuresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
      'value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_pressure';
  @override
  VerificationContext validateIntegrity(Insertable<JwPressure> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwPressure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwPressure(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $JwPressuresTable createAlias(String alias) {
    return $JwPressuresTable(attachedDatabase, alias);
  }
}

class JwPressure extends DataClass implements Insertable<JwPressure> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const JwPressure(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['value'] = Variable<int>(value);
    return map;
  }

  JwPressuresCompanion toCompanion(bool nullToAbsent) {
    return JwPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory JwPressure.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwPressure(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'value': serializer.toJson<int>(value),
    };
  }

  JwPressure copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      JwPressure(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  JwPressure copyWithCompanion(JwPressuresCompanion data) {
    return JwPressure(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwPressure(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwPressure &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class JwPressuresCompanion extends UpdateCompanion<JwPressure> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const JwPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwPressuresCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<JwPressure> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return JwPressuresCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwPressuresCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwTemperaturesTable extends JwTemperatures
    with TableInfo<$JwTemperaturesTable, JwTemperature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwTemperaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _skinTemperatureMeta =
      const VerificationMeta('skinTemperature');
  @override
  late final GeneratedColumn<double> skinTemperature = GeneratedColumn<double>(
      'skin_temperature', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _heatStressMeta =
      const VerificationMeta('heatStress');
  @override
  late final GeneratedColumn<int> heatStress = GeneratedColumn<int>(
      'heat_stress', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _wornMeta = const VerificationMeta('worn');
  @override
  late final GeneratedColumn<bool> worn = GeneratedColumn<bool>(
      'worn', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("worn" IN (0, 1))'));
  static const VerificationMeta _compensatedMeta =
      const VerificationMeta('compensated');
  @override
  late final GeneratedColumn<bool> compensated = GeneratedColumn<bool>(
      'compensated', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("compensated" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns =>
      [userId, deviceMac, time, skinTemperature, heatStress, worn, compensated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_temperature';
  @override
  VerificationContext validateIntegrity(Insertable<JwTemperature> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('skin_temperature')) {
      context.handle(
          _skinTemperatureMeta,
          skinTemperature.isAcceptableOrUnknown(
              data['skin_temperature']!, _skinTemperatureMeta));
    } else if (isInserting) {
      context.missing(_skinTemperatureMeta);
    }
    if (data.containsKey('heat_stress')) {
      context.handle(
          _heatStressMeta,
          heatStress.isAcceptableOrUnknown(
              data['heat_stress']!, _heatStressMeta));
    } else if (isInserting) {
      context.missing(_heatStressMeta);
    }
    if (data.containsKey('worn')) {
      context.handle(
          _wornMeta, worn.isAcceptableOrUnknown(data['worn']!, _wornMeta));
    } else if (isInserting) {
      context.missing(_wornMeta);
    }
    if (data.containsKey('compensated')) {
      context.handle(
          _compensatedMeta,
          compensated.isAcceptableOrUnknown(
              data['compensated']!, _compensatedMeta));
    } else if (isInserting) {
      context.missing(_compensatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwTemperature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwTemperature(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      skinTemperature: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}skin_temperature'])!,
      heatStress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heat_stress'])!,
      worn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}worn'])!,
      compensated: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}compensated'])!,
    );
  }

  @override
  $JwTemperaturesTable createAlias(String alias) {
    return $JwTemperaturesTable(attachedDatabase, alias);
  }
}

class JwTemperature extends DataClass implements Insertable<JwTemperature> {
  final String userId;
  final String deviceMac;
  final int time;
  final double skinTemperature;
  final int heatStress;
  final bool worn;
  final bool compensated;
  const JwTemperature(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.skinTemperature,
      required this.heatStress,
      required this.worn,
      required this.compensated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['skin_temperature'] = Variable<double>(skinTemperature);
    map['heat_stress'] = Variable<int>(heatStress);
    map['worn'] = Variable<bool>(worn);
    map['compensated'] = Variable<bool>(compensated);
    return map;
  }

  JwTemperaturesCompanion toCompanion(bool nullToAbsent) {
    return JwTemperaturesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      skinTemperature: Value(skinTemperature),
      heatStress: Value(heatStress),
      worn: Value(worn),
      compensated: Value(compensated),
    );
  }

  factory JwTemperature.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwTemperature(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      skinTemperature: serializer.fromJson<double>(json['skinTemperature']),
      heatStress: serializer.fromJson<int>(json['heatStress']),
      worn: serializer.fromJson<bool>(json['worn']),
      compensated: serializer.fromJson<bool>(json['compensated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'skinTemperature': serializer.toJson<double>(skinTemperature),
      'heatStress': serializer.toJson<int>(heatStress),
      'worn': serializer.toJson<bool>(worn),
      'compensated': serializer.toJson<bool>(compensated),
    };
  }

  JwTemperature copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          double? skinTemperature,
          int? heatStress,
          bool? worn,
          bool? compensated}) =>
      JwTemperature(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        skinTemperature: skinTemperature ?? this.skinTemperature,
        heatStress: heatStress ?? this.heatStress,
        worn: worn ?? this.worn,
        compensated: compensated ?? this.compensated,
      );
  JwTemperature copyWithCompanion(JwTemperaturesCompanion data) {
    return JwTemperature(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      skinTemperature: data.skinTemperature.present
          ? data.skinTemperature.value
          : this.skinTemperature,
      heatStress:
          data.heatStress.present ? data.heatStress.value : this.heatStress,
      worn: data.worn.present ? data.worn.value : this.worn,
      compensated:
          data.compensated.present ? data.compensated.value : this.compensated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwTemperature(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('skinTemperature: $skinTemperature, ')
          ..write('heatStress: $heatStress, ')
          ..write('worn: $worn, ')
          ..write('compensated: $compensated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId, deviceMac, time, skinTemperature, heatStress, worn, compensated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwTemperature &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.skinTemperature == this.skinTemperature &&
          other.heatStress == this.heatStress &&
          other.worn == this.worn &&
          other.compensated == this.compensated);
}

class JwTemperaturesCompanion extends UpdateCompanion<JwTemperature> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<double> skinTemperature;
  final Value<int> heatStress;
  final Value<bool> worn;
  final Value<bool> compensated;
  final Value<int> rowid;
  const JwTemperaturesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.skinTemperature = const Value.absent(),
    this.heatStress = const Value.absent(),
    this.worn = const Value.absent(),
    this.compensated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwTemperaturesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required double skinTemperature,
    required int heatStress,
    required bool worn,
    required bool compensated,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        skinTemperature = Value(skinTemperature),
        heatStress = Value(heatStress),
        worn = Value(worn),
        compensated = Value(compensated);
  static Insertable<JwTemperature> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<double>? skinTemperature,
    Expression<int>? heatStress,
    Expression<bool>? worn,
    Expression<bool>? compensated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (skinTemperature != null) 'skin_temperature': skinTemperature,
      if (heatStress != null) 'heat_stress': heatStress,
      if (worn != null) 'worn': worn,
      if (compensated != null) 'compensated': compensated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwTemperaturesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<double>? skinTemperature,
      Value<int>? heatStress,
      Value<bool>? worn,
      Value<bool>? compensated,
      Value<int>? rowid}) {
    return JwTemperaturesCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      skinTemperature: skinTemperature ?? this.skinTemperature,
      heatStress: heatStress ?? this.heatStress,
      worn: worn ?? this.worn,
      compensated: compensated ?? this.compensated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (skinTemperature.present) {
      map['skin_temperature'] = Variable<double>(skinTemperature.value);
    }
    if (heatStress.present) {
      map['heat_stress'] = Variable<int>(heatStress.value);
    }
    if (worn.present) {
      map['worn'] = Variable<bool>(worn.value);
    }
    if (compensated.present) {
      map['compensated'] = Variable<bool>(compensated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwTemperaturesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('skinTemperature: $skinTemperature, ')
          ..write('heatStress: $heatStress, ')
          ..write('worn: $worn, ')
          ..write('compensated: $compensated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwBloodGlucosesTable extends JwBloodGlucoses
    with TableInfo<$JwBloodGlucosesTable, JwBloodGlucose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwBloodGlucosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
      'value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_blood_glucose';
  @override
  VerificationContext validateIntegrity(Insertable<JwBloodGlucose> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwBloodGlucose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwBloodGlucose(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $JwBloodGlucosesTable createAlias(String alias) {
    return $JwBloodGlucosesTable(attachedDatabase, alias);
  }
}

class JwBloodGlucose extends DataClass implements Insertable<JwBloodGlucose> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const JwBloodGlucose(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['value'] = Variable<int>(value);
    return map;
  }

  JwBloodGlucosesCompanion toCompanion(bool nullToAbsent) {
    return JwBloodGlucosesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory JwBloodGlucose.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwBloodGlucose(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'value': serializer.toJson<int>(value),
    };
  }

  JwBloodGlucose copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      JwBloodGlucose(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  JwBloodGlucose copyWithCompanion(JwBloodGlucosesCompanion data) {
    return JwBloodGlucose(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodGlucose(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwBloodGlucose &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class JwBloodGlucosesCompanion extends UpdateCompanion<JwBloodGlucose> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const JwBloodGlucosesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwBloodGlucosesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<JwBloodGlucose> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwBloodGlucosesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return JwBloodGlucosesCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwBloodGlucosesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JwSportsTable extends JwSports with TableInfo<$JwSportsTable, JwSport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JwSportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMacMeta =
      const VerificationMeta('deviceMac');
  @override
  late final GeneratedColumn<String> deviceMac = GeneratedColumn<String>(
      'device_mac', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
      'time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
      'mode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pauseCountMeta =
      const VerificationMeta('pauseCount');
  @override
  late final GeneratedColumn<int> pauseCount = GeneratedColumn<int>(
      'pause_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pauseDurationMeta =
      const VerificationMeta('pauseDuration');
  @override
  late final GeneratedColumn<int> pauseDuration = GeneratedColumn<int>(
      'pause_duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
      'steps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _distanceMeta =
      const VerificationMeta('distance');
  @override
  late final GeneratedColumn<int> distance = GeneratedColumn<int>(
      'distance', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
      'energy', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _heartRateMaxMeta =
      const VerificationMeta('heartRateMax');
  @override
  late final GeneratedColumn<int> heartRateMax = GeneratedColumn<int>(
      'heart_rate_max', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heartRateAverageMeta =
      const VerificationMeta('heartRateAverage');
  @override
  late final GeneratedColumn<int> heartRateAverage = GeneratedColumn<int>(
      'heart_rate_average', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heartRateMinMeta =
      const VerificationMeta('heartRateMin');
  @override
  late final GeneratedColumn<int> heartRateMin = GeneratedColumn<int>(
      'heart_rate_min', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        deviceMac,
        time,
        mode,
        duration,
        pauseCount,
        pauseDuration,
        steps,
        distance,
        energy,
        heartRateMax,
        heartRateAverage,
        heartRateMin
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jw_sport';
  @override
  VerificationContext validateIntegrity(Insertable<JwSport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_mac')) {
      context.handle(_deviceMacMeta,
          deviceMac.isAcceptableOrUnknown(data['device_mac']!, _deviceMacMeta));
    } else if (isInserting) {
      context.missing(_deviceMacMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('pause_count')) {
      context.handle(
          _pauseCountMeta,
          pauseCount.isAcceptableOrUnknown(
              data['pause_count']!, _pauseCountMeta));
    } else if (isInserting) {
      context.missing(_pauseCountMeta);
    }
    if (data.containsKey('pause_duration')) {
      context.handle(
          _pauseDurationMeta,
          pauseDuration.isAcceptableOrUnknown(
              data['pause_duration']!, _pauseDurationMeta));
    } else if (isInserting) {
      context.missing(_pauseDurationMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
          _stepsMeta, steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta));
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta,
          distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    } else if (isInserting) {
      context.missing(_distanceMeta);
    }
    if (data.containsKey('energy')) {
      context.handle(_energyMeta,
          energy.isAcceptableOrUnknown(data['energy']!, _energyMeta));
    } else if (isInserting) {
      context.missing(_energyMeta);
    }
    if (data.containsKey('heart_rate_max')) {
      context.handle(
          _heartRateMaxMeta,
          heartRateMax.isAcceptableOrUnknown(
              data['heart_rate_max']!, _heartRateMaxMeta));
    }
    if (data.containsKey('heart_rate_average')) {
      context.handle(
          _heartRateAverageMeta,
          heartRateAverage.isAcceptableOrUnknown(
              data['heart_rate_average']!, _heartRateAverageMeta));
    }
    if (data.containsKey('heart_rate_min')) {
      context.handle(
          _heartRateMinMeta,
          heartRateMin.isAcceptableOrUnknown(
              data['heart_rate_min']!, _heartRateMinMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  JwSport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JwSport(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mode'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      pauseCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pause_count'])!,
      pauseDuration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pause_duration'])!,
      steps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}steps'])!,
      distance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}distance'])!,
      energy: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}energy'])!,
      heartRateMax: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heart_rate_max']),
      heartRateAverage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heart_rate_average']),
      heartRateMin: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heart_rate_min']),
    );
  }

  @override
  $JwSportsTable createAlias(String alias) {
    return $JwSportsTable(attachedDatabase, alias);
  }
}

class JwSport extends DataClass implements Insertable<JwSport> {
  final String userId;
  final String deviceMac;
  final int time;
  final int mode;
  final int duration;
  final int pauseCount;
  final int pauseDuration;
  final int steps;
  final int distance;
  final int energy;
  final int? heartRateMax;
  final int? heartRateAverage;
  final int? heartRateMin;
  const JwSport(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.mode,
      required this.duration,
      required this.pauseCount,
      required this.pauseDuration,
      required this.steps,
      required this.distance,
      required this.energy,
      this.heartRateMax,
      this.heartRateAverage,
      this.heartRateMin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['mode'] = Variable<int>(mode);
    map['duration'] = Variable<int>(duration);
    map['pause_count'] = Variable<int>(pauseCount);
    map['pause_duration'] = Variable<int>(pauseDuration);
    map['steps'] = Variable<int>(steps);
    map['distance'] = Variable<int>(distance);
    map['energy'] = Variable<int>(energy);
    if (!nullToAbsent || heartRateMax != null) {
      map['heart_rate_max'] = Variable<int>(heartRateMax);
    }
    if (!nullToAbsent || heartRateAverage != null) {
      map['heart_rate_average'] = Variable<int>(heartRateAverage);
    }
    if (!nullToAbsent || heartRateMin != null) {
      map['heart_rate_min'] = Variable<int>(heartRateMin);
    }
    return map;
  }

  JwSportsCompanion toCompanion(bool nullToAbsent) {
    return JwSportsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      mode: Value(mode),
      duration: Value(duration),
      pauseCount: Value(pauseCount),
      pauseDuration: Value(pauseDuration),
      steps: Value(steps),
      distance: Value(distance),
      energy: Value(energy),
      heartRateMax: heartRateMax == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRateMax),
      heartRateAverage: heartRateAverage == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRateAverage),
      heartRateMin: heartRateMin == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRateMin),
    );
  }

  factory JwSport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JwSport(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      mode: serializer.fromJson<int>(json['mode']),
      duration: serializer.fromJson<int>(json['duration']),
      pauseCount: serializer.fromJson<int>(json['pauseCount']),
      pauseDuration: serializer.fromJson<int>(json['pauseDuration']),
      steps: serializer.fromJson<int>(json['steps']),
      distance: serializer.fromJson<int>(json['distance']),
      energy: serializer.fromJson<int>(json['energy']),
      heartRateMax: serializer.fromJson<int?>(json['heartRateMax']),
      heartRateAverage: serializer.fromJson<int?>(json['heartRateAverage']),
      heartRateMin: serializer.fromJson<int?>(json['heartRateMin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'mode': serializer.toJson<int>(mode),
      'duration': serializer.toJson<int>(duration),
      'pauseCount': serializer.toJson<int>(pauseCount),
      'pauseDuration': serializer.toJson<int>(pauseDuration),
      'steps': serializer.toJson<int>(steps),
      'distance': serializer.toJson<int>(distance),
      'energy': serializer.toJson<int>(energy),
      'heartRateMax': serializer.toJson<int?>(heartRateMax),
      'heartRateAverage': serializer.toJson<int?>(heartRateAverage),
      'heartRateMin': serializer.toJson<int?>(heartRateMin),
    };
  }

  JwSport copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? mode,
          int? duration,
          int? pauseCount,
          int? pauseDuration,
          int? steps,
          int? distance,
          int? energy,
          Value<int?> heartRateMax = const Value.absent(),
          Value<int?> heartRateAverage = const Value.absent(),
          Value<int?> heartRateMin = const Value.absent()}) =>
      JwSport(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        mode: mode ?? this.mode,
        duration: duration ?? this.duration,
        pauseCount: pauseCount ?? this.pauseCount,
        pauseDuration: pauseDuration ?? this.pauseDuration,
        steps: steps ?? this.steps,
        distance: distance ?? this.distance,
        energy: energy ?? this.energy,
        heartRateMax:
            heartRateMax.present ? heartRateMax.value : this.heartRateMax,
        heartRateAverage: heartRateAverage.present
            ? heartRateAverage.value
            : this.heartRateAverage,
        heartRateMin:
            heartRateMin.present ? heartRateMin.value : this.heartRateMin,
      );
  JwSport copyWithCompanion(JwSportsCompanion data) {
    return JwSport(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      mode: data.mode.present ? data.mode.value : this.mode,
      duration: data.duration.present ? data.duration.value : this.duration,
      pauseCount:
          data.pauseCount.present ? data.pauseCount.value : this.pauseCount,
      pauseDuration: data.pauseDuration.present
          ? data.pauseDuration.value
          : this.pauseDuration,
      steps: data.steps.present ? data.steps.value : this.steps,
      distance: data.distance.present ? data.distance.value : this.distance,
      energy: data.energy.present ? data.energy.value : this.energy,
      heartRateMax: data.heartRateMax.present
          ? data.heartRateMax.value
          : this.heartRateMax,
      heartRateAverage: data.heartRateAverage.present
          ? data.heartRateAverage.value
          : this.heartRateAverage,
      heartRateMin: data.heartRateMin.present
          ? data.heartRateMin.value
          : this.heartRateMin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JwSport(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode, ')
          ..write('duration: $duration, ')
          ..write('pauseCount: $pauseCount, ')
          ..write('pauseDuration: $pauseDuration, ')
          ..write('steps: $steps, ')
          ..write('distance: $distance, ')
          ..write('energy: $energy, ')
          ..write('heartRateMax: $heartRateMax, ')
          ..write('heartRateAverage: $heartRateAverage, ')
          ..write('heartRateMin: $heartRateMin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId,
      deviceMac,
      time,
      mode,
      duration,
      pauseCount,
      pauseDuration,
      steps,
      distance,
      energy,
      heartRateMax,
      heartRateAverage,
      heartRateMin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JwSport &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.mode == this.mode &&
          other.duration == this.duration &&
          other.pauseCount == this.pauseCount &&
          other.pauseDuration == this.pauseDuration &&
          other.steps == this.steps &&
          other.distance == this.distance &&
          other.energy == this.energy &&
          other.heartRateMax == this.heartRateMax &&
          other.heartRateAverage == this.heartRateAverage &&
          other.heartRateMin == this.heartRateMin);
}

class JwSportsCompanion extends UpdateCompanion<JwSport> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> mode;
  final Value<int> duration;
  final Value<int> pauseCount;
  final Value<int> pauseDuration;
  final Value<int> steps;
  final Value<int> distance;
  final Value<int> energy;
  final Value<int?> heartRateMax;
  final Value<int?> heartRateAverage;
  final Value<int?> heartRateMin;
  final Value<int> rowid;
  const JwSportsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.mode = const Value.absent(),
    this.duration = const Value.absent(),
    this.pauseCount = const Value.absent(),
    this.pauseDuration = const Value.absent(),
    this.steps = const Value.absent(),
    this.distance = const Value.absent(),
    this.energy = const Value.absent(),
    this.heartRateMax = const Value.absent(),
    this.heartRateAverage = const Value.absent(),
    this.heartRateMin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JwSportsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int mode,
    required int duration,
    required int pauseCount,
    required int pauseDuration,
    required int steps,
    required int distance,
    required int energy,
    this.heartRateMax = const Value.absent(),
    this.heartRateAverage = const Value.absent(),
    this.heartRateMin = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        mode = Value(mode),
        duration = Value(duration),
        pauseCount = Value(pauseCount),
        pauseDuration = Value(pauseDuration),
        steps = Value(steps),
        distance = Value(distance),
        energy = Value(energy);
  static Insertable<JwSport> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? mode,
    Expression<int>? duration,
    Expression<int>? pauseCount,
    Expression<int>? pauseDuration,
    Expression<int>? steps,
    Expression<int>? distance,
    Expression<int>? energy,
    Expression<int>? heartRateMax,
    Expression<int>? heartRateAverage,
    Expression<int>? heartRateMin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (mode != null) 'mode': mode,
      if (duration != null) 'duration': duration,
      if (pauseCount != null) 'pause_count': pauseCount,
      if (pauseDuration != null) 'pause_duration': pauseDuration,
      if (steps != null) 'steps': steps,
      if (distance != null) 'distance': distance,
      if (energy != null) 'energy': energy,
      if (heartRateMax != null) 'heart_rate_max': heartRateMax,
      if (heartRateAverage != null) 'heart_rate_average': heartRateAverage,
      if (heartRateMin != null) 'heart_rate_min': heartRateMin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JwSportsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? mode,
      Value<int>? duration,
      Value<int>? pauseCount,
      Value<int>? pauseDuration,
      Value<int>? steps,
      Value<int>? distance,
      Value<int>? energy,
      Value<int?>? heartRateMax,
      Value<int?>? heartRateAverage,
      Value<int?>? heartRateMin,
      Value<int>? rowid}) {
    return JwSportsCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      duration: duration ?? this.duration,
      pauseCount: pauseCount ?? this.pauseCount,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      energy: energy ?? this.energy,
      heartRateMax: heartRateMax ?? this.heartRateMax,
      heartRateAverage: heartRateAverage ?? this.heartRateAverage,
      heartRateMin: heartRateMin ?? this.heartRateMin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceMac.present) {
      map['device_mac'] = Variable<String>(deviceMac.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (pauseCount.present) {
      map['pause_count'] = Variable<int>(pauseCount.value);
    }
    if (pauseDuration.present) {
      map['pause_duration'] = Variable<int>(pauseDuration.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distance.present) {
      map['distance'] = Variable<int>(distance.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (heartRateMax.present) {
      map['heart_rate_max'] = Variable<int>(heartRateMax.value);
    }
    if (heartRateAverage.present) {
      map['heart_rate_average'] = Variable<int>(heartRateAverage.value);
    }
    if (heartRateMin.present) {
      map['heart_rate_min'] = Variable<int>(heartRateMin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JwSportsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode, ')
          ..write('duration: $duration, ')
          ..write('pauseCount: $pauseCount, ')
          ..write('pauseDuration: $pauseDuration, ')
          ..write('steps: $steps, ')
          ..write('distance: $distance, ')
          ..write('energy: $energy, ')
          ..write('heartRateMax: $heartRateMax, ')
          ..write('heartRateAverage: $heartRateAverage, ')
          ..write('heartRateMin: $heartRateMin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$JWDatabase extends GeneratedDatabase {
  _$JWDatabase(QueryExecutor e) : super(e);
  $JWDatabaseManager get managers => $JWDatabaseManager(this);
  late final $JwActivitiesTable jwActivities = $JwActivitiesTable(this);
  late final $JwSleepsTable jwSleeps = $JwSleepsTable(this);
  late final $JwHeartRatesTable jwHeartRates = $JwHeartRatesTable(this);
  late final $JwBloodPressuresTable jwBloodPressures =
      $JwBloodPressuresTable(this);
  late final $JwBloodOxygensTable jwBloodOxygens = $JwBloodOxygensTable(this);
  late final $JwHrvsTable jwHrvs = $JwHrvsTable(this);
  late final $JwPressuresTable jwPressures = $JwPressuresTable(this);
  late final $JwTemperaturesTable jwTemperatures = $JwTemperaturesTable(this);
  late final $JwBloodGlucosesTable jwBloodGlucoses =
      $JwBloodGlucosesTable(this);
  late final $JwSportsTable jwSports = $JwSportsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        jwActivities,
        jwSleeps,
        jwHeartRates,
        jwBloodPressures,
        jwBloodOxygens,
        jwHrvs,
        jwPressures,
        jwTemperatures,
        jwBloodGlucoses,
        jwSports
      ];
}

typedef $$JwActivitiesTableCreateCompanionBuilder = JwActivitiesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int steps,
  required int distance,
  required int energy,
  required int activeTime,
  required int mode,
  Value<int> rowid,
});
typedef $$JwActivitiesTableUpdateCompanionBuilder = JwActivitiesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> steps,
  Value<int> distance,
  Value<int> energy,
  Value<int> activeTime,
  Value<int> mode,
  Value<int> rowid,
});

class $$JwActivitiesTableFilterComposer
    extends Composer<_$JWDatabase, $JwActivitiesTable> {
  $$JwActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get energy => $composableBuilder(
      column: $table.energy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get activeTime => $composableBuilder(
      column: $table.activeTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));
}

class $$JwActivitiesTableOrderingComposer
    extends Composer<_$JWDatabase, $JwActivitiesTable> {
  $$JwActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get energy => $composableBuilder(
      column: $table.energy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get activeTime => $composableBuilder(
      column: $table.activeTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));
}

class $$JwActivitiesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwActivitiesTable> {
  $$JwActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get activeTime => $composableBuilder(
      column: $table.activeTime, builder: (column) => column);

  GeneratedColumn<int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);
}

class $$JwActivitiesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwActivitiesTable,
    JwActivity,
    $$JwActivitiesTableFilterComposer,
    $$JwActivitiesTableOrderingComposer,
    $$JwActivitiesTableAnnotationComposer,
    $$JwActivitiesTableCreateCompanionBuilder,
    $$JwActivitiesTableUpdateCompanionBuilder,
    (JwActivity, BaseReferences<_$JWDatabase, $JwActivitiesTable, JwActivity>),
    JwActivity,
    PrefetchHooks Function()> {
  $$JwActivitiesTableTableManager(_$JWDatabase db, $JwActivitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> steps = const Value.absent(),
            Value<int> distance = const Value.absent(),
            Value<int> energy = const Value.absent(),
            Value<int> activeTime = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwActivitiesCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            steps: steps,
            distance: distance,
            energy: energy,
            activeTime: activeTime,
            mode: mode,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int steps,
            required int distance,
            required int energy,
            required int activeTime,
            required int mode,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwActivitiesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            steps: steps,
            distance: distance,
            energy: energy,
            activeTime: activeTime,
            mode: mode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwActivitiesTable, JwActivity>(table),
                    BaseReferences<_$JWDatabase, $JwActivitiesTable,
                        JwActivity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwActivitiesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwActivitiesTable,
    JwActivity,
    $$JwActivitiesTableFilterComposer,
    $$JwActivitiesTableOrderingComposer,
    $$JwActivitiesTableAnnotationComposer,
    $$JwActivitiesTableCreateCompanionBuilder,
    $$JwActivitiesTableUpdateCompanionBuilder,
    (JwActivity, BaseReferences<_$JWDatabase, $JwActivitiesTable, JwActivity>),
    JwActivity,
    PrefetchHooks Function()>;
typedef $$JwSleepsTableCreateCompanionBuilder = JwSleepsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int mode,
  Value<int> rowid,
});
typedef $$JwSleepsTableUpdateCompanionBuilder = JwSleepsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> mode,
  Value<int> rowid,
});

class $$JwSleepsTableFilterComposer
    extends Composer<_$JWDatabase, $JwSleepsTable> {
  $$JwSleepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));
}

class $$JwSleepsTableOrderingComposer
    extends Composer<_$JWDatabase, $JwSleepsTable> {
  $$JwSleepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));
}

class $$JwSleepsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwSleepsTable> {
  $$JwSleepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);
}

class $$JwSleepsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwSleepsTable,
    JwSleep,
    $$JwSleepsTableFilterComposer,
    $$JwSleepsTableOrderingComposer,
    $$JwSleepsTableAnnotationComposer,
    $$JwSleepsTableCreateCompanionBuilder,
    $$JwSleepsTableUpdateCompanionBuilder,
    (JwSleep, BaseReferences<_$JWDatabase, $JwSleepsTable, JwSleep>),
    JwSleep,
    PrefetchHooks Function()> {
  $$JwSleepsTableTableManager(_$JWDatabase db, $JwSleepsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwSleepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwSleepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwSleepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwSleepsCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int mode,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwSleepsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwSleepsTable, JwSleep>(table),
                    BaseReferences<_$JWDatabase, $JwSleepsTable, JwSleep>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwSleepsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwSleepsTable,
    JwSleep,
    $$JwSleepsTableFilterComposer,
    $$JwSleepsTableOrderingComposer,
    $$JwSleepsTableAnnotationComposer,
    $$JwSleepsTableCreateCompanionBuilder,
    $$JwSleepsTableUpdateCompanionBuilder,
    (JwSleep, BaseReferences<_$JWDatabase, $JwSleepsTable, JwSleep>),
    JwSleep,
    PrefetchHooks Function()>;
typedef $$JwHeartRatesTableCreateCompanionBuilder = JwHeartRatesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int heartRate,
  Value<int> rowid,
});
typedef $$JwHeartRatesTableUpdateCompanionBuilder = JwHeartRatesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> heartRate,
  Value<int> rowid,
});

class $$JwHeartRatesTableFilterComposer
    extends Composer<_$JWDatabase, $JwHeartRatesTable> {
  $$JwHeartRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heartRate => $composableBuilder(
      column: $table.heartRate, builder: (column) => ColumnFilters(column));
}

class $$JwHeartRatesTableOrderingComposer
    extends Composer<_$JWDatabase, $JwHeartRatesTable> {
  $$JwHeartRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heartRate => $composableBuilder(
      column: $table.heartRate, builder: (column) => ColumnOrderings(column));
}

class $$JwHeartRatesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwHeartRatesTable> {
  $$JwHeartRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get heartRate =>
      $composableBuilder(column: $table.heartRate, builder: (column) => column);
}

class $$JwHeartRatesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwHeartRatesTable,
    JwHeartRate,
    $$JwHeartRatesTableFilterComposer,
    $$JwHeartRatesTableOrderingComposer,
    $$JwHeartRatesTableAnnotationComposer,
    $$JwHeartRatesTableCreateCompanionBuilder,
    $$JwHeartRatesTableUpdateCompanionBuilder,
    (
      JwHeartRate,
      BaseReferences<_$JWDatabase, $JwHeartRatesTable, JwHeartRate>
    ),
    JwHeartRate,
    PrefetchHooks Function()> {
  $$JwHeartRatesTableTableManager(_$JWDatabase db, $JwHeartRatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwHeartRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwHeartRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwHeartRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> heartRate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwHeartRatesCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            heartRate: heartRate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int heartRate,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwHeartRatesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            heartRate: heartRate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwHeartRatesTable, JwHeartRate>(table),
                    BaseReferences<_$JWDatabase, $JwHeartRatesTable,
                        JwHeartRate>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwHeartRatesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwHeartRatesTable,
    JwHeartRate,
    $$JwHeartRatesTableFilterComposer,
    $$JwHeartRatesTableOrderingComposer,
    $$JwHeartRatesTableAnnotationComposer,
    $$JwHeartRatesTableCreateCompanionBuilder,
    $$JwHeartRatesTableUpdateCompanionBuilder,
    (
      JwHeartRate,
      BaseReferences<_$JWDatabase, $JwHeartRatesTable, JwHeartRate>
    ),
    JwHeartRate,
    PrefetchHooks Function()>;
typedef $$JwBloodPressuresTableCreateCompanionBuilder
    = JwBloodPressuresCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int systolic,
  required int diastolic,
  Value<int> rowid,
});
typedef $$JwBloodPressuresTableUpdateCompanionBuilder
    = JwBloodPressuresCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> systolic,
  Value<int> diastolic,
  Value<int> rowid,
});

class $$JwBloodPressuresTableFilterComposer
    extends Composer<_$JWDatabase, $JwBloodPressuresTable> {
  $$JwBloodPressuresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get systolic => $composableBuilder(
      column: $table.systolic, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get diastolic => $composableBuilder(
      column: $table.diastolic, builder: (column) => ColumnFilters(column));
}

class $$JwBloodPressuresTableOrderingComposer
    extends Composer<_$JWDatabase, $JwBloodPressuresTable> {
  $$JwBloodPressuresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get systolic => $composableBuilder(
      column: $table.systolic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get diastolic => $composableBuilder(
      column: $table.diastolic, builder: (column) => ColumnOrderings(column));
}

class $$JwBloodPressuresTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwBloodPressuresTable> {
  $$JwBloodPressuresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get systolic =>
      $composableBuilder(column: $table.systolic, builder: (column) => column);

  GeneratedColumn<int> get diastolic =>
      $composableBuilder(column: $table.diastolic, builder: (column) => column);
}

class $$JwBloodPressuresTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwBloodPressuresTable,
    JwBloodPressure,
    $$JwBloodPressuresTableFilterComposer,
    $$JwBloodPressuresTableOrderingComposer,
    $$JwBloodPressuresTableAnnotationComposer,
    $$JwBloodPressuresTableCreateCompanionBuilder,
    $$JwBloodPressuresTableUpdateCompanionBuilder,
    (
      JwBloodPressure,
      BaseReferences<_$JWDatabase, $JwBloodPressuresTable, JwBloodPressure>
    ),
    JwBloodPressure,
    PrefetchHooks Function()> {
  $$JwBloodPressuresTableTableManager(
      _$JWDatabase db, $JwBloodPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwBloodPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwBloodPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwBloodPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> systolic = const Value.absent(),
            Value<int> diastolic = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodPressuresCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            systolic: systolic,
            diastolic: diastolic,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int systolic,
            required int diastolic,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            systolic: systolic,
            diastolic: diastolic,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwBloodPressuresTable, JwBloodPressure>(table),
                    BaseReferences<_$JWDatabase, $JwBloodPressuresTable,
                        JwBloodPressure>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwBloodPressuresTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwBloodPressuresTable,
    JwBloodPressure,
    $$JwBloodPressuresTableFilterComposer,
    $$JwBloodPressuresTableOrderingComposer,
    $$JwBloodPressuresTableAnnotationComposer,
    $$JwBloodPressuresTableCreateCompanionBuilder,
    $$JwBloodPressuresTableUpdateCompanionBuilder,
    (
      JwBloodPressure,
      BaseReferences<_$JWDatabase, $JwBloodPressuresTable, JwBloodPressure>
    ),
    JwBloodPressure,
    PrefetchHooks Function()>;
typedef $$JwBloodOxygensTableCreateCompanionBuilder = JwBloodOxygensCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});
typedef $$JwBloodOxygensTableUpdateCompanionBuilder = JwBloodOxygensCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});

class $$JwBloodOxygensTableFilterComposer
    extends Composer<_$JWDatabase, $JwBloodOxygensTable> {
  $$JwBloodOxygensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get high => $composableBuilder(
      column: $table.high, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get low => $composableBuilder(
      column: $table.low, builder: (column) => ColumnFilters(column));
}

class $$JwBloodOxygensTableOrderingComposer
    extends Composer<_$JWDatabase, $JwBloodOxygensTable> {
  $$JwBloodOxygensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get high => $composableBuilder(
      column: $table.high, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get low => $composableBuilder(
      column: $table.low, builder: (column) => ColumnOrderings(column));
}

class $$JwBloodOxygensTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwBloodOxygensTable> {
  $$JwBloodOxygensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<int> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);
}

class $$JwBloodOxygensTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwBloodOxygensTable,
    JwBloodOxygen,
    $$JwBloodOxygensTableFilterComposer,
    $$JwBloodOxygensTableOrderingComposer,
    $$JwBloodOxygensTableAnnotationComposer,
    $$JwBloodOxygensTableCreateCompanionBuilder,
    $$JwBloodOxygensTableUpdateCompanionBuilder,
    (
      JwBloodOxygen,
      BaseReferences<_$JWDatabase, $JwBloodOxygensTable, JwBloodOxygen>
    ),
    JwBloodOxygen,
    PrefetchHooks Function()> {
  $$JwBloodOxygensTableTableManager(_$JWDatabase db, $JwBloodOxygensTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwBloodOxygensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwBloodOxygensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwBloodOxygensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int?> high = const Value.absent(),
            Value<int?> low = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodOxygensCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            high: high,
            low: low,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int value,
            Value<int?> high = const Value.absent(),
            Value<int?> low = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodOxygensCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            high: high,
            low: low,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwBloodOxygensTable, JwBloodOxygen>(table),
                    BaseReferences<_$JWDatabase, $JwBloodOxygensTable,
                        JwBloodOxygen>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwBloodOxygensTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwBloodOxygensTable,
    JwBloodOxygen,
    $$JwBloodOxygensTableFilterComposer,
    $$JwBloodOxygensTableOrderingComposer,
    $$JwBloodOxygensTableAnnotationComposer,
    $$JwBloodOxygensTableCreateCompanionBuilder,
    $$JwBloodOxygensTableUpdateCompanionBuilder,
    (
      JwBloodOxygen,
      BaseReferences<_$JWDatabase, $JwBloodOxygensTable, JwBloodOxygen>
    ),
    JwBloodOxygen,
    PrefetchHooks Function()>;
typedef $$JwHrvsTableCreateCompanionBuilder = JwHrvsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int sdnn,
  Value<int> rowid,
});
typedef $$JwHrvsTableUpdateCompanionBuilder = JwHrvsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> sdnn,
  Value<int> rowid,
});

class $$JwHrvsTableFilterComposer extends Composer<_$JWDatabase, $JwHrvsTable> {
  $$JwHrvsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sdnn => $composableBuilder(
      column: $table.sdnn, builder: (column) => ColumnFilters(column));
}

class $$JwHrvsTableOrderingComposer
    extends Composer<_$JWDatabase, $JwHrvsTable> {
  $$JwHrvsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sdnn => $composableBuilder(
      column: $table.sdnn, builder: (column) => ColumnOrderings(column));
}

class $$JwHrvsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwHrvsTable> {
  $$JwHrvsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get sdnn =>
      $composableBuilder(column: $table.sdnn, builder: (column) => column);
}

class $$JwHrvsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwHrvsTable,
    JwHrv,
    $$JwHrvsTableFilterComposer,
    $$JwHrvsTableOrderingComposer,
    $$JwHrvsTableAnnotationComposer,
    $$JwHrvsTableCreateCompanionBuilder,
    $$JwHrvsTableUpdateCompanionBuilder,
    (JwHrv, BaseReferences<_$JWDatabase, $JwHrvsTable, JwHrv>),
    JwHrv,
    PrefetchHooks Function()> {
  $$JwHrvsTableTableManager(_$JWDatabase db, $JwHrvsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwHrvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwHrvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwHrvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> sdnn = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwHrvsCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            sdnn: sdnn,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int sdnn,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwHrvsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            sdnn: sdnn,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwHrvsTable, JwHrv>(table),
                    BaseReferences<_$JWDatabase, $JwHrvsTable, JwHrv>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwHrvsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwHrvsTable,
    JwHrv,
    $$JwHrvsTableFilterComposer,
    $$JwHrvsTableOrderingComposer,
    $$JwHrvsTableAnnotationComposer,
    $$JwHrvsTableCreateCompanionBuilder,
    $$JwHrvsTableUpdateCompanionBuilder,
    (JwHrv, BaseReferences<_$JWDatabase, $JwHrvsTable, JwHrv>),
    JwHrv,
    PrefetchHooks Function()>;
typedef $$JwPressuresTableCreateCompanionBuilder = JwPressuresCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$JwPressuresTableUpdateCompanionBuilder = JwPressuresCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$JwPressuresTableFilterComposer
    extends Composer<_$JWDatabase, $JwPressuresTable> {
  $$JwPressuresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$JwPressuresTableOrderingComposer
    extends Composer<_$JWDatabase, $JwPressuresTable> {
  $$JwPressuresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$JwPressuresTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwPressuresTable> {
  $$JwPressuresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$JwPressuresTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwPressuresTable,
    JwPressure,
    $$JwPressuresTableFilterComposer,
    $$JwPressuresTableOrderingComposer,
    $$JwPressuresTableAnnotationComposer,
    $$JwPressuresTableCreateCompanionBuilder,
    $$JwPressuresTableUpdateCompanionBuilder,
    (JwPressure, BaseReferences<_$JWDatabase, $JwPressuresTable, JwPressure>),
    JwPressure,
    PrefetchHooks Function()> {
  $$JwPressuresTableTableManager(_$JWDatabase db, $JwPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwPressuresCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int value,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwPressuresTable, JwPressure>(table),
                    BaseReferences<_$JWDatabase, $JwPressuresTable, JwPressure>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwPressuresTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwPressuresTable,
    JwPressure,
    $$JwPressuresTableFilterComposer,
    $$JwPressuresTableOrderingComposer,
    $$JwPressuresTableAnnotationComposer,
    $$JwPressuresTableCreateCompanionBuilder,
    $$JwPressuresTableUpdateCompanionBuilder,
    (JwPressure, BaseReferences<_$JWDatabase, $JwPressuresTable, JwPressure>),
    JwPressure,
    PrefetchHooks Function()>;
typedef $$JwTemperaturesTableCreateCompanionBuilder = JwTemperaturesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required double skinTemperature,
  required int heatStress,
  required bool worn,
  required bool compensated,
  Value<int> rowid,
});
typedef $$JwTemperaturesTableUpdateCompanionBuilder = JwTemperaturesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<double> skinTemperature,
  Value<int> heatStress,
  Value<bool> worn,
  Value<bool> compensated,
  Value<int> rowid,
});

class $$JwTemperaturesTableFilterComposer
    extends Composer<_$JWDatabase, $JwTemperaturesTable> {
  $$JwTemperaturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get skinTemperature => $composableBuilder(
      column: $table.skinTemperature,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heatStress => $composableBuilder(
      column: $table.heatStress, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get worn => $composableBuilder(
      column: $table.worn, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get compensated => $composableBuilder(
      column: $table.compensated, builder: (column) => ColumnFilters(column));
}

class $$JwTemperaturesTableOrderingComposer
    extends Composer<_$JWDatabase, $JwTemperaturesTable> {
  $$JwTemperaturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get skinTemperature => $composableBuilder(
      column: $table.skinTemperature,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heatStress => $composableBuilder(
      column: $table.heatStress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get worn => $composableBuilder(
      column: $table.worn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get compensated => $composableBuilder(
      column: $table.compensated, builder: (column) => ColumnOrderings(column));
}

class $$JwTemperaturesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwTemperaturesTable> {
  $$JwTemperaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<double> get skinTemperature => $composableBuilder(
      column: $table.skinTemperature, builder: (column) => column);

  GeneratedColumn<int> get heatStress => $composableBuilder(
      column: $table.heatStress, builder: (column) => column);

  GeneratedColumn<bool> get worn =>
      $composableBuilder(column: $table.worn, builder: (column) => column);

  GeneratedColumn<bool> get compensated => $composableBuilder(
      column: $table.compensated, builder: (column) => column);
}

class $$JwTemperaturesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwTemperaturesTable,
    JwTemperature,
    $$JwTemperaturesTableFilterComposer,
    $$JwTemperaturesTableOrderingComposer,
    $$JwTemperaturesTableAnnotationComposer,
    $$JwTemperaturesTableCreateCompanionBuilder,
    $$JwTemperaturesTableUpdateCompanionBuilder,
    (
      JwTemperature,
      BaseReferences<_$JWDatabase, $JwTemperaturesTable, JwTemperature>
    ),
    JwTemperature,
    PrefetchHooks Function()> {
  $$JwTemperaturesTableTableManager(_$JWDatabase db, $JwTemperaturesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwTemperaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwTemperaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwTemperaturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<double> skinTemperature = const Value.absent(),
            Value<int> heatStress = const Value.absent(),
            Value<bool> worn = const Value.absent(),
            Value<bool> compensated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwTemperaturesCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            skinTemperature: skinTemperature,
            heatStress: heatStress,
            worn: worn,
            compensated: compensated,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required double skinTemperature,
            required int heatStress,
            required bool worn,
            required bool compensated,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwTemperaturesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            skinTemperature: skinTemperature,
            heatStress: heatStress,
            worn: worn,
            compensated: compensated,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwTemperaturesTable, JwTemperature>(table),
                    BaseReferences<_$JWDatabase, $JwTemperaturesTable,
                        JwTemperature>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwTemperaturesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwTemperaturesTable,
    JwTemperature,
    $$JwTemperaturesTableFilterComposer,
    $$JwTemperaturesTableOrderingComposer,
    $$JwTemperaturesTableAnnotationComposer,
    $$JwTemperaturesTableCreateCompanionBuilder,
    $$JwTemperaturesTableUpdateCompanionBuilder,
    (
      JwTemperature,
      BaseReferences<_$JWDatabase, $JwTemperaturesTable, JwTemperature>
    ),
    JwTemperature,
    PrefetchHooks Function()>;
typedef $$JwBloodGlucosesTableCreateCompanionBuilder = JwBloodGlucosesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$JwBloodGlucosesTableUpdateCompanionBuilder = JwBloodGlucosesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$JwBloodGlucosesTableFilterComposer
    extends Composer<_$JWDatabase, $JwBloodGlucosesTable> {
  $$JwBloodGlucosesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$JwBloodGlucosesTableOrderingComposer
    extends Composer<_$JWDatabase, $JwBloodGlucosesTable> {
  $$JwBloodGlucosesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$JwBloodGlucosesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwBloodGlucosesTable> {
  $$JwBloodGlucosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$JwBloodGlucosesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwBloodGlucosesTable,
    JwBloodGlucose,
    $$JwBloodGlucosesTableFilterComposer,
    $$JwBloodGlucosesTableOrderingComposer,
    $$JwBloodGlucosesTableAnnotationComposer,
    $$JwBloodGlucosesTableCreateCompanionBuilder,
    $$JwBloodGlucosesTableUpdateCompanionBuilder,
    (
      JwBloodGlucose,
      BaseReferences<_$JWDatabase, $JwBloodGlucosesTable, JwBloodGlucose>
    ),
    JwBloodGlucose,
    PrefetchHooks Function()> {
  $$JwBloodGlucosesTableTableManager(
      _$JWDatabase db, $JwBloodGlucosesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwBloodGlucosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwBloodGlucosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwBloodGlucosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodGlucosesCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int value,
            Value<int> rowid = const Value.absent(),
          }) =>
              JwBloodGlucosesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwBloodGlucosesTable, JwBloodGlucose>(table),
                    BaseReferences<_$JWDatabase, $JwBloodGlucosesTable,
                        JwBloodGlucose>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwBloodGlucosesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwBloodGlucosesTable,
    JwBloodGlucose,
    $$JwBloodGlucosesTableFilterComposer,
    $$JwBloodGlucosesTableOrderingComposer,
    $$JwBloodGlucosesTableAnnotationComposer,
    $$JwBloodGlucosesTableCreateCompanionBuilder,
    $$JwBloodGlucosesTableUpdateCompanionBuilder,
    (
      JwBloodGlucose,
      BaseReferences<_$JWDatabase, $JwBloodGlucosesTable, JwBloodGlucose>
    ),
    JwBloodGlucose,
    PrefetchHooks Function()>;
typedef $$JwSportsTableCreateCompanionBuilder = JwSportsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int mode,
  required int duration,
  required int pauseCount,
  required int pauseDuration,
  required int steps,
  required int distance,
  required int energy,
  Value<int?> heartRateMax,
  Value<int?> heartRateAverage,
  Value<int?> heartRateMin,
  Value<int> rowid,
});
typedef $$JwSportsTableUpdateCompanionBuilder = JwSportsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> mode,
  Value<int> duration,
  Value<int> pauseCount,
  Value<int> pauseDuration,
  Value<int> steps,
  Value<int> distance,
  Value<int> energy,
  Value<int?> heartRateMax,
  Value<int?> heartRateAverage,
  Value<int?> heartRateMin,
  Value<int> rowid,
});

class $$JwSportsTableFilterComposer
    extends Composer<_$JWDatabase, $JwSportsTable> {
  $$JwSportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pauseCount => $composableBuilder(
      column: $table.pauseCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pauseDuration => $composableBuilder(
      column: $table.pauseDuration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get energy => $composableBuilder(
      column: $table.energy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heartRateMax => $composableBuilder(
      column: $table.heartRateMax, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heartRateAverage => $composableBuilder(
      column: $table.heartRateAverage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heartRateMin => $composableBuilder(
      column: $table.heartRateMin, builder: (column) => ColumnFilters(column));
}

class $$JwSportsTableOrderingComposer
    extends Composer<_$JWDatabase, $JwSportsTable> {
  $$JwSportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceMac => $composableBuilder(
      column: $table.deviceMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pauseCount => $composableBuilder(
      column: $table.pauseCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pauseDuration => $composableBuilder(
      column: $table.pauseDuration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get energy => $composableBuilder(
      column: $table.energy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heartRateMax => $composableBuilder(
      column: $table.heartRateMax,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heartRateAverage => $composableBuilder(
      column: $table.heartRateAverage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heartRateMin => $composableBuilder(
      column: $table.heartRateMin,
      builder: (column) => ColumnOrderings(column));
}

class $$JwSportsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JwSportsTable> {
  $$JwSportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceMac =>
      $composableBuilder(column: $table.deviceMac, builder: (column) => column);

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get pauseCount => $composableBuilder(
      column: $table.pauseCount, builder: (column) => column);

  GeneratedColumn<int> get pauseDuration => $composableBuilder(
      column: $table.pauseDuration, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get heartRateMax => $composableBuilder(
      column: $table.heartRateMax, builder: (column) => column);

  GeneratedColumn<int> get heartRateAverage => $composableBuilder(
      column: $table.heartRateAverage, builder: (column) => column);

  GeneratedColumn<int> get heartRateMin => $composableBuilder(
      column: $table.heartRateMin, builder: (column) => column);
}

class $$JwSportsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JwSportsTable,
    JwSport,
    $$JwSportsTableFilterComposer,
    $$JwSportsTableOrderingComposer,
    $$JwSportsTableAnnotationComposer,
    $$JwSportsTableCreateCompanionBuilder,
    $$JwSportsTableUpdateCompanionBuilder,
    (JwSport, BaseReferences<_$JWDatabase, $JwSportsTable, JwSport>),
    JwSport,
    PrefetchHooks Function()> {
  $$JwSportsTableTableManager(_$JWDatabase db, $JwSportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JwSportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JwSportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JwSportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int> pauseCount = const Value.absent(),
            Value<int> pauseDuration = const Value.absent(),
            Value<int> steps = const Value.absent(),
            Value<int> distance = const Value.absent(),
            Value<int> energy = const Value.absent(),
            Value<int?> heartRateMax = const Value.absent(),
            Value<int?> heartRateAverage = const Value.absent(),
            Value<int?> heartRateMin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwSportsCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            duration: duration,
            pauseCount: pauseCount,
            pauseDuration: pauseDuration,
            steps: steps,
            distance: distance,
            energy: energy,
            heartRateMax: heartRateMax,
            heartRateAverage: heartRateAverage,
            heartRateMin: heartRateMin,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int mode,
            required int duration,
            required int pauseCount,
            required int pauseDuration,
            required int steps,
            required int distance,
            required int energy,
            Value<int?> heartRateMax = const Value.absent(),
            Value<int?> heartRateAverage = const Value.absent(),
            Value<int?> heartRateMin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JwSportsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            duration: duration,
            pauseCount: pauseCount,
            pauseDuration: pauseDuration,
            steps: steps,
            distance: distance,
            energy: energy,
            heartRateMax: heartRateMax,
            heartRateAverage: heartRateAverage,
            heartRateMin: heartRateMin,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JwSportsTable, JwSport>(table),
                    BaseReferences<_$JWDatabase, $JwSportsTable, JwSport>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JwSportsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JwSportsTable,
    JwSport,
    $$JwSportsTableFilterComposer,
    $$JwSportsTableOrderingComposer,
    $$JwSportsTableAnnotationComposer,
    $$JwSportsTableCreateCompanionBuilder,
    $$JwSportsTableUpdateCompanionBuilder,
    (JwSport, BaseReferences<_$JWDatabase, $JwSportsTable, JwSport>),
    JwSport,
    PrefetchHooks Function()>;

class $JWDatabaseManager {
  final _$JWDatabase _db;
  $JWDatabaseManager(this._db);
  $$JwActivitiesTableTableManager get jwActivities =>
      $$JwActivitiesTableTableManager(_db, _db.jwActivities);
  $$JwSleepsTableTableManager get jwSleeps =>
      $$JwSleepsTableTableManager(_db, _db.jwSleeps);
  $$JwHeartRatesTableTableManager get jwHeartRates =>
      $$JwHeartRatesTableTableManager(_db, _db.jwHeartRates);
  $$JwBloodPressuresTableTableManager get jwBloodPressures =>
      $$JwBloodPressuresTableTableManager(_db, _db.jwBloodPressures);
  $$JwBloodOxygensTableTableManager get jwBloodOxygens =>
      $$JwBloodOxygensTableTableManager(_db, _db.jwBloodOxygens);
  $$JwHrvsTableTableManager get jwHrvs =>
      $$JwHrvsTableTableManager(_db, _db.jwHrvs);
  $$JwPressuresTableTableManager get jwPressures =>
      $$JwPressuresTableTableManager(_db, _db.jwPressures);
  $$JwTemperaturesTableTableManager get jwTemperatures =>
      $$JwTemperaturesTableTableManager(_db, _db.jwTemperatures);
  $$JwBloodGlucosesTableTableManager get jwBloodGlucoses =>
      $$JwBloodGlucosesTableTableManager(_db, _db.jwBloodGlucoses);
  $$JwSportsTableTableManager get jwSports =>
      $$JwSportsTableTableManager(_db, _db.jwSports);
}
