// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_database.dart';

// ignore_for_file: type=lint
class $WsActivitiesTable extends WsActivities
    with TableInfo<$WsActivitiesTable, WsActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsActivitiesTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_activity';
  @override
  VerificationContext validateIntegrity(Insertable<WsActivity> instance,
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
  WsActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsActivity(
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
  $WsActivitiesTable createAlias(String alias) {
    return $WsActivitiesTable(attachedDatabase, alias);
  }
}

class WsActivity extends DataClass implements Insertable<WsActivity> {
  final String userId;
  final String deviceMac;
  final int time;
  final int steps;
  final int distance;
  final int energy;
  final int activeTime;
  final int mode;
  const WsActivity(
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

  WsActivitiesCompanion toCompanion(bool nullToAbsent) {
    return WsActivitiesCompanion(
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

  factory WsActivity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsActivity(
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

  WsActivity copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? steps,
          int? distance,
          int? energy,
          int? activeTime,
          int? mode}) =>
      WsActivity(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        steps: steps ?? this.steps,
        distance: distance ?? this.distance,
        energy: energy ?? this.energy,
        activeTime: activeTime ?? this.activeTime,
        mode: mode ?? this.mode,
      );
  WsActivity copyWithCompanion(WsActivitiesCompanion data) {
    return WsActivity(
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
    return (StringBuffer('WsActivity(')
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
      (other is WsActivity &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.steps == this.steps &&
          other.distance == this.distance &&
          other.energy == this.energy &&
          other.activeTime == this.activeTime &&
          other.mode == this.mode);
}

class WsActivitiesCompanion extends UpdateCompanion<WsActivity> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> steps;
  final Value<int> distance;
  final Value<int> energy;
  final Value<int> activeTime;
  final Value<int> mode;
  final Value<int> rowid;
  const WsActivitiesCompanion({
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
  WsActivitiesCompanion.insert({
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
  static Insertable<WsActivity> custom({
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

  WsActivitiesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? steps,
      Value<int>? distance,
      Value<int>? energy,
      Value<int>? activeTime,
      Value<int>? mode,
      Value<int>? rowid}) {
    return WsActivitiesCompanion(
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
    return (StringBuffer('WsActivitiesCompanion(')
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

class $WsSleepsTable extends WsSleeps with TableInfo<$WsSleepsTable, WsSleep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsSleepsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_sleep';
  @override
  VerificationContext validateIntegrity(Insertable<WsSleep> instance,
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
  WsSleep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsSleep(
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
  $WsSleepsTable createAlias(String alias) {
    return $WsSleepsTable(attachedDatabase, alias);
  }
}

class WsSleep extends DataClass implements Insertable<WsSleep> {
  final String userId;
  final String deviceMac;
  final int time;
  final int mode;
  const WsSleep(
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

  WsSleepsCompanion toCompanion(bool nullToAbsent) {
    return WsSleepsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      mode: Value(mode),
    );
  }

  factory WsSleep.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsSleep(
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

  WsSleep copyWith({String? userId, String? deviceMac, int? time, int? mode}) =>
      WsSleep(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        mode: mode ?? this.mode,
      );
  WsSleep copyWithCompanion(WsSleepsCompanion data) {
    return WsSleep(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsSleep(')
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
      (other is WsSleep &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.mode == this.mode);
}

class WsSleepsCompanion extends UpdateCompanion<WsSleep> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> mode;
  final Value<int> rowid;
  const WsSleepsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.mode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsSleepsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int mode,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        mode = Value(mode);
  static Insertable<WsSleep> custom({
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

  WsSleepsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? mode,
      Value<int>? rowid}) {
    return WsSleepsCompanion(
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
    return (StringBuffer('WsSleepsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('mode: $mode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WsHeartRatesTable extends WsHeartRates
    with TableInfo<$WsHeartRatesTable, WsHeartRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsHeartRatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
      'bpm', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, deviceMac, time, bpm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ws_heart_rate';
  @override
  VerificationContext validateIntegrity(Insertable<WsHeartRate> instance,
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
    if (data.containsKey('bpm')) {
      context.handle(
          _bpmMeta, bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta));
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, deviceMac, time};
  @override
  WsHeartRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsHeartRate(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_mac'])!,
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time'])!,
      bpm: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bpm'])!,
    );
  }

  @override
  $WsHeartRatesTable createAlias(String alias) {
    return $WsHeartRatesTable(attachedDatabase, alias);
  }
}

class WsHeartRate extends DataClass implements Insertable<WsHeartRate> {
  final String userId;
  final String deviceMac;
  final int time;
  final int bpm;
  const WsHeartRate(
      {required this.userId,
      required this.deviceMac,
      required this.time,
      required this.bpm});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['device_mac'] = Variable<String>(deviceMac);
    map['time'] = Variable<int>(time);
    map['bpm'] = Variable<int>(bpm);
    return map;
  }

  WsHeartRatesCompanion toCompanion(bool nullToAbsent) {
    return WsHeartRatesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      bpm: Value(bpm),
    );
  }

  factory WsHeartRate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsHeartRate(
      userId: serializer.fromJson<String>(json['userId']),
      deviceMac: serializer.fromJson<String>(json['deviceMac']),
      time: serializer.fromJson<int>(json['time']),
      bpm: serializer.fromJson<int>(json['bpm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'deviceMac': serializer.toJson<String>(deviceMac),
      'time': serializer.toJson<int>(time),
      'bpm': serializer.toJson<int>(bpm),
    };
  }

  WsHeartRate copyWith(
          {String? userId, String? deviceMac, int? time, int? bpm}) =>
      WsHeartRate(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        bpm: bpm ?? this.bpm,
      );
  WsHeartRate copyWithCompanion(WsHeartRatesCompanion data) {
    return WsHeartRate(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsHeartRate(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('bpm: $bpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, deviceMac, time, bpm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WsHeartRate &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.bpm == this.bpm);
}

class WsHeartRatesCompanion extends UpdateCompanion<WsHeartRate> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> bpm;
  final Value<int> rowid;
  const WsHeartRatesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.bpm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsHeartRatesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int bpm,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        bpm = Value(bpm);
  static Insertable<WsHeartRate> custom({
    Expression<String>? userId,
    Expression<String>? deviceMac,
    Expression<int>? time,
    Expression<int>? bpm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (deviceMac != null) 'device_mac': deviceMac,
      if (time != null) 'time': time,
      if (bpm != null) 'bpm': bpm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WsHeartRatesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? bpm,
      Value<int>? rowid}) {
    return WsHeartRatesCompanion(
      userId: userId ?? this.userId,
      deviceMac: deviceMac ?? this.deviceMac,
      time: time ?? this.time,
      bpm: bpm ?? this.bpm,
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
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WsHeartRatesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('bpm: $bpm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WsBloodPressuresTable extends WsBloodPressures
    with TableInfo<$WsBloodPressuresTable, WsBloodPressure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsBloodPressuresTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_blood_pressure';
  @override
  VerificationContext validateIntegrity(Insertable<WsBloodPressure> instance,
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
  WsBloodPressure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsBloodPressure(
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
  $WsBloodPressuresTable createAlias(String alias) {
    return $WsBloodPressuresTable(attachedDatabase, alias);
  }
}

class WsBloodPressure extends DataClass implements Insertable<WsBloodPressure> {
  final String userId;
  final String deviceMac;
  final int time;
  final int systolic;
  final int diastolic;
  const WsBloodPressure(
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

  WsBloodPressuresCompanion toCompanion(bool nullToAbsent) {
    return WsBloodPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      systolic: Value(systolic),
      diastolic: Value(diastolic),
    );
  }

  factory WsBloodPressure.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsBloodPressure(
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

  WsBloodPressure copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? systolic,
          int? diastolic}) =>
      WsBloodPressure(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        systolic: systolic ?? this.systolic,
        diastolic: diastolic ?? this.diastolic,
      );
  WsBloodPressure copyWithCompanion(WsBloodPressuresCompanion data) {
    return WsBloodPressure(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      systolic: data.systolic.present ? data.systolic.value : this.systolic,
      diastolic: data.diastolic.present ? data.diastolic.value : this.diastolic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsBloodPressure(')
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
      (other is WsBloodPressure &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.systolic == this.systolic &&
          other.diastolic == this.diastolic);
}

class WsBloodPressuresCompanion extends UpdateCompanion<WsBloodPressure> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> systolic;
  final Value<int> diastolic;
  final Value<int> rowid;
  const WsBloodPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.systolic = const Value.absent(),
    this.diastolic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsBloodPressuresCompanion.insert({
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
  static Insertable<WsBloodPressure> custom({
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

  WsBloodPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? systolic,
      Value<int>? diastolic,
      Value<int>? rowid}) {
    return WsBloodPressuresCompanion(
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
    return (StringBuffer('WsBloodPressuresCompanion(')
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

class $WsBloodOxygensTable extends WsBloodOxygens
    with TableInfo<$WsBloodOxygensTable, WsBloodOxygen> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsBloodOxygensTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_blood_oxygen';
  @override
  VerificationContext validateIntegrity(Insertable<WsBloodOxygen> instance,
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
  WsBloodOxygen map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsBloodOxygen(
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
  $WsBloodOxygensTable createAlias(String alias) {
    return $WsBloodOxygensTable(attachedDatabase, alias);
  }
}

class WsBloodOxygen extends DataClass implements Insertable<WsBloodOxygen> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  final int? high;
  final int? low;
  const WsBloodOxygen(
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

  WsBloodOxygensCompanion toCompanion(bool nullToAbsent) {
    return WsBloodOxygensCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
      high: high == null && nullToAbsent ? const Value.absent() : Value(high),
      low: low == null && nullToAbsent ? const Value.absent() : Value(low),
    );
  }

  factory WsBloodOxygen.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsBloodOxygen(
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

  WsBloodOxygen copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          int? value,
          Value<int?> high = const Value.absent(),
          Value<int?> low = const Value.absent()}) =>
      WsBloodOxygen(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
        high: high.present ? high.value : this.high,
        low: low.present ? low.value : this.low,
      );
  WsBloodOxygen copyWithCompanion(WsBloodOxygensCompanion data) {
    return WsBloodOxygen(
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
    return (StringBuffer('WsBloodOxygen(')
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
      (other is WsBloodOxygen &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value &&
          other.high == this.high &&
          other.low == this.low);
}

class WsBloodOxygensCompanion extends UpdateCompanion<WsBloodOxygen> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int?> high;
  final Value<int?> low;
  final Value<int> rowid;
  const WsBloodOxygensCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsBloodOxygensCompanion.insert({
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
  static Insertable<WsBloodOxygen> custom({
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

  WsBloodOxygensCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int?>? high,
      Value<int?>? low,
      Value<int>? rowid}) {
    return WsBloodOxygensCompanion(
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
    return (StringBuffer('WsBloodOxygensCompanion(')
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

class $WsHrvsTable extends WsHrvs with TableInfo<$WsHrvsTable, WsHrv> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsHrvsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_hrv';
  @override
  VerificationContext validateIntegrity(Insertable<WsHrv> instance,
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
  WsHrv map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsHrv(
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
  $WsHrvsTable createAlias(String alias) {
    return $WsHrvsTable(attachedDatabase, alias);
  }
}

class WsHrv extends DataClass implements Insertable<WsHrv> {
  final String userId;
  final String deviceMac;
  final int time;
  final int sdnn;
  const WsHrv(
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

  WsHrvsCompanion toCompanion(bool nullToAbsent) {
    return WsHrvsCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      sdnn: Value(sdnn),
    );
  }

  factory WsHrv.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsHrv(
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

  WsHrv copyWith({String? userId, String? deviceMac, int? time, int? sdnn}) =>
      WsHrv(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        sdnn: sdnn ?? this.sdnn,
      );
  WsHrv copyWithCompanion(WsHrvsCompanion data) {
    return WsHrv(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      sdnn: data.sdnn.present ? data.sdnn.value : this.sdnn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsHrv(')
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
      (other is WsHrv &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.sdnn == this.sdnn);
}

class WsHrvsCompanion extends UpdateCompanion<WsHrv> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> sdnn;
  final Value<int> rowid;
  const WsHrvsCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.sdnn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsHrvsCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int sdnn,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        sdnn = Value(sdnn);
  static Insertable<WsHrv> custom({
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

  WsHrvsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? sdnn,
      Value<int>? rowid}) {
    return WsHrvsCompanion(
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
    return (StringBuffer('WsHrvsCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('sdnn: $sdnn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WsPressuresTable extends WsPressures
    with TableInfo<$WsPressuresTable, WsPressure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsPressuresTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_pressure';
  @override
  VerificationContext validateIntegrity(Insertable<WsPressure> instance,
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
  WsPressure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsPressure(
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
  $WsPressuresTable createAlias(String alias) {
    return $WsPressuresTable(attachedDatabase, alias);
  }
}

class WsPressure extends DataClass implements Insertable<WsPressure> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const WsPressure(
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

  WsPressuresCompanion toCompanion(bool nullToAbsent) {
    return WsPressuresCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory WsPressure.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsPressure(
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

  WsPressure copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      WsPressure(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  WsPressure copyWithCompanion(WsPressuresCompanion data) {
    return WsPressure(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsPressure(')
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
      (other is WsPressure &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class WsPressuresCompanion extends UpdateCompanion<WsPressure> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const WsPressuresCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsPressuresCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<WsPressure> custom({
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

  WsPressuresCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return WsPressuresCompanion(
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
    return (StringBuffer('WsPressuresCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WsTemperaturesTable extends WsTemperatures
    with TableInfo<$WsTemperaturesTable, WsTemperature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsTemperaturesTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_temperature';
  @override
  VerificationContext validateIntegrity(Insertable<WsTemperature> instance,
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
  WsTemperature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsTemperature(
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
  $WsTemperaturesTable createAlias(String alias) {
    return $WsTemperaturesTable(attachedDatabase, alias);
  }
}

class WsTemperature extends DataClass implements Insertable<WsTemperature> {
  final String userId;
  final String deviceMac;
  final int time;
  final double skinTemperature;
  final int heatStress;
  final bool worn;
  final bool compensated;
  const WsTemperature(
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

  WsTemperaturesCompanion toCompanion(bool nullToAbsent) {
    return WsTemperaturesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      skinTemperature: Value(skinTemperature),
      heatStress: Value(heatStress),
      worn: Value(worn),
      compensated: Value(compensated),
    );
  }

  factory WsTemperature.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsTemperature(
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

  WsTemperature copyWith(
          {String? userId,
          String? deviceMac,
          int? time,
          double? skinTemperature,
          int? heatStress,
          bool? worn,
          bool? compensated}) =>
      WsTemperature(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        skinTemperature: skinTemperature ?? this.skinTemperature,
        heatStress: heatStress ?? this.heatStress,
        worn: worn ?? this.worn,
        compensated: compensated ?? this.compensated,
      );
  WsTemperature copyWithCompanion(WsTemperaturesCompanion data) {
    return WsTemperature(
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
    return (StringBuffer('WsTemperature(')
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
      (other is WsTemperature &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.skinTemperature == this.skinTemperature &&
          other.heatStress == this.heatStress &&
          other.worn == this.worn &&
          other.compensated == this.compensated);
}

class WsTemperaturesCompanion extends UpdateCompanion<WsTemperature> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<double> skinTemperature;
  final Value<int> heatStress;
  final Value<bool> worn;
  final Value<bool> compensated;
  final Value<int> rowid;
  const WsTemperaturesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.skinTemperature = const Value.absent(),
    this.heatStress = const Value.absent(),
    this.worn = const Value.absent(),
    this.compensated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsTemperaturesCompanion.insert({
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
  static Insertable<WsTemperature> custom({
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

  WsTemperaturesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<double>? skinTemperature,
      Value<int>? heatStress,
      Value<bool>? worn,
      Value<bool>? compensated,
      Value<int>? rowid}) {
    return WsTemperaturesCompanion(
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
    return (StringBuffer('WsTemperaturesCompanion(')
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

class $WsBloodGlucosesTable extends WsBloodGlucoses
    with TableInfo<$WsBloodGlucosesTable, WsBloodGlucose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsBloodGlucosesTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_blood_glucose';
  @override
  VerificationContext validateIntegrity(Insertable<WsBloodGlucose> instance,
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
  WsBloodGlucose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsBloodGlucose(
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
  $WsBloodGlucosesTable createAlias(String alias) {
    return $WsBloodGlucosesTable(attachedDatabase, alias);
  }
}

class WsBloodGlucose extends DataClass implements Insertable<WsBloodGlucose> {
  final String userId;
  final String deviceMac;
  final int time;
  final int value;
  const WsBloodGlucose(
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

  WsBloodGlucosesCompanion toCompanion(bool nullToAbsent) {
    return WsBloodGlucosesCompanion(
      userId: Value(userId),
      deviceMac: Value(deviceMac),
      time: Value(time),
      value: Value(value),
    );
  }

  factory WsBloodGlucose.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsBloodGlucose(
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

  WsBloodGlucose copyWith(
          {String? userId, String? deviceMac, int? time, int? value}) =>
      WsBloodGlucose(
        userId: userId ?? this.userId,
        deviceMac: deviceMac ?? this.deviceMac,
        time: time ?? this.time,
        value: value ?? this.value,
      );
  WsBloodGlucose copyWithCompanion(WsBloodGlucosesCompanion data) {
    return WsBloodGlucose(
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceMac: data.deviceMac.present ? data.deviceMac.value : this.deviceMac,
      time: data.time.present ? data.time.value : this.time,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WsBloodGlucose(')
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
      (other is WsBloodGlucose &&
          other.userId == this.userId &&
          other.deviceMac == this.deviceMac &&
          other.time == this.time &&
          other.value == this.value);
}

class WsBloodGlucosesCompanion extends UpdateCompanion<WsBloodGlucose> {
  final Value<String> userId;
  final Value<String> deviceMac;
  final Value<int> time;
  final Value<int> value;
  final Value<int> rowid;
  const WsBloodGlucosesCompanion({
    this.userId = const Value.absent(),
    this.deviceMac = const Value.absent(),
    this.time = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WsBloodGlucosesCompanion.insert({
    required String userId,
    required String deviceMac,
    required int time,
    required int value,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        deviceMac = Value(deviceMac),
        time = Value(time),
        value = Value(value);
  static Insertable<WsBloodGlucose> custom({
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

  WsBloodGlucosesCompanion copyWith(
      {Value<String>? userId,
      Value<String>? deviceMac,
      Value<int>? time,
      Value<int>? value,
      Value<int>? rowid}) {
    return WsBloodGlucosesCompanion(
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
    return (StringBuffer('WsBloodGlucosesCompanion(')
          ..write('userId: $userId, ')
          ..write('deviceMac: $deviceMac, ')
          ..write('time: $time, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WsSportsTable extends WsSports with TableInfo<$WsSportsTable, WsSport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WsSportsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'ws_sport';
  @override
  VerificationContext validateIntegrity(Insertable<WsSport> instance,
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
  WsSport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WsSport(
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
  $WsSportsTable createAlias(String alias) {
    return $WsSportsTable(attachedDatabase, alias);
  }
}

class WsSport extends DataClass implements Insertable<WsSport> {
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
  const WsSport(
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

  WsSportsCompanion toCompanion(bool nullToAbsent) {
    return WsSportsCompanion(
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

  factory WsSport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WsSport(
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

  WsSport copyWith(
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
      WsSport(
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
  WsSport copyWithCompanion(WsSportsCompanion data) {
    return WsSport(
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
    return (StringBuffer('WsSport(')
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
      (other is WsSport &&
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

class WsSportsCompanion extends UpdateCompanion<WsSport> {
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
  const WsSportsCompanion({
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
  WsSportsCompanion.insert({
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
  static Insertable<WsSport> custom({
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

  WsSportsCompanion copyWith(
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
    return WsSportsCompanion(
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
    return (StringBuffer('WsSportsCompanion(')
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

abstract class _$WSDatabase extends GeneratedDatabase {
  _$WSDatabase(QueryExecutor e) : super(e);
  $WSDatabaseManager get managers => $WSDatabaseManager(this);
  late final $WsActivitiesTable wsActivities = $WsActivitiesTable(this);
  late final $WsSleepsTable wsSleeps = $WsSleepsTable(this);
  late final $WsHeartRatesTable wsHeartRates = $WsHeartRatesTable(this);
  late final $WsBloodPressuresTable wsBloodPressures =
      $WsBloodPressuresTable(this);
  late final $WsBloodOxygensTable wsBloodOxygens = $WsBloodOxygensTable(this);
  late final $WsHrvsTable wsHrvs = $WsHrvsTable(this);
  late final $WsPressuresTable wsPressures = $WsPressuresTable(this);
  late final $WsTemperaturesTable wsTemperatures = $WsTemperaturesTable(this);
  late final $WsBloodGlucosesTable wsBloodGlucoses =
      $WsBloodGlucosesTable(this);
  late final $WsSportsTable wsSports = $WsSportsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        wsActivities,
        wsSleeps,
        wsHeartRates,
        wsBloodPressures,
        wsBloodOxygens,
        wsHrvs,
        wsPressures,
        wsTemperatures,
        wsBloodGlucoses,
        wsSports
      ];
}

typedef $$WsActivitiesTableCreateCompanionBuilder = WsActivitiesCompanion
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
typedef $$WsActivitiesTableUpdateCompanionBuilder = WsActivitiesCompanion
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

class $$WsActivitiesTableFilterComposer
    extends Composer<_$WSDatabase, $WsActivitiesTable> {
  $$WsActivitiesTableFilterComposer({
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

class $$WsActivitiesTableOrderingComposer
    extends Composer<_$WSDatabase, $WsActivitiesTable> {
  $$WsActivitiesTableOrderingComposer({
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

class $$WsActivitiesTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsActivitiesTable> {
  $$WsActivitiesTableAnnotationComposer({
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

class $$WsActivitiesTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsActivitiesTable,
    WsActivity,
    $$WsActivitiesTableFilterComposer,
    $$WsActivitiesTableOrderingComposer,
    $$WsActivitiesTableAnnotationComposer,
    $$WsActivitiesTableCreateCompanionBuilder,
    $$WsActivitiesTableUpdateCompanionBuilder,
    (WsActivity, BaseReferences<_$WSDatabase, $WsActivitiesTable, WsActivity>),
    WsActivity,
    PrefetchHooks Function()> {
  $$WsActivitiesTableTableManager(_$WSDatabase db, $WsActivitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsActivitiesTableAnnotationComposer($db: db, $table: table),
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
              WsActivitiesCompanion(
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
              WsActivitiesCompanion.insert(
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
                    e.readTable<$WsActivitiesTable, WsActivity>(table),
                    BaseReferences<_$WSDatabase, $WsActivitiesTable,
                        WsActivity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsActivitiesTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsActivitiesTable,
    WsActivity,
    $$WsActivitiesTableFilterComposer,
    $$WsActivitiesTableOrderingComposer,
    $$WsActivitiesTableAnnotationComposer,
    $$WsActivitiesTableCreateCompanionBuilder,
    $$WsActivitiesTableUpdateCompanionBuilder,
    (WsActivity, BaseReferences<_$WSDatabase, $WsActivitiesTable, WsActivity>),
    WsActivity,
    PrefetchHooks Function()>;
typedef $$WsSleepsTableCreateCompanionBuilder = WsSleepsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int mode,
  Value<int> rowid,
});
typedef $$WsSleepsTableUpdateCompanionBuilder = WsSleepsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> mode,
  Value<int> rowid,
});

class $$WsSleepsTableFilterComposer
    extends Composer<_$WSDatabase, $WsSleepsTable> {
  $$WsSleepsTableFilterComposer({
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

class $$WsSleepsTableOrderingComposer
    extends Composer<_$WSDatabase, $WsSleepsTable> {
  $$WsSleepsTableOrderingComposer({
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

class $$WsSleepsTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsSleepsTable> {
  $$WsSleepsTableAnnotationComposer({
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

class $$WsSleepsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsSleepsTable,
    WsSleep,
    $$WsSleepsTableFilterComposer,
    $$WsSleepsTableOrderingComposer,
    $$WsSleepsTableAnnotationComposer,
    $$WsSleepsTableCreateCompanionBuilder,
    $$WsSleepsTableUpdateCompanionBuilder,
    (WsSleep, BaseReferences<_$WSDatabase, $WsSleepsTable, WsSleep>),
    WsSleep,
    PrefetchHooks Function()> {
  $$WsSleepsTableTableManager(_$WSDatabase db, $WsSleepsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsSleepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsSleepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsSleepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsSleepsCompanion(
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
              WsSleepsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            mode: mode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsSleepsTable, WsSleep>(table),
                    BaseReferences<_$WSDatabase, $WsSleepsTable, WsSleep>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsSleepsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsSleepsTable,
    WsSleep,
    $$WsSleepsTableFilterComposer,
    $$WsSleepsTableOrderingComposer,
    $$WsSleepsTableAnnotationComposer,
    $$WsSleepsTableCreateCompanionBuilder,
    $$WsSleepsTableUpdateCompanionBuilder,
    (WsSleep, BaseReferences<_$WSDatabase, $WsSleepsTable, WsSleep>),
    WsSleep,
    PrefetchHooks Function()>;
typedef $$WsHeartRatesTableCreateCompanionBuilder = WsHeartRatesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int bpm,
  Value<int> rowid,
});
typedef $$WsHeartRatesTableUpdateCompanionBuilder = WsHeartRatesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> bpm,
  Value<int> rowid,
});

class $$WsHeartRatesTableFilterComposer
    extends Composer<_$WSDatabase, $WsHeartRatesTable> {
  $$WsHeartRatesTableFilterComposer({
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

  ColumnFilters<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnFilters(column));
}

class $$WsHeartRatesTableOrderingComposer
    extends Composer<_$WSDatabase, $WsHeartRatesTable> {
  $$WsHeartRatesTableOrderingComposer({
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

  ColumnOrderings<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnOrderings(column));
}

class $$WsHeartRatesTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsHeartRatesTable> {
  $$WsHeartRatesTableAnnotationComposer({
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

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);
}

class $$WsHeartRatesTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsHeartRatesTable,
    WsHeartRate,
    $$WsHeartRatesTableFilterComposer,
    $$WsHeartRatesTableOrderingComposer,
    $$WsHeartRatesTableAnnotationComposer,
    $$WsHeartRatesTableCreateCompanionBuilder,
    $$WsHeartRatesTableUpdateCompanionBuilder,
    (
      WsHeartRate,
      BaseReferences<_$WSDatabase, $WsHeartRatesTable, WsHeartRate>
    ),
    WsHeartRate,
    PrefetchHooks Function()> {
  $$WsHeartRatesTableTableManager(_$WSDatabase db, $WsHeartRatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsHeartRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsHeartRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsHeartRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> bpm = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsHeartRatesCompanion(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            bpm: bpm,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required String deviceMac,
            required int time,
            required int bpm,
            Value<int> rowid = const Value.absent(),
          }) =>
              WsHeartRatesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            bpm: bpm,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsHeartRatesTable, WsHeartRate>(table),
                    BaseReferences<_$WSDatabase, $WsHeartRatesTable,
                        WsHeartRate>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsHeartRatesTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsHeartRatesTable,
    WsHeartRate,
    $$WsHeartRatesTableFilterComposer,
    $$WsHeartRatesTableOrderingComposer,
    $$WsHeartRatesTableAnnotationComposer,
    $$WsHeartRatesTableCreateCompanionBuilder,
    $$WsHeartRatesTableUpdateCompanionBuilder,
    (
      WsHeartRate,
      BaseReferences<_$WSDatabase, $WsHeartRatesTable, WsHeartRate>
    ),
    WsHeartRate,
    PrefetchHooks Function()>;
typedef $$WsBloodPressuresTableCreateCompanionBuilder
    = WsBloodPressuresCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int systolic,
  required int diastolic,
  Value<int> rowid,
});
typedef $$WsBloodPressuresTableUpdateCompanionBuilder
    = WsBloodPressuresCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> systolic,
  Value<int> diastolic,
  Value<int> rowid,
});

class $$WsBloodPressuresTableFilterComposer
    extends Composer<_$WSDatabase, $WsBloodPressuresTable> {
  $$WsBloodPressuresTableFilterComposer({
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

class $$WsBloodPressuresTableOrderingComposer
    extends Composer<_$WSDatabase, $WsBloodPressuresTable> {
  $$WsBloodPressuresTableOrderingComposer({
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

class $$WsBloodPressuresTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsBloodPressuresTable> {
  $$WsBloodPressuresTableAnnotationComposer({
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

class $$WsBloodPressuresTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsBloodPressuresTable,
    WsBloodPressure,
    $$WsBloodPressuresTableFilterComposer,
    $$WsBloodPressuresTableOrderingComposer,
    $$WsBloodPressuresTableAnnotationComposer,
    $$WsBloodPressuresTableCreateCompanionBuilder,
    $$WsBloodPressuresTableUpdateCompanionBuilder,
    (
      WsBloodPressure,
      BaseReferences<_$WSDatabase, $WsBloodPressuresTable, WsBloodPressure>
    ),
    WsBloodPressure,
    PrefetchHooks Function()> {
  $$WsBloodPressuresTableTableManager(
      _$WSDatabase db, $WsBloodPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsBloodPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsBloodPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsBloodPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> systolic = const Value.absent(),
            Value<int> diastolic = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsBloodPressuresCompanion(
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
              WsBloodPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            systolic: systolic,
            diastolic: diastolic,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsBloodPressuresTable, WsBloodPressure>(table),
                    BaseReferences<_$WSDatabase, $WsBloodPressuresTable,
                        WsBloodPressure>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsBloodPressuresTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsBloodPressuresTable,
    WsBloodPressure,
    $$WsBloodPressuresTableFilterComposer,
    $$WsBloodPressuresTableOrderingComposer,
    $$WsBloodPressuresTableAnnotationComposer,
    $$WsBloodPressuresTableCreateCompanionBuilder,
    $$WsBloodPressuresTableUpdateCompanionBuilder,
    (
      WsBloodPressure,
      BaseReferences<_$WSDatabase, $WsBloodPressuresTable, WsBloodPressure>
    ),
    WsBloodPressure,
    PrefetchHooks Function()>;
typedef $$WsBloodOxygensTableCreateCompanionBuilder = WsBloodOxygensCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});
typedef $$WsBloodOxygensTableUpdateCompanionBuilder = WsBloodOxygensCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int?> high,
  Value<int?> low,
  Value<int> rowid,
});

class $$WsBloodOxygensTableFilterComposer
    extends Composer<_$WSDatabase, $WsBloodOxygensTable> {
  $$WsBloodOxygensTableFilterComposer({
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

class $$WsBloodOxygensTableOrderingComposer
    extends Composer<_$WSDatabase, $WsBloodOxygensTable> {
  $$WsBloodOxygensTableOrderingComposer({
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

class $$WsBloodOxygensTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsBloodOxygensTable> {
  $$WsBloodOxygensTableAnnotationComposer({
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

class $$WsBloodOxygensTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsBloodOxygensTable,
    WsBloodOxygen,
    $$WsBloodOxygensTableFilterComposer,
    $$WsBloodOxygensTableOrderingComposer,
    $$WsBloodOxygensTableAnnotationComposer,
    $$WsBloodOxygensTableCreateCompanionBuilder,
    $$WsBloodOxygensTableUpdateCompanionBuilder,
    (
      WsBloodOxygen,
      BaseReferences<_$WSDatabase, $WsBloodOxygensTable, WsBloodOxygen>
    ),
    WsBloodOxygen,
    PrefetchHooks Function()> {
  $$WsBloodOxygensTableTableManager(_$WSDatabase db, $WsBloodOxygensTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsBloodOxygensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsBloodOxygensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsBloodOxygensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int?> high = const Value.absent(),
            Value<int?> low = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsBloodOxygensCompanion(
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
              WsBloodOxygensCompanion.insert(
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
                    e.readTable<$WsBloodOxygensTable, WsBloodOxygen>(table),
                    BaseReferences<_$WSDatabase, $WsBloodOxygensTable,
                        WsBloodOxygen>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsBloodOxygensTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsBloodOxygensTable,
    WsBloodOxygen,
    $$WsBloodOxygensTableFilterComposer,
    $$WsBloodOxygensTableOrderingComposer,
    $$WsBloodOxygensTableAnnotationComposer,
    $$WsBloodOxygensTableCreateCompanionBuilder,
    $$WsBloodOxygensTableUpdateCompanionBuilder,
    (
      WsBloodOxygen,
      BaseReferences<_$WSDatabase, $WsBloodOxygensTable, WsBloodOxygen>
    ),
    WsBloodOxygen,
    PrefetchHooks Function()>;
typedef $$WsHrvsTableCreateCompanionBuilder = WsHrvsCompanion Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int sdnn,
  Value<int> rowid,
});
typedef $$WsHrvsTableUpdateCompanionBuilder = WsHrvsCompanion Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> sdnn,
  Value<int> rowid,
});

class $$WsHrvsTableFilterComposer extends Composer<_$WSDatabase, $WsHrvsTable> {
  $$WsHrvsTableFilterComposer({
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

class $$WsHrvsTableOrderingComposer
    extends Composer<_$WSDatabase, $WsHrvsTable> {
  $$WsHrvsTableOrderingComposer({
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

class $$WsHrvsTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsHrvsTable> {
  $$WsHrvsTableAnnotationComposer({
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

class $$WsHrvsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsHrvsTable,
    WsHrv,
    $$WsHrvsTableFilterComposer,
    $$WsHrvsTableOrderingComposer,
    $$WsHrvsTableAnnotationComposer,
    $$WsHrvsTableCreateCompanionBuilder,
    $$WsHrvsTableUpdateCompanionBuilder,
    (WsHrv, BaseReferences<_$WSDatabase, $WsHrvsTable, WsHrv>),
    WsHrv,
    PrefetchHooks Function()> {
  $$WsHrvsTableTableManager(_$WSDatabase db, $WsHrvsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsHrvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsHrvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsHrvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> sdnn = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsHrvsCompanion(
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
              WsHrvsCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            sdnn: sdnn,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsHrvsTable, WsHrv>(table),
                    BaseReferences<_$WSDatabase, $WsHrvsTable, WsHrv>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsHrvsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsHrvsTable,
    WsHrv,
    $$WsHrvsTableFilterComposer,
    $$WsHrvsTableOrderingComposer,
    $$WsHrvsTableAnnotationComposer,
    $$WsHrvsTableCreateCompanionBuilder,
    $$WsHrvsTableUpdateCompanionBuilder,
    (WsHrv, BaseReferences<_$WSDatabase, $WsHrvsTable, WsHrv>),
    WsHrv,
    PrefetchHooks Function()>;
typedef $$WsPressuresTableCreateCompanionBuilder = WsPressuresCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$WsPressuresTableUpdateCompanionBuilder = WsPressuresCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$WsPressuresTableFilterComposer
    extends Composer<_$WSDatabase, $WsPressuresTable> {
  $$WsPressuresTableFilterComposer({
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

class $$WsPressuresTableOrderingComposer
    extends Composer<_$WSDatabase, $WsPressuresTable> {
  $$WsPressuresTableOrderingComposer({
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

class $$WsPressuresTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsPressuresTable> {
  $$WsPressuresTableAnnotationComposer({
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

class $$WsPressuresTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsPressuresTable,
    WsPressure,
    $$WsPressuresTableFilterComposer,
    $$WsPressuresTableOrderingComposer,
    $$WsPressuresTableAnnotationComposer,
    $$WsPressuresTableCreateCompanionBuilder,
    $$WsPressuresTableUpdateCompanionBuilder,
    (WsPressure, BaseReferences<_$WSDatabase, $WsPressuresTable, WsPressure>),
    WsPressure,
    PrefetchHooks Function()> {
  $$WsPressuresTableTableManager(_$WSDatabase db, $WsPressuresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsPressuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsPressuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsPressuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsPressuresCompanion(
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
              WsPressuresCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsPressuresTable, WsPressure>(table),
                    BaseReferences<_$WSDatabase, $WsPressuresTable, WsPressure>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsPressuresTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsPressuresTable,
    WsPressure,
    $$WsPressuresTableFilterComposer,
    $$WsPressuresTableOrderingComposer,
    $$WsPressuresTableAnnotationComposer,
    $$WsPressuresTableCreateCompanionBuilder,
    $$WsPressuresTableUpdateCompanionBuilder,
    (WsPressure, BaseReferences<_$WSDatabase, $WsPressuresTable, WsPressure>),
    WsPressure,
    PrefetchHooks Function()>;
typedef $$WsTemperaturesTableCreateCompanionBuilder = WsTemperaturesCompanion
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
typedef $$WsTemperaturesTableUpdateCompanionBuilder = WsTemperaturesCompanion
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

class $$WsTemperaturesTableFilterComposer
    extends Composer<_$WSDatabase, $WsTemperaturesTable> {
  $$WsTemperaturesTableFilterComposer({
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

class $$WsTemperaturesTableOrderingComposer
    extends Composer<_$WSDatabase, $WsTemperaturesTable> {
  $$WsTemperaturesTableOrderingComposer({
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

class $$WsTemperaturesTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsTemperaturesTable> {
  $$WsTemperaturesTableAnnotationComposer({
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

class $$WsTemperaturesTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsTemperaturesTable,
    WsTemperature,
    $$WsTemperaturesTableFilterComposer,
    $$WsTemperaturesTableOrderingComposer,
    $$WsTemperaturesTableAnnotationComposer,
    $$WsTemperaturesTableCreateCompanionBuilder,
    $$WsTemperaturesTableUpdateCompanionBuilder,
    (
      WsTemperature,
      BaseReferences<_$WSDatabase, $WsTemperaturesTable, WsTemperature>
    ),
    WsTemperature,
    PrefetchHooks Function()> {
  $$WsTemperaturesTableTableManager(_$WSDatabase db, $WsTemperaturesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsTemperaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsTemperaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsTemperaturesTableAnnotationComposer($db: db, $table: table),
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
              WsTemperaturesCompanion(
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
              WsTemperaturesCompanion.insert(
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
                    e.readTable<$WsTemperaturesTable, WsTemperature>(table),
                    BaseReferences<_$WSDatabase, $WsTemperaturesTable,
                        WsTemperature>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsTemperaturesTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsTemperaturesTable,
    WsTemperature,
    $$WsTemperaturesTableFilterComposer,
    $$WsTemperaturesTableOrderingComposer,
    $$WsTemperaturesTableAnnotationComposer,
    $$WsTemperaturesTableCreateCompanionBuilder,
    $$WsTemperaturesTableUpdateCompanionBuilder,
    (
      WsTemperature,
      BaseReferences<_$WSDatabase, $WsTemperaturesTable, WsTemperature>
    ),
    WsTemperature,
    PrefetchHooks Function()>;
typedef $$WsBloodGlucosesTableCreateCompanionBuilder = WsBloodGlucosesCompanion
    Function({
  required String userId,
  required String deviceMac,
  required int time,
  required int value,
  Value<int> rowid,
});
typedef $$WsBloodGlucosesTableUpdateCompanionBuilder = WsBloodGlucosesCompanion
    Function({
  Value<String> userId,
  Value<String> deviceMac,
  Value<int> time,
  Value<int> value,
  Value<int> rowid,
});

class $$WsBloodGlucosesTableFilterComposer
    extends Composer<_$WSDatabase, $WsBloodGlucosesTable> {
  $$WsBloodGlucosesTableFilterComposer({
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

class $$WsBloodGlucosesTableOrderingComposer
    extends Composer<_$WSDatabase, $WsBloodGlucosesTable> {
  $$WsBloodGlucosesTableOrderingComposer({
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

class $$WsBloodGlucosesTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsBloodGlucosesTable> {
  $$WsBloodGlucosesTableAnnotationComposer({
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

class $$WsBloodGlucosesTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsBloodGlucosesTable,
    WsBloodGlucose,
    $$WsBloodGlucosesTableFilterComposer,
    $$WsBloodGlucosesTableOrderingComposer,
    $$WsBloodGlucosesTableAnnotationComposer,
    $$WsBloodGlucosesTableCreateCompanionBuilder,
    $$WsBloodGlucosesTableUpdateCompanionBuilder,
    (
      WsBloodGlucose,
      BaseReferences<_$WSDatabase, $WsBloodGlucosesTable, WsBloodGlucose>
    ),
    WsBloodGlucose,
    PrefetchHooks Function()> {
  $$WsBloodGlucosesTableTableManager(
      _$WSDatabase db, $WsBloodGlucosesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsBloodGlucosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsBloodGlucosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsBloodGlucosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> deviceMac = const Value.absent(),
            Value<int> time = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WsBloodGlucosesCompanion(
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
              WsBloodGlucosesCompanion.insert(
            userId: userId,
            deviceMac: deviceMac,
            time: time,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WsBloodGlucosesTable, WsBloodGlucose>(table),
                    BaseReferences<_$WSDatabase, $WsBloodGlucosesTable,
                        WsBloodGlucose>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsBloodGlucosesTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsBloodGlucosesTable,
    WsBloodGlucose,
    $$WsBloodGlucosesTableFilterComposer,
    $$WsBloodGlucosesTableOrderingComposer,
    $$WsBloodGlucosesTableAnnotationComposer,
    $$WsBloodGlucosesTableCreateCompanionBuilder,
    $$WsBloodGlucosesTableUpdateCompanionBuilder,
    (
      WsBloodGlucose,
      BaseReferences<_$WSDatabase, $WsBloodGlucosesTable, WsBloodGlucose>
    ),
    WsBloodGlucose,
    PrefetchHooks Function()>;
typedef $$WsSportsTableCreateCompanionBuilder = WsSportsCompanion Function({
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
typedef $$WsSportsTableUpdateCompanionBuilder = WsSportsCompanion Function({
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

class $$WsSportsTableFilterComposer
    extends Composer<_$WSDatabase, $WsSportsTable> {
  $$WsSportsTableFilterComposer({
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

class $$WsSportsTableOrderingComposer
    extends Composer<_$WSDatabase, $WsSportsTable> {
  $$WsSportsTableOrderingComposer({
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

class $$WsSportsTableAnnotationComposer
    extends Composer<_$WSDatabase, $WsSportsTable> {
  $$WsSportsTableAnnotationComposer({
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

class $$WsSportsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $WsSportsTable,
    WsSport,
    $$WsSportsTableFilterComposer,
    $$WsSportsTableOrderingComposer,
    $$WsSportsTableAnnotationComposer,
    $$WsSportsTableCreateCompanionBuilder,
    $$WsSportsTableUpdateCompanionBuilder,
    (WsSport, BaseReferences<_$WSDatabase, $WsSportsTable, WsSport>),
    WsSport,
    PrefetchHooks Function()> {
  $$WsSportsTableTableManager(_$WSDatabase db, $WsSportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WsSportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WsSportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WsSportsTableAnnotationComposer($db: db, $table: table),
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
              WsSportsCompanion(
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
              WsSportsCompanion.insert(
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
                    e.readTable<$WsSportsTable, WsSport>(table),
                    BaseReferences<_$WSDatabase, $WsSportsTable, WsSport>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WsSportsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $WsSportsTable,
    WsSport,
    $$WsSportsTableFilterComposer,
    $$WsSportsTableOrderingComposer,
    $$WsSportsTableAnnotationComposer,
    $$WsSportsTableCreateCompanionBuilder,
    $$WsSportsTableUpdateCompanionBuilder,
    (WsSport, BaseReferences<_$WSDatabase, $WsSportsTable, WsSport>),
    WsSport,
    PrefetchHooks Function()>;

class $WSDatabaseManager {
  final _$WSDatabase _db;
  $WSDatabaseManager(this._db);
  $$WsActivitiesTableTableManager get wsActivities =>
      $$WsActivitiesTableTableManager(_db, _db.wsActivities);
  $$WsSleepsTableTableManager get wsSleeps =>
      $$WsSleepsTableTableManager(_db, _db.wsSleeps);
  $$WsHeartRatesTableTableManager get wsHeartRates =>
      $$WsHeartRatesTableTableManager(_db, _db.wsHeartRates);
  $$WsBloodPressuresTableTableManager get wsBloodPressures =>
      $$WsBloodPressuresTableTableManager(_db, _db.wsBloodPressures);
  $$WsBloodOxygensTableTableManager get wsBloodOxygens =>
      $$WsBloodOxygensTableTableManager(_db, _db.wsBloodOxygens);
  $$WsHrvsTableTableManager get wsHrvs =>
      $$WsHrvsTableTableManager(_db, _db.wsHrvs);
  $$WsPressuresTableTableManager get wsPressures =>
      $$WsPressuresTableTableManager(_db, _db.wsPressures);
  $$WsTemperaturesTableTableManager get wsTemperatures =>
      $$WsTemperaturesTableTableManager(_db, _db.wsTemperatures);
  $$WsBloodGlucosesTableTableManager get wsBloodGlucoses =>
      $$WsBloodGlucosesTableTableManager(_db, _db.wsBloodGlucoses);
  $$WsSportsTableTableManager get wsSports =>
      $$WsSportsTableTableManager(_db, _db.wsSports);
}
