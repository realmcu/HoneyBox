// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jw_database.dart';

// ignore_for_file: type=lint
class $JWActivitiesTable extends JWActivities
    with TableInfo<$JWActivitiesTable, JWActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWActivitiesTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWActivityRow> instance,
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
  JWActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWActivityRow(
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
  $JWActivitiesTable createAlias(String alias) {
    return $JWActivitiesTable(attachedDatabase, alias);
  }
}

class JWActivityRow extends DataClass implements Insertable<JWActivityRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int steps;
  final int distance;
  final int energy;
  final int activeTime;
  final int mode;
  const JWActivityRow(
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

  JWActivitiesCompanion toCompanion(bool nullToAbsent) {
    return JWActivitiesCompanion(
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

  factory JWActivityRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWActivityRow(
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

  JWActivityRow copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? steps,
          int? distance,
          int? energy,
          int? activeTime,
          int? mode}) =>
      JWActivityRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        steps: steps ?? this.steps,
        distance: distance ?? this.distance,
        energy: energy ?? this.energy,
        activeTime: activeTime ?? this.activeTime,
        mode: mode ?? this.mode,
      );
  JWActivityRow copyWithCompanion(JWActivitiesCompanion data) {
    return JWActivityRow(
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
    return (StringBuffer('JWActivityRow(')
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
      (other is JWActivityRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.steps == this.steps &&
          other.distance == this.distance &&
          other.energy == this.energy &&
          other.activeTime == this.activeTime &&
          other.mode == this.mode);
}

class JWActivitiesCompanion extends UpdateCompanion<JWActivityRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> steps;
  final Value<int> distance;
  final Value<int> energy;
  final Value<int> activeTime;
  final Value<int> mode;
  final Value<int> rowid;
  const JWActivitiesCompanion({
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
  JWActivitiesCompanion.insert({
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
  static Insertable<JWActivityRow> custom({
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

  JWActivitiesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? steps,
      Value<int>? distance,
      Value<int>? energy,
      Value<int>? activeTime,
      Value<int>? mode,
      Value<int>? rowid}) {
    return JWActivitiesCompanion(
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
    return (StringBuffer('JWActivitiesCompanion(')
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

class $JWSleepsTable extends JWSleeps
    with TableInfo<$JWSleepsTable, JWSleepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWSleepsTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWSleepRow> instance,
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
  JWSleepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWSleepRow(
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
  $JWSleepsTable createAlias(String alias) {
    return $JWSleepsTable(attachedDatabase, alias);
  }
}

class JWSleepRow extends DataClass implements Insertable<JWSleepRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int mode;
  const JWSleepRow(
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

  JWSleepsCompanion toCompanion(bool nullToAbsent) {
    return JWSleepsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      mode: Value(mode),
    );
  }

  factory JWSleepRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWSleepRow(
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

  JWSleepRow copyWith(
          {String? userId, String? deviceMac, int? time, int? mode}) =>
      JWSleepRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        mode: mode ?? this.mode,
      );
  JWSleepRow copyWithCompanion(JWSleepsCompanion data) {
    return JWSleepRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWSleepRow(')
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
      (other is JWSleepRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.mode == this.mode);
}

class JWSleepsCompanion extends UpdateCompanion<JWSleepRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> mode;
  final Value<int> rowid;
  const JWSleepsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.mode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWSleepsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int mode,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        mode = Value(mode);
  static Insertable<JWSleepRow> custom({
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

  JWSleepsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? mode,
      Value<int>? rowid}) {
    return JWSleepsCompanion(
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
    return (StringBuffer('JWSleepsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JWHeartRatesTable extends JWHeartRates
    with TableInfo<$JWHeartRatesTable, JWHeartRateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWHeartRatesTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWHeartRateRow> instance,
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
  JWHeartRateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWHeartRateRow(
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
  $JWHeartRatesTable createAlias(String alias) {
    return $JWHeartRatesTable(attachedDatabase, alias);
  }
}

class JWHeartRateRow extends DataClass implements Insertable<JWHeartRateRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int heartRate;
  const JWHeartRateRow(
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

  JWHeartRatesCompanion toCompanion(bool nullToAbsent) {
    return JWHeartRatesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      heartRate: Value(heartRate),
    );
  }

  factory JWHeartRateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWHeartRateRow(
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

  JWHeartRateRow copyWith(
          {String? userId, String? deviceMac, int? time, int? heartRate}) =>
      JWHeartRateRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        heartRate: heartRate ?? this.heartRate,
      );
  JWHeartRateRow copyWithCompanion(JWHeartRatesCompanion data) {
    return JWHeartRateRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      heartRate: data.heartRate.present ? data.heartRate.value : this.heartRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWHeartRateRow(')
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
      (other is JWHeartRateRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.heartRate == this.heartRate);
}

class JWHeartRatesCompanion extends UpdateCompanion<JWHeartRateRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> heartRate;
  final Value<int> rowid;
  const JWHeartRatesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWHeartRatesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int heartRate,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        heartRate = Value(heartRate);
  static Insertable<JWHeartRateRow> custom({
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

  JWHeartRatesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? heartRate,
      Value<int>? rowid}) {
    return JWHeartRatesCompanion(
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
    return (StringBuffer('JWHeartRatesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('heartRate: $heartRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JWBloodPressuresTable extends JWBloodPressures
    with TableInfo<$JWBloodPressuresTable, JWBloodPressureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWBloodPressuresTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWBloodPressureRow> instance,
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
  JWBloodPressureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWBloodPressureRow(
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
  $JWBloodPressuresTable createAlias(String alias) {
    return $JWBloodPressuresTable(attachedDatabase, alias);
  }
}

class JWBloodPressureRow extends DataClass
    implements Insertable<JWBloodPressureRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int systolic;
  final int diastolic;
  const JWBloodPressureRow(
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

  JWBloodPressuresCompanion toCompanion(bool nullToAbsent) {
    return JWBloodPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      systolic: Value(systolic),
      diastolic: Value(diastolic),
    );
  }

  factory JWBloodPressureRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWBloodPressureRow(
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

  JWBloodPressureRow copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? systolic,
          int? diastolic}) =>
      JWBloodPressureRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        systolic: systolic ?? this.systolic,
        diastolic: diastolic ?? this.diastolic,
      );
  JWBloodPressureRow copyWithCompanion(JWBloodPressuresCompanion data) {
    return JWBloodPressureRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      systolic: data.systolic.present ? data.systolic.value : this.systolic,
      diastolic: data.diastolic.present ? data.diastolic.value : this.diastolic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWBloodPressureRow(')
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
      (other is JWBloodPressureRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.systolic == this.systolic &&
          other.diastolic == this.diastolic);
}

class JWBloodPressuresCompanion extends UpdateCompanion<JWBloodPressureRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> systolic;
  final Value<int> diastolic;
  final Value<int> rowid;
  const JWBloodPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.systolic = const Value.absent(),
    this.diastolic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWBloodPressuresCompanion.insert({
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
  static Insertable<JWBloodPressureRow> custom({
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

  JWBloodPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? systolic,
      Value<int>? diastolic,
      Value<int>? rowid}) {
    return JWBloodPressuresCompanion(
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
    return (StringBuffer('JWBloodPressuresCompanion(')
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

class $JWBloodOxygensTable extends JWBloodOxygens
    with TableInfo<$JWBloodOxygensTable, JWBloodOxygenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWBloodOxygensTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWBloodOxygenRow> instance,
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
  JWBloodOxygenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWBloodOxygenRow(
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
  $JWBloodOxygensTable createAlias(String alias) {
    return $JWBloodOxygensTable(attachedDatabase, alias);
  }
}

class JWBloodOxygenRow extends DataClass
    implements Insertable<JWBloodOxygenRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  final int? high;
  final int? low;
  const JWBloodOxygenRow(
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

  JWBloodOxygensCompanion toCompanion(bool nullToAbsent) {
    return JWBloodOxygensCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
    );
  }

  factory JWBloodOxygenRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWBloodOxygenRow(
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

  JWBloodOxygenRow copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? value,
          Value<int?> high = const Value.absent(),
          Value<int?> low = const Value.absent()}) =>
      JWBloodOxygenRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
        high: high.present ? high.value : this.high,
        low: low.present ? low.value : this.low,
      );
  JWBloodOxygenRow copyWithCompanion(JWBloodOxygensCompanion data) {
    return JWBloodOxygenRow(
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
    return (StringBuffer('JWBloodOxygenRow(')
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
      (other is JWBloodOxygenRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value &&
          other.high == this.high &&
          other.low == this.low);
}

class JWBloodOxygensCompanion extends UpdateCompanion<JWBloodOxygenRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int?> high;
  final Value<int?> low;
  final Value<int> rowid;
  const JWBloodOxygensCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWBloodOxygensCompanion.insert({
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
  static Insertable<JWBloodOxygenRow> custom({
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

  JWBloodOxygensCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int?>? high,
      Value<int?>? low,
      Value<int>? rowid}) {
    return JWBloodOxygensCompanion(
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
    return (StringBuffer('JWBloodOxygensCompanion(')
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

class $JWHrvsTable extends JWHrvs with TableInfo<$JWHrvsTable, JWHrvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWHrvsTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWHrvRow> instance,
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
  JWHrvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWHrvRow(
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
  $JWHrvsTable createAlias(String alias) {
    return $JWHrvsTable(attachedDatabase, alias);
  }
}

class JWHrvRow extends DataClass implements Insertable<JWHrvRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int sdnn;
  const JWHrvRow(
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

  JWHrvsCompanion toCompanion(bool nullToAbsent) {
    return JWHrvsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      sdnn: Value(sdnn),
    );
  }

  factory JWHrvRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWHrvRow(
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

  JWHrvRow copyWith(
          {String? userId, String? deviceMac, int? time, int? sdnn}) =>
      JWHrvRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        sdnn: sdnn ?? this.sdnn,
      );
  JWHrvRow copyWithCompanion(JWHrvsCompanion data) {
    return JWHrvRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      sdnn: data.sdnn.present ? data.sdnn.value : this.sdnn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWHrvRow(')
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
      (other is JWHrvRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.sdnn == this.sdnn);
}

class JWHrvsCompanion extends UpdateCompanion<JWHrvRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> sdnn;
  final Value<int> rowid;
  const JWHrvsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.sdnn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWHrvsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int sdnn,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        sdnn = Value(sdnn);
  static Insertable<JWHrvRow> custom({
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

  JWHrvsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? sdnn,
      Value<int>? rowid}) {
    return JWHrvsCompanion(
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
    return (StringBuffer('JWHrvsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('sdnn: $sdnn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JWPressuresTable extends JWPressures
    with TableInfo<$JWPressuresTable, JWPressureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWPressuresTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWPressureRow> instance,
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
  JWPressureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWPressureRow(
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
  $JWPressuresTable createAlias(String alias) {
    return $JWPressuresTable(attachedDatabase, alias);
  }
}

class JWPressureRow extends DataClass implements Insertable<JWPressureRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const JWPressureRow(
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

  JWPressuresCompanion toCompanion(bool nullToAbsent) {
    return JWPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory JWPressureRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWPressureRow(
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

  JWPressureRow copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      JWPressureRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  JWPressureRow copyWithCompanion(JWPressuresCompanion data) {
    return JWPressureRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWPressureRow(')
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
      (other is JWPressureRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class JWPressuresCompanion extends UpdateCompanion<JWPressureRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const JWPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWPressuresCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<JWPressureRow> custom({
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

  JWPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return JWPressuresCompanion(
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
    return (StringBuffer('JWPressuresCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JWTemperaturesTable extends JWTemperatures
    with TableInfo<$JWTemperaturesTable, JWTemperatureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWTemperaturesTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWTemperatureRow> instance,
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
  JWTemperatureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWTemperatureRow(
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
  $JWTemperaturesTable createAlias(String alias) {
    return $JWTemperaturesTable(attachedDatabase, alias);
  }
}

class JWTemperatureRow extends DataClass
    implements Insertable<JWTemperatureRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final double skinTemperature;
  final int heatStress;
  final bool worn;
  final bool compensated;
  const JWTemperatureRow(
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

  JWTemperaturesCompanion toCompanion(bool nullToAbsent) {
    return JWTemperaturesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      skinTemperature: Value(skinTemperature),
      heatStress: Value(heatStress),
      worn: Value(worn),
      compensated: Value(compensated),
    );
  }

  factory JWTemperatureRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWTemperatureRow(
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

  JWTemperatureRow copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          double? skinTemperature,
          int? heatStress,
          bool? worn,
          bool? compensated}) =>
      JWTemperatureRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        skinTemperature: skinTemperature ?? this.skinTemperature,
        heatStress: heatStress ?? this.heatStress,
        worn: worn ?? this.worn,
        compensated: compensated ?? this.compensated,
      );
  JWTemperatureRow copyWithCompanion(JWTemperaturesCompanion data) {
    return JWTemperatureRow(
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
    return (StringBuffer('JWTemperatureRow(')
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
      (other is JWTemperatureRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.skinTemperature == this.skinTemperature &&
          other.heatStress == this.heatStress &&
          other.worn == this.worn &&
          other.compensated == this.compensated);
}

class JWTemperaturesCompanion extends UpdateCompanion<JWTemperatureRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<double> skinTemperature;
  final Value<int> heatStress;
  final Value<bool> worn;
  final Value<bool> compensated;
  final Value<int> rowid;
  const JWTemperaturesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.skinTemperature = const Value.absent(),
    this.heatStress = const Value.absent(),
    this.worn = const Value.absent(),
    this.compensated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWTemperaturesCompanion.insert({
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
  static Insertable<JWTemperatureRow> custom({
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

  JWTemperaturesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<double>? skinTemperature,
      Value<int>? heatStress,
      Value<bool>? worn,
      Value<bool>? compensated,
      Value<int>? rowid}) {
    return JWTemperaturesCompanion(
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
    return (StringBuffer('JWTemperaturesCompanion(')
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

class $JWBloodGlucosesTable extends JWBloodGlucoses
    with TableInfo<$JWBloodGlucosesTable, JWBloodGlucoseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWBloodGlucosesTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWBloodGlucoseRow> instance,
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
  JWBloodGlucoseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWBloodGlucoseRow(
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
  $JWBloodGlucosesTable createAlias(String alias) {
    return $JWBloodGlucosesTable(attachedDatabase, alias);
  }
}

class JWBloodGlucoseRow extends DataClass
    implements Insertable<JWBloodGlucoseRow> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const JWBloodGlucoseRow(
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

  JWBloodGlucosesCompanion toCompanion(bool nullToAbsent) {
    return JWBloodGlucosesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory JWBloodGlucoseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWBloodGlucoseRow(
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

  JWBloodGlucoseRow copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      JWBloodGlucoseRow(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  JWBloodGlucoseRow copyWithCompanion(JWBloodGlucosesCompanion data) {
    return JWBloodGlucoseRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JWBloodGlucoseRow(')
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
      (other is JWBloodGlucoseRow &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class JWBloodGlucosesCompanion extends UpdateCompanion<JWBloodGlucoseRow> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const JWBloodGlucosesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JWBloodGlucosesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<JWBloodGlucoseRow> custom({
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

  JWBloodGlucosesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return JWBloodGlucosesCompanion(
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
    return (StringBuffer('JWBloodGlucosesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JWSportsTable extends JWSports
    with TableInfo<$JWSportsTable, JWSportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JWSportsTable(this.attachedDatabase, [this._alias]);
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
  VerificationContext validateIntegrity(Insertable<JWSportRow> instance,
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
  JWSportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JWSportRow(
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
  $JWSportsTable createAlias(String alias) {
    return $JWSportsTable(attachedDatabase, alias);
  }
}

class JWSportRow extends DataClass implements Insertable<JWSportRow> {
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
  const JWSportRow(
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

  JWSportsCompanion toCompanion(bool nullToAbsent) {
    return JWSportsCompanion(
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

  factory JWSportRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JWSportRow(
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

  JWSportRow copyWith(
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
      JWSportRow(
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
  JWSportRow copyWithCompanion(JWSportsCompanion data) {
    return JWSportRow(
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
    return (StringBuffer('JWSportRow(')
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
      (other is JWSportRow &&
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

class JWSportsCompanion extends UpdateCompanion<JWSportRow> {
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
  const JWSportsCompanion({
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
  JWSportsCompanion.insert({
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
  static Insertable<JWSportRow> custom({
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

  JWSportsCompanion copyWith(
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
    return JWSportsCompanion(
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
    return (StringBuffer('JWSportsCompanion(')
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
  late final $JWActivitiesTable jWActivities = $JWActivitiesTable(this);
  late final $JWSleepsTable jWSleeps = $JWSleepsTable(this);
  late final $JWHeartRatesTable jWHeartRates = $JWHeartRatesTable(this);
  late final $JWBloodPressuresTable jWBloodPressures =
      $JWBloodPressuresTable(this);
  late final $JWBloodOxygensTable jWBloodOxygens = $JWBloodOxygensTable(this);
  late final $JWHrvsTable jWHrvs = $JWHrvsTable(this);
  late final $JWPressuresTable jWPressures = $JWPressuresTable(this);
  late final $JWTemperaturesTable jWTemperatures = $JWTemperaturesTable(this);
  late final $JWBloodGlucosesTable jWBloodGlucoses =
      $JWBloodGlucosesTable(this);
  late final $JWSportsTable jWSports = $JWSportsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        jWActivities,
        jWSleeps,
        jWHeartRates,
        jWBloodPressures,
        jWBloodOxygens,
        jWHrvs,
        jWPressures,
        jWTemperatures,
        jWBloodGlucoses,
        jWSports
      ];
}

typedef $$JWActivitiesTableCreateCompanionBuilder = JWActivitiesCompanion
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
typedef $$JWActivitiesTableUpdateCompanionBuilder = JWActivitiesCompanion
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

class $$JWActivitiesTableFilterComposer
    extends Composer<_$JWDatabase, $JWActivitiesTable> {
  $$JWActivitiesTableFilterComposer({
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

class $$JWActivitiesTableOrderingComposer
    extends Composer<_$JWDatabase, $JWActivitiesTable> {
  $$JWActivitiesTableOrderingComposer({
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

class $$JWActivitiesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWActivitiesTable> {
  $$JWActivitiesTableAnnotationComposer({
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

class $$JWActivitiesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWActivitiesTable,
    JWActivityRow,
    $$JWActivitiesTableFilterComposer,
    $$JWActivitiesTableOrderingComposer,
    $$JWActivitiesTableAnnotationComposer,
    $$JWActivitiesTableCreateCompanionBuilder,
    $$JWActivitiesTableUpdateCompanionBuilder,
    (
      JWActivityRow,
      BaseReferences<_$JWDatabase, $JWActivitiesTable, JWActivityRow>
    ),
    JWActivityRow,
    PrefetchHooks Function()> {
  $$JWActivitiesTableTableManager(_$JWDatabase db, $JWActivitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWActivitiesTableAnnotationComposer($db: db, $table: table),
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
              JWActivitiesCompanion(
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
              JWActivitiesCompanion.insert(
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
                    e.readTable<$JWActivitiesTable, JWActivityRow>(table),
                    BaseReferences<_$JWDatabase, $JWActivitiesTable,
                        JWActivityRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWActivitiesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWActivitiesTable,
    JWActivityRow,
    $$JWActivitiesTableFilterComposer,
    $$JWActivitiesTableOrderingComposer,
    $$JWActivitiesTableAnnotationComposer,
    $$JWActivitiesTableCreateCompanionBuilder,
    $$JWActivitiesTableUpdateCompanionBuilder,
    (
      JWActivityRow,
      BaseReferences<_$JWDatabase, $JWActivitiesTable, JWActivityRow>
    ),
    JWActivityRow,
    PrefetchHooks Function()>;
typedef $$JWSleepsTableCreateCompanionBuilder = JWSleepsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int mode,
  Value<int> rowid,
});
typedef $$JWSleepsTableUpdateCompanionBuilder = JWSleepsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> mode,
  Value<int> rowid,
});

class $$JWSleepsTableFilterComposer
    extends Composer<_$JWDatabase, $JWSleepsTable> {
  $$JWSleepsTableFilterComposer({
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

class $$JWSleepsTableOrderingComposer
    extends Composer<_$JWDatabase, $JWSleepsTable> {
  $$JWSleepsTableOrderingComposer({
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

class $$JWSleepsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWSleepsTable> {
  $$JWSleepsTableAnnotationComposer({
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

class $$JWSleepsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWSleepsTable,
    JWSleepRow,
    $$JWSleepsTableFilterComposer,
    $$JWSleepsTableOrderingComposer,
    $$JWSleepsTableAnnotationComposer,
    $$JWSleepsTableCreateCompanionBuilder,
    $$JWSleepsTableUpdateCompanionBuilder,
    (JWSleepRow, BaseReferences<_$JWDatabase, $JWSleepsTable, JWSleepRow>),
    JWSleepRow,
    PrefetchHooks Function()> {
  $$JWSleepsTableTableManager(_$JWDatabase db, $JWSleepsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWSleepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWSleepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWSleepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWSleepsCompanion(
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
              JWSleepsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWSleepsTable, JWSleepRow>(table),
                    BaseReferences<_$JWDatabase, $JWSleepsTable, JWSleepRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWSleepsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWSleepsTable,
    JWSleepRow,
    $$JWSleepsTableFilterComposer,
    $$JWSleepsTableOrderingComposer,
    $$JWSleepsTableAnnotationComposer,
    $$JWSleepsTableCreateCompanionBuilder,
    $$JWSleepsTableUpdateCompanionBuilder,
    (JWSleepRow, BaseReferences<_$JWDatabase, $JWSleepsTable, JWSleepRow>),
    JWSleepRow,
    PrefetchHooks Function()>;
typedef $$JWHeartRatesTableCreateCompanionBuilder = JWHeartRatesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int heartRate,
  Value<int> rowid,
});
typedef $$JWHeartRatesTableUpdateCompanionBuilder = JWHeartRatesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> heartRate,
  Value<int> rowid,
});

class $$JWHeartRatesTableFilterComposer
    extends Composer<_$JWDatabase, $JWHeartRatesTable> {
  $$JWHeartRatesTableFilterComposer({
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

class $$JWHeartRatesTableOrderingComposer
    extends Composer<_$JWDatabase, $JWHeartRatesTable> {
  $$JWHeartRatesTableOrderingComposer({
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

class $$JWHeartRatesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWHeartRatesTable> {
  $$JWHeartRatesTableAnnotationComposer({
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

class $$JWHeartRatesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWHeartRatesTable,
    JWHeartRateRow,
    $$JWHeartRatesTableFilterComposer,
    $$JWHeartRatesTableOrderingComposer,
    $$JWHeartRatesTableAnnotationComposer,
    $$JWHeartRatesTableCreateCompanionBuilder,
    $$JWHeartRatesTableUpdateCompanionBuilder,
    (
      JWHeartRateRow,
      BaseReferences<_$JWDatabase, $JWHeartRatesTable, JWHeartRateRow>
    ),
    JWHeartRateRow,
    PrefetchHooks Function()> {
  $$JWHeartRatesTableTableManager(_$JWDatabase db, $JWHeartRatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWHeartRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWHeartRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWHeartRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> heartRate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWHeartRatesCompanion(
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
              JWHeartRatesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            heartRate: heartRate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWHeartRatesTable, JWHeartRateRow>(table),
                    BaseReferences<_$JWDatabase, $JWHeartRatesTable,
                        JWHeartRateRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWHeartRatesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWHeartRatesTable,
    JWHeartRateRow,
    $$JWHeartRatesTableFilterComposer,
    $$JWHeartRatesTableOrderingComposer,
    $$JWHeartRatesTableAnnotationComposer,
    $$JWHeartRatesTableCreateCompanionBuilder,
    $$JWHeartRatesTableUpdateCompanionBuilder,
    (
      JWHeartRateRow,
      BaseReferences<_$JWDatabase, $JWHeartRatesTable, JWHeartRateRow>
    ),
    JWHeartRateRow,
    PrefetchHooks Function()>;
typedef $$JWBloodPressuresTableCreateCompanionBuilder
    = JWBloodPressuresCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int systolic,
  required int diastolic,
  Value<int> rowid,
});
typedef $$JWBloodPressuresTableUpdateCompanionBuilder
    = JWBloodPressuresCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> systolic,
  Value<int> diastolic,
  Value<int> rowid,
});

class $$JWBloodPressuresTableFilterComposer
    extends Composer<_$JWDatabase, $JWBloodPressuresTable> {
  $$JWBloodPressuresTableFilterComposer({
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

class $$JWBloodPressuresTableOrderingComposer
    extends Composer<_$JWDatabase, $JWBloodPressuresTable> {
  $$JWBloodPressuresTableOrderingComposer({
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

class $$JWBloodPressuresTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWBloodPressuresTable> {
  $$JWBloodPressuresTableAnnotationComposer({
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

class $$JWBloodPressuresTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWBloodPressuresTable,
    JWBloodPressureRow,
    $$JWBloodPressuresTableFilterComposer,
    $$JWBloodPressuresTableOrderingComposer,
    $$JWBloodPressuresTableAnnotationComposer,
    $$JWBloodPressuresTableCreateCompanionBuilder,
    $$JWBloodPressuresTableUpdateCompanionBuilder,
    (
      JWBloodPressureRow,
      BaseReferences<_$JWDatabase, $JWBloodPressuresTable, JWBloodPressureRow>
    ),
    JWBloodPressureRow,
    PrefetchHooks Function()> {
  $$JWBloodPressuresTableTableManager(
      _$JWDatabase db, $JWBloodPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWBloodPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWBloodPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWBloodPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> systolic = const Value.absent(),
            Value<int> diastolic = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWBloodPressuresCompanion(
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
              JWBloodPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            systolic: systolic,
            diastolic: diastolic,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWBloodPressuresTable, JWBloodPressureRow>(
                        table),
                    BaseReferences<_$JWDatabase, $JWBloodPressuresTable,
                        JWBloodPressureRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWBloodPressuresTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWBloodPressuresTable,
    JWBloodPressureRow,
    $$JWBloodPressuresTableFilterComposer,
    $$JWBloodPressuresTableOrderingComposer,
    $$JWBloodPressuresTableAnnotationComposer,
    $$JWBloodPressuresTableCreateCompanionBuilder,
    $$JWBloodPressuresTableUpdateCompanionBuilder,
    (
      JWBloodPressureRow,
      BaseReferences<_$JWDatabase, $JWBloodPressuresTable, JWBloodPressureRow>
    ),
    JWBloodPressureRow,
    PrefetchHooks Function()>;
typedef $$JWBloodOxygensTableCreateCompanionBuilder = JWBloodOxygensCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});
typedef $$JWBloodOxygensTableUpdateCompanionBuilder = JWBloodOxygensCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});

class $$JWBloodOxygensTableFilterComposer
    extends Composer<_$JWDatabase, $JWBloodOxygensTable> {
  $$JWBloodOxygensTableFilterComposer({
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

class $$JWBloodOxygensTableOrderingComposer
    extends Composer<_$JWDatabase, $JWBloodOxygensTable> {
  $$JWBloodOxygensTableOrderingComposer({
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

class $$JWBloodOxygensTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWBloodOxygensTable> {
  $$JWBloodOxygensTableAnnotationComposer({
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

class $$JWBloodOxygensTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWBloodOxygensTable,
    JWBloodOxygenRow,
    $$JWBloodOxygensTableFilterComposer,
    $$JWBloodOxygensTableOrderingComposer,
    $$JWBloodOxygensTableAnnotationComposer,
    $$JWBloodOxygensTableCreateCompanionBuilder,
    $$JWBloodOxygensTableUpdateCompanionBuilder,
    (
      JWBloodOxygenRow,
      BaseReferences<_$JWDatabase, $JWBloodOxygensTable, JWBloodOxygenRow>
    ),
    JWBloodOxygenRow,
    PrefetchHooks Function()> {
  $$JWBloodOxygensTableTableManager(_$JWDatabase db, $JWBloodOxygensTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWBloodOxygensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWBloodOxygensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWBloodOxygensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int?> high = const Value.absent(),
            Value<int?> low = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWBloodOxygensCompanion(
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
              JWBloodOxygensCompanion.insert(
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
                    e.readTable<$JWBloodOxygensTable, JWBloodOxygenRow>(table),
                    BaseReferences<_$JWDatabase, $JWBloodOxygensTable,
                        JWBloodOxygenRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWBloodOxygensTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWBloodOxygensTable,
    JWBloodOxygenRow,
    $$JWBloodOxygensTableFilterComposer,
    $$JWBloodOxygensTableOrderingComposer,
    $$JWBloodOxygensTableAnnotationComposer,
    $$JWBloodOxygensTableCreateCompanionBuilder,
    $$JWBloodOxygensTableUpdateCompanionBuilder,
    (
      JWBloodOxygenRow,
      BaseReferences<_$JWDatabase, $JWBloodOxygensTable, JWBloodOxygenRow>
    ),
    JWBloodOxygenRow,
    PrefetchHooks Function()>;
typedef $$JWHrvsTableCreateCompanionBuilder = JWHrvsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int sdnn,
  Value<int> rowid,
});
typedef $$JWHrvsTableUpdateCompanionBuilder = JWHrvsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> sdnn,
  Value<int> rowid,
});

class $$JWHrvsTableFilterComposer extends Composer<_$JWDatabase, $JWHrvsTable> {
  $$JWHrvsTableFilterComposer({
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

class $$JWHrvsTableOrderingComposer
    extends Composer<_$JWDatabase, $JWHrvsTable> {
  $$JWHrvsTableOrderingComposer({
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

class $$JWHrvsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWHrvsTable> {
  $$JWHrvsTableAnnotationComposer({
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

class $$JWHrvsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWHrvsTable,
    JWHrvRow,
    $$JWHrvsTableFilterComposer,
    $$JWHrvsTableOrderingComposer,
    $$JWHrvsTableAnnotationComposer,
    $$JWHrvsTableCreateCompanionBuilder,
    $$JWHrvsTableUpdateCompanionBuilder,
    (JWHrvRow, BaseReferences<_$JWDatabase, $JWHrvsTable, JWHrvRow>),
    JWHrvRow,
    PrefetchHooks Function()> {
  $$JWHrvsTableTableManager(_$JWDatabase db, $JWHrvsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWHrvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWHrvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWHrvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> sdnn = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWHrvsCompanion(
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
              JWHrvsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            sdnn: sdnn,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWHrvsTable, JWHrvRow>(table),
                    BaseReferences<_$JWDatabase, $JWHrvsTable, JWHrvRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWHrvsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWHrvsTable,
    JWHrvRow,
    $$JWHrvsTableFilterComposer,
    $$JWHrvsTableOrderingComposer,
    $$JWHrvsTableAnnotationComposer,
    $$JWHrvsTableCreateCompanionBuilder,
    $$JWHrvsTableUpdateCompanionBuilder,
    (JWHrvRow, BaseReferences<_$JWDatabase, $JWHrvsTable, JWHrvRow>),
    JWHrvRow,
    PrefetchHooks Function()>;
typedef $$JWPressuresTableCreateCompanionBuilder = JWPressuresCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$JWPressuresTableUpdateCompanionBuilder = JWPressuresCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$JWPressuresTableFilterComposer
    extends Composer<_$JWDatabase, $JWPressuresTable> {
  $$JWPressuresTableFilterComposer({
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

class $$JWPressuresTableOrderingComposer
    extends Composer<_$JWDatabase, $JWPressuresTable> {
  $$JWPressuresTableOrderingComposer({
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

class $$JWPressuresTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWPressuresTable> {
  $$JWPressuresTableAnnotationComposer({
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

class $$JWPressuresTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWPressuresTable,
    JWPressureRow,
    $$JWPressuresTableFilterComposer,
    $$JWPressuresTableOrderingComposer,
    $$JWPressuresTableAnnotationComposer,
    $$JWPressuresTableCreateCompanionBuilder,
    $$JWPressuresTableUpdateCompanionBuilder,
    (
      JWPressureRow,
      BaseReferences<_$JWDatabase, $JWPressuresTable, JWPressureRow>
    ),
    JWPressureRow,
    PrefetchHooks Function()> {
  $$JWPressuresTableTableManager(_$JWDatabase db, $JWPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWPressuresCompanion(
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
              JWPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWPressuresTable, JWPressureRow>(table),
                    BaseReferences<_$JWDatabase, $JWPressuresTable,
                        JWPressureRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWPressuresTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWPressuresTable,
    JWPressureRow,
    $$JWPressuresTableFilterComposer,
    $$JWPressuresTableOrderingComposer,
    $$JWPressuresTableAnnotationComposer,
    $$JWPressuresTableCreateCompanionBuilder,
    $$JWPressuresTableUpdateCompanionBuilder,
    (
      JWPressureRow,
      BaseReferences<_$JWDatabase, $JWPressuresTable, JWPressureRow>
    ),
    JWPressureRow,
    PrefetchHooks Function()>;
typedef $$JWTemperaturesTableCreateCompanionBuilder = JWTemperaturesCompanion
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
typedef $$JWTemperaturesTableUpdateCompanionBuilder = JWTemperaturesCompanion
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

class $$JWTemperaturesTableFilterComposer
    extends Composer<_$JWDatabase, $JWTemperaturesTable> {
  $$JWTemperaturesTableFilterComposer({
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

class $$JWTemperaturesTableOrderingComposer
    extends Composer<_$JWDatabase, $JWTemperaturesTable> {
  $$JWTemperaturesTableOrderingComposer({
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

class $$JWTemperaturesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWTemperaturesTable> {
  $$JWTemperaturesTableAnnotationComposer({
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

class $$JWTemperaturesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWTemperaturesTable,
    JWTemperatureRow,
    $$JWTemperaturesTableFilterComposer,
    $$JWTemperaturesTableOrderingComposer,
    $$JWTemperaturesTableAnnotationComposer,
    $$JWTemperaturesTableCreateCompanionBuilder,
    $$JWTemperaturesTableUpdateCompanionBuilder,
    (
      JWTemperatureRow,
      BaseReferences<_$JWDatabase, $JWTemperaturesTable, JWTemperatureRow>
    ),
    JWTemperatureRow,
    PrefetchHooks Function()> {
  $$JWTemperaturesTableTableManager(_$JWDatabase db, $JWTemperaturesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWTemperaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWTemperaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWTemperaturesTableAnnotationComposer($db: db, $table: table),
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
              JWTemperaturesCompanion(
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
              JWTemperaturesCompanion.insert(
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
                    e.readTable<$JWTemperaturesTable, JWTemperatureRow>(table),
                    BaseReferences<_$JWDatabase, $JWTemperaturesTable,
                        JWTemperatureRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWTemperaturesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWTemperaturesTable,
    JWTemperatureRow,
    $$JWTemperaturesTableFilterComposer,
    $$JWTemperaturesTableOrderingComposer,
    $$JWTemperaturesTableAnnotationComposer,
    $$JWTemperaturesTableCreateCompanionBuilder,
    $$JWTemperaturesTableUpdateCompanionBuilder,
    (
      JWTemperatureRow,
      BaseReferences<_$JWDatabase, $JWTemperaturesTable, JWTemperatureRow>
    ),
    JWTemperatureRow,
    PrefetchHooks Function()>;
typedef $$JWBloodGlucosesTableCreateCompanionBuilder = JWBloodGlucosesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$JWBloodGlucosesTableUpdateCompanionBuilder = JWBloodGlucosesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$JWBloodGlucosesTableFilterComposer
    extends Composer<_$JWDatabase, $JWBloodGlucosesTable> {
  $$JWBloodGlucosesTableFilterComposer({
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

class $$JWBloodGlucosesTableOrderingComposer
    extends Composer<_$JWDatabase, $JWBloodGlucosesTable> {
  $$JWBloodGlucosesTableOrderingComposer({
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

class $$JWBloodGlucosesTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWBloodGlucosesTable> {
  $$JWBloodGlucosesTableAnnotationComposer({
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

class $$JWBloodGlucosesTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWBloodGlucosesTable,
    JWBloodGlucoseRow,
    $$JWBloodGlucosesTableFilterComposer,
    $$JWBloodGlucosesTableOrderingComposer,
    $$JWBloodGlucosesTableAnnotationComposer,
    $$JWBloodGlucosesTableCreateCompanionBuilder,
    $$JWBloodGlucosesTableUpdateCompanionBuilder,
    (
      JWBloodGlucoseRow,
      BaseReferences<_$JWDatabase, $JWBloodGlucosesTable, JWBloodGlucoseRow>
    ),
    JWBloodGlucoseRow,
    PrefetchHooks Function()> {
  $$JWBloodGlucosesTableTableManager(
      _$JWDatabase db, $JWBloodGlucosesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWBloodGlucosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWBloodGlucosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWBloodGlucosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JWBloodGlucosesCompanion(
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
              JWBloodGlucosesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JWBloodGlucosesTable, JWBloodGlucoseRow>(
                        table),
                    BaseReferences<_$JWDatabase, $JWBloodGlucosesTable,
                        JWBloodGlucoseRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWBloodGlucosesTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWBloodGlucosesTable,
    JWBloodGlucoseRow,
    $$JWBloodGlucosesTableFilterComposer,
    $$JWBloodGlucosesTableOrderingComposer,
    $$JWBloodGlucosesTableAnnotationComposer,
    $$JWBloodGlucosesTableCreateCompanionBuilder,
    $$JWBloodGlucosesTableUpdateCompanionBuilder,
    (
      JWBloodGlucoseRow,
      BaseReferences<_$JWDatabase, $JWBloodGlucosesTable, JWBloodGlucoseRow>
    ),
    JWBloodGlucoseRow,
    PrefetchHooks Function()>;
typedef $$JWSportsTableCreateCompanionBuilder = JWSportsCompanion Function({
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
typedef $$JWSportsTableUpdateCompanionBuilder = JWSportsCompanion Function({
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

class $$JWSportsTableFilterComposer
    extends Composer<_$JWDatabase, $JWSportsTable> {
  $$JWSportsTableFilterComposer({
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

class $$JWSportsTableOrderingComposer
    extends Composer<_$JWDatabase, $JWSportsTable> {
  $$JWSportsTableOrderingComposer({
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

class $$JWSportsTableAnnotationComposer
    extends Composer<_$JWDatabase, $JWSportsTable> {
  $$JWSportsTableAnnotationComposer({
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

class $$JWSportsTableTableManager extends RootTableManager<
    _$JWDatabase,
    $JWSportsTable,
    JWSportRow,
    $$JWSportsTableFilterComposer,
    $$JWSportsTableOrderingComposer,
    $$JWSportsTableAnnotationComposer,
    $$JWSportsTableCreateCompanionBuilder,
    $$JWSportsTableUpdateCompanionBuilder,
    (JWSportRow, BaseReferences<_$JWDatabase, $JWSportsTable, JWSportRow>),
    JWSportRow,
    PrefetchHooks Function()> {
  $$JWSportsTableTableManager(_$JWDatabase db, $JWSportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JWSportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JWSportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JWSportsTableAnnotationComposer($db: db, $table: table),
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
              JWSportsCompanion(
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
              JWSportsCompanion.insert(
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
                    e.readTable<$JWSportsTable, JWSportRow>(table),
                    BaseReferences<_$JWDatabase, $JWSportsTable, JWSportRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JWSportsTableProcessedTableManager = ProcessedTableManager<
    _$JWDatabase,
    $JWSportsTable,
    JWSportRow,
    $$JWSportsTableFilterComposer,
    $$JWSportsTableOrderingComposer,
    $$JWSportsTableAnnotationComposer,
    $$JWSportsTableCreateCompanionBuilder,
    $$JWSportsTableUpdateCompanionBuilder,
    (JWSportRow, BaseReferences<_$JWDatabase, $JWSportsTable, JWSportRow>),
    JWSportRow,
    PrefetchHooks Function()>;

class $JWDatabaseManager {
  final _$JWDatabase _db;
  $JWDatabaseManager(this._db);
  $$JWActivitiesTableTableManager get jWActivities =>
      $$JWActivitiesTableTableManager(_db, _db.jWActivities);
  $$JWSleepsTableTableManager get jWSleeps =>
      $$JWSleepsTableTableManager(_db, _db.jWSleeps);
  $$JWHeartRatesTableTableManager get jWHeartRates =>
      $$JWHeartRatesTableTableManager(_db, _db.jWHeartRates);
  $$JWBloodPressuresTableTableManager get jWBloodPressures =>
      $$JWBloodPressuresTableTableManager(_db, _db.jWBloodPressures);
  $$JWBloodOxygensTableTableManager get jWBloodOxygens =>
      $$JWBloodOxygensTableTableManager(_db, _db.jWBloodOxygens);
  $$JWHrvsTableTableManager get jWHrvs =>
      $$JWHrvsTableTableManager(_db, _db.jWHrvs);
  $$JWPressuresTableTableManager get jWPressures =>
      $$JWPressuresTableTableManager(_db, _db.jWPressures);
  $$JWTemperaturesTableTableManager get jWTemperatures =>
      $$JWTemperaturesTableTableManager(_db, _db.jWTemperatures);
  $$JWBloodGlucosesTableTableManager get jWBloodGlucoses =>
      $$JWBloodGlucosesTableTableManager(_db, _db.jWBloodGlucoses);
  $$JWSportsTableTableManager get jWSports =>
      $$JWSportsTableTableManager(_db, _db.jWSports);
}
