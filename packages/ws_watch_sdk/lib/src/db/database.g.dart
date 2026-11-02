// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _btMacMeta = const VerificationMeta('btMac');
  @override
  late final GeneratedColumn<String> btMac = GeneratedColumn<String>(
      'bt_mac', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firmwareVersionMeta =
      const VerificationMeta('firmwareVersion');
  @override
  late final GeneratedColumn<String> firmwareVersion = GeneratedColumn<String>(
      'firmware_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deviceInfoRawMeta =
      const VerificationMeta('deviceInfoRaw');
  @override
  late final GeneratedColumn<Uint8List> deviceInfoRaw =
      GeneratedColumn<Uint8List>('device_info_raw', aliasedName, true,
          type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _capabilitiesRawMeta =
      const VerificationMeta('capabilitiesRaw');
  @override
  late final GeneratedColumn<Uint8List> capabilitiesRaw =
      GeneratedColumn<Uint8List>('capabilities_raw', aliasedName, true,
          type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _chipTypeMeta =
      const VerificationMeta('chipType');
  @override
  late final GeneratedColumn<int> chipType = GeneratedColumn<int>(
      'chip_type', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastConnectedAtMeta =
      const VerificationMeta('lastConnectedAt');
  @override
  late final GeneratedColumn<int> lastConnectedAt = GeneratedColumn<int>(
      'last_connected_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        deviceId,
        userId,
        name,
        btMac,
        firmwareVersion,
        deviceInfoRaw,
        capabilitiesRaw,
        chipType,
        lastConnectedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(Insertable<Device> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('bt_mac')) {
      context.handle(
          _btMacMeta, btMac.isAcceptableOrUnknown(data['bt_mac']!, _btMacMeta));
    }
    if (data.containsKey('firmware_version')) {
      context.handle(
          _firmwareVersionMeta,
          firmwareVersion.isAcceptableOrUnknown(
              data['firmware_version']!, _firmwareVersionMeta));
    }
    if (data.containsKey('device_info_raw')) {
      context.handle(
          _deviceInfoRawMeta,
          deviceInfoRaw.isAcceptableOrUnknown(
              data['device_info_raw']!, _deviceInfoRawMeta));
    }
    if (data.containsKey('capabilities_raw')) {
      context.handle(
          _capabilitiesRawMeta,
          capabilitiesRaw.isAcceptableOrUnknown(
              data['capabilities_raw']!, _capabilitiesRawMeta));
    }
    if (data.containsKey('chip_type')) {
      context.handle(_chipTypeMeta,
          chipType.isAcceptableOrUnknown(data['chip_type']!, _chipTypeMeta));
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
          _lastConnectedAtMeta,
          lastConnectedAt.isAcceptableOrUnknown(
              data['last_connected_at']!, _lastConnectedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      btMac: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bt_mac']),
      firmwareVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}firmware_version']),
      deviceInfoRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}device_info_raw']),
      capabilitiesRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}capabilities_raw']),
      chipType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chip_type']),
      lastConnectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_connected_at']),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String deviceId;
  final String userId;
  final String name;
  final String? btMac;
  final String? firmwareVersion;
  final Uint8List? deviceInfoRaw;
  final Uint8List? capabilitiesRaw;
  final int? chipType;
  final int? lastConnectedAt;
  const Device(
      {required this.deviceId,
      required this.userId,
      required this.name,
      this.btMac,
      this.firmwareVersion,
      this.deviceInfoRaw,
      this.capabilitiesRaw,
      this.chipType,
      this.lastConnectedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || btMac != null) {
      map['bt_mac'] = Variable<String>(btMac);
    }
    if (!nullToAbsent || firmwareVersion != null) {
      map['firmware_version'] = Variable<String>(firmwareVersion);
    }
    if (!nullToAbsent || deviceInfoRaw != null) {
      map['device_info_raw'] = Variable<Uint8List>(deviceInfoRaw);
    }
    if (!nullToAbsent || capabilitiesRaw != null) {
      map['capabilities_raw'] = Variable<Uint8List>(capabilitiesRaw);
    }
    if (!nullToAbsent || chipType != null) {
      map['chip_type'] = Variable<int>(chipType);
    }
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<int>(lastConnectedAt);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      deviceId: Value(deviceId),
      userId: Value(userId),
      name: Value(name),
      btMac:
          btMac == null && nullToAbsent ? const Value.absent() : Value(btMac),
      firmwareVersion: firmwareVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(firmwareVersion),
      deviceInfoRaw: deviceInfoRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceInfoRaw),
      capabilitiesRaw: capabilitiesRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(capabilitiesRaw),
      chipType: chipType == null && nullToAbsent
          ? const Value.absent()
          : Value(chipType),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
    );
  }

  factory Device.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      btMac: serializer.fromJson<String?>(json['btMac']),
      firmwareVersion: serializer.fromJson<String?>(json['firmwareVersion']),
      deviceInfoRaw: serializer.fromJson<Uint8List?>(json['deviceInfoRaw']),
      capabilitiesRaw: serializer.fromJson<Uint8List?>(json['capabilitiesRaw']),
      chipType: serializer.fromJson<int?>(json['chipType']),
      lastConnectedAt: serializer.fromJson<int?>(json['lastConnectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'btMac': serializer.toJson<String?>(btMac),
      'firmwareVersion': serializer.toJson<String?>(firmwareVersion),
      'deviceInfoRaw': serializer.toJson<Uint8List?>(deviceInfoRaw),
      'capabilitiesRaw': serializer.toJson<Uint8List?>(capabilitiesRaw),
      'chipType': serializer.toJson<int?>(chipType),
      'lastConnectedAt': serializer.toJson<int?>(lastConnectedAt),
    };
  }

  Device copyWith(
          {String? deviceId,
          String? userId,
          String? name,
          Value<String?> btMac = const Value.absent(),
          Value<String?> firmwareVersion = const Value.absent(),
          Value<Uint8List?> deviceInfoRaw = const Value.absent(),
          Value<Uint8List?> capabilitiesRaw = const Value.absent(),
          Value<int?> chipType = const Value.absent(),
          Value<int?> lastConnectedAt = const Value.absent()}) =>
      Device(
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        btMac: btMac.present ? btMac.value : this.btMac,
        firmwareVersion: firmwareVersion.present
            ? firmwareVersion.value
            : this.firmwareVersion,
        deviceInfoRaw:
            deviceInfoRaw.present ? deviceInfoRaw.value : this.deviceInfoRaw,
        capabilitiesRaw: capabilitiesRaw.present
            ? capabilitiesRaw.value
            : this.capabilitiesRaw,
        chipType: chipType.present ? chipType.value : this.chipType,
        lastConnectedAt: lastConnectedAt.present
            ? lastConnectedAt.value
            : this.lastConnectedAt,
      );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      btMac: data.btMac.present ? data.btMac.value : this.btMac,
      firmwareVersion: data.firmwareVersion.present
          ? data.firmwareVersion.value
          : this.firmwareVersion,
      deviceInfoRaw: data.deviceInfoRaw.present
          ? data.deviceInfoRaw.value
          : this.deviceInfoRaw,
      capabilitiesRaw: data.capabilitiesRaw.present
          ? data.capabilitiesRaw.value
          : this.capabilitiesRaw,
      chipType: data.chipType.present ? data.chipType.value : this.chipType,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('btMac: $btMac, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('deviceInfoRaw: $deviceInfoRaw, ')
          ..write('capabilitiesRaw: $capabilitiesRaw, ')
          ..write('chipType: $chipType, ')
          ..write('lastConnectedAt: $lastConnectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      deviceId,
      userId,
      name,
      btMac,
      firmwareVersion,
      $driftBlobEquality.hash(deviceInfoRaw),
      $driftBlobEquality.hash(capabilitiesRaw),
      chipType,
      lastConnectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.btMac == this.btMac &&
          other.firmwareVersion == this.firmwareVersion &&
          $driftBlobEquality.equals(other.deviceInfoRaw, this.deviceInfoRaw) &&
          $driftBlobEquality.equals(
              other.capabilitiesRaw, this.capabilitiesRaw) &&
          other.chipType == this.chipType &&
          other.lastConnectedAt == this.lastConnectedAt);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String> name;
  final Value<String?> btMac;
  final Value<String?> firmwareVersion;
  final Value<Uint8List?> deviceInfoRaw;
  final Value<Uint8List?> capabilitiesRaw;
  final Value<int?> chipType;
  final Value<int?> lastConnectedAt;
  final Value<int> rowid;
  const DevicesCompanion({
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.btMac = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.deviceInfoRaw = const Value.absent(),
    this.capabilitiesRaw = const Value.absent(),
    this.chipType = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String deviceId,
    required String userId,
    this.name = const Value.absent(),
    this.btMac = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.deviceInfoRaw = const Value.absent(),
    this.capabilitiesRaw = const Value.absent(),
    this.chipType = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : deviceId = Value(deviceId),
        userId = Value(userId);
  static Insertable<Device> custom({
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? btMac,
    Expression<String>? firmwareVersion,
    Expression<Uint8List>? deviceInfoRaw,
    Expression<Uint8List>? capabilitiesRaw,
    Expression<int>? chipType,
    Expression<int>? lastConnectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (btMac != null) 'bt_mac': btMac,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (deviceInfoRaw != null) 'device_info_raw': deviceInfoRaw,
      if (capabilitiesRaw != null) 'capabilities_raw': capabilitiesRaw,
      if (chipType != null) 'chip_type': chipType,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith(
      {Value<String>? deviceId,
      Value<String>? userId,
      Value<String>? name,
      Value<String?>? btMac,
      Value<String?>? firmwareVersion,
      Value<Uint8List?>? deviceInfoRaw,
      Value<Uint8List?>? capabilitiesRaw,
      Value<int?>? chipType,
      Value<int?>? lastConnectedAt,
      Value<int>? rowid}) {
    return DevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      btMac: btMac ?? this.btMac,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      deviceInfoRaw: deviceInfoRaw ?? this.deviceInfoRaw,
      capabilitiesRaw: capabilitiesRaw ?? this.capabilitiesRaw,
      chipType: chipType ?? this.chipType,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (btMac.present) {
      map['bt_mac'] = Variable<String>(btMac.value);
    }
    if (firmwareVersion.present) {
      map['firmware_version'] = Variable<String>(firmwareVersion.value);
    }
    if (deviceInfoRaw.present) {
      map['device_info_raw'] = Variable<Uint8List>(deviceInfoRaw.value);
    }
    if (capabilitiesRaw.present) {
      map['capabilities_raw'] = Variable<Uint8List>(capabilitiesRaw.value);
    }
    if (chipType.present) {
      map['chip_type'] = Variable<int>(chipType.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<int>(lastConnectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('btMac: $btMac, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('deviceInfoRaw: $deviceInfoRaw, ')
          ..write('capabilitiesRaw: $capabilitiesRaw, ')
          ..write('chipType: $chipType, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StepRecordsTable extends StepRecords
    with TableInfo<$StepRecordsTable, StepRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordTimeMeta =
      const VerificationMeta('recordTime');
  @override
  late final GeneratedColumn<int> recordTime = GeneratedColumn<int>(
      'record_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
      'mode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
      'steps', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bucketMinutesMeta =
      const VerificationMeta('bucketMinutes');
  @override
  late final GeneratedColumn<int> bucketMinutes = GeneratedColumn<int>(
      'bucket_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _averageHeartRateMeta =
      const VerificationMeta('averageHeartRate');
  @override
  late final GeneratedColumn<int> averageHeartRate = GeneratedColumn<int>(
      'average_heart_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _flagsMeta = const VerificationMeta('flags');
  @override
  late final GeneratedColumn<int> flags = GeneratedColumn<int>(
      'flags', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _caloriesDeciKcalMeta =
      const VerificationMeta('caloriesDeciKcal');
  @override
  late final GeneratedColumn<int> caloriesDeciKcal = GeneratedColumn<int>(
      'calories_deci_kcal', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _distanceMetersMeta =
      const VerificationMeta('distanceMeters');
  @override
  late final GeneratedColumn<int> distanceMeters = GeneratedColumn<int>(
      'distance_meters', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tzOffsetMinutesMeta =
      const VerificationMeta('tzOffsetMinutes');
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
      'tz_offset_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<Uint8List> raw = GeneratedColumn<Uint8List>(
      'raw', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        userId,
        recordTime,
        mode,
        steps,
        bucketMinutes,
        averageHeartRate,
        flags,
        caloriesDeciKcal,
        distanceMeters,
        tzOffsetMinutes,
        syncedAt,
        raw
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'step_records';
  @override
  VerificationContext validateIntegrity(Insertable<StepRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('record_time')) {
      context.handle(
          _recordTimeMeta,
          recordTime.isAcceptableOrUnknown(
              data['record_time']!, _recordTimeMeta));
    } else if (isInserting) {
      context.missing(_recordTimeMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
          _stepsMeta, steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta));
    }
    if (data.containsKey('bucket_minutes')) {
      context.handle(
          _bucketMinutesMeta,
          bucketMinutes.isAcceptableOrUnknown(
              data['bucket_minutes']!, _bucketMinutesMeta));
    } else if (isInserting) {
      context.missing(_bucketMinutesMeta);
    }
    if (data.containsKey('average_heart_rate')) {
      context.handle(
          _averageHeartRateMeta,
          averageHeartRate.isAcceptableOrUnknown(
              data['average_heart_rate']!, _averageHeartRateMeta));
    }
    if (data.containsKey('flags')) {
      context.handle(
          _flagsMeta, flags.isAcceptableOrUnknown(data['flags']!, _flagsMeta));
    } else if (isInserting) {
      context.missing(_flagsMeta);
    }
    if (data.containsKey('calories_deci_kcal')) {
      context.handle(
          _caloriesDeciKcalMeta,
          caloriesDeciKcal.isAcceptableOrUnknown(
              data['calories_deci_kcal']!, _caloriesDeciKcalMeta));
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
          _distanceMetersMeta,
          distanceMeters.isAcceptableOrUnknown(
              data['distance_meters']!, _distanceMetersMeta));
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
          _tzOffsetMinutesMeta,
          tzOffsetMinutes.isAcceptableOrUnknown(
              data['tz_offset_minutes']!, _tzOffsetMinutesMeta));
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('raw')) {
      context.handle(
          _rawMeta, raw.isAcceptableOrUnknown(data['raw']!, _rawMeta));
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {deviceId, userId, recordTime},
      ];
  @override
  StepRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recordTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}record_time'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mode'])!,
      steps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}steps']),
      bucketMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bucket_minutes'])!,
      averageHeartRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}average_heart_rate']),
      flags: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}flags'])!,
      caloriesDeciKcal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calories_deci_kcal']),
      distanceMeters: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}distance_meters']),
      tzOffsetMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tz_offset_minutes'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at'])!,
      raw: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}raw'])!,
    );
  }

  @override
  $StepRecordsTable createAlias(String alias) {
    return $StepRecordsTable(attachedDatabase, alias);
  }
}

class StepRecord extends DataClass implements Insertable<StepRecord> {
  final int id;
  final String deviceId;
  final String userId;
  final int recordTime;
  final int mode;
  final int? steps;
  final int bucketMinutes;
  final int? averageHeartRate;
  final int flags;
  final int? caloriesDeciKcal;
  final int? distanceMeters;
  final int tzOffsetMinutes;
  final int syncedAt;
  final Uint8List raw;
  const StepRecord(
      {required this.id,
      required this.deviceId,
      required this.userId,
      required this.recordTime,
      required this.mode,
      this.steps,
      required this.bucketMinutes,
      this.averageHeartRate,
      required this.flags,
      this.caloriesDeciKcal,
      this.distanceMeters,
      required this.tzOffsetMinutes,
      required this.syncedAt,
      required this.raw});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['record_time'] = Variable<int>(recordTime);
    map['mode'] = Variable<int>(mode);
    if (!nullToAbsent || steps != null) {
      map['steps'] = Variable<int>(steps);
    }
    map['bucket_minutes'] = Variable<int>(bucketMinutes);
    if (!nullToAbsent || averageHeartRate != null) {
      map['average_heart_rate'] = Variable<int>(averageHeartRate);
    }
    map['flags'] = Variable<int>(flags);
    if (!nullToAbsent || caloriesDeciKcal != null) {
      map['calories_deci_kcal'] = Variable<int>(caloriesDeciKcal);
    }
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<int>(distanceMeters);
    }
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    map['synced_at'] = Variable<int>(syncedAt);
    map['raw'] = Variable<Uint8List>(raw);
    return map;
  }

  StepRecordsCompanion toCompanion(bool nullToAbsent) {
    return StepRecordsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      userId: Value(userId),
      recordTime: Value(recordTime),
      mode: Value(mode),
      steps:
          steps == null && nullToAbsent ? const Value.absent() : Value(steps),
      bucketMinutes: Value(bucketMinutes),
      averageHeartRate: averageHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(averageHeartRate),
      flags: Value(flags),
      caloriesDeciKcal: caloriesDeciKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriesDeciKcal),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      syncedAt: Value(syncedAt),
      raw: Value(raw),
    );
  }

  factory StepRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepRecord(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      recordTime: serializer.fromJson<int>(json['recordTime']),
      mode: serializer.fromJson<int>(json['mode']),
      steps: serializer.fromJson<int?>(json['steps']),
      bucketMinutes: serializer.fromJson<int>(json['bucketMinutes']),
      averageHeartRate: serializer.fromJson<int?>(json['averageHeartRate']),
      flags: serializer.fromJson<int>(json['flags']),
      caloriesDeciKcal: serializer.fromJson<int?>(json['caloriesDeciKcal']),
      distanceMeters: serializer.fromJson<int?>(json['distanceMeters']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      syncedAt: serializer.fromJson<int>(json['syncedAt']),
      raw: serializer.fromJson<Uint8List>(json['raw']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'recordTime': serializer.toJson<int>(recordTime),
      'mode': serializer.toJson<int>(mode),
      'steps': serializer.toJson<int?>(steps),
      'bucketMinutes': serializer.toJson<int>(bucketMinutes),
      'averageHeartRate': serializer.toJson<int?>(averageHeartRate),
      'flags': serializer.toJson<int>(flags),
      'caloriesDeciKcal': serializer.toJson<int?>(caloriesDeciKcal),
      'distanceMeters': serializer.toJson<int?>(distanceMeters),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'syncedAt': serializer.toJson<int>(syncedAt),
      'raw': serializer.toJson<Uint8List>(raw),
    };
  }

  StepRecord copyWith(
          {int? id,
          String? deviceId,
          String? userId,
          int? recordTime,
          int? mode,
          Value<int?> steps = const Value.absent(),
          int? bucketMinutes,
          Value<int?> averageHeartRate = const Value.absent(),
          int? flags,
          Value<int?> caloriesDeciKcal = const Value.absent(),
          Value<int?> distanceMeters = const Value.absent(),
          int? tzOffsetMinutes,
          int? syncedAt,
          Uint8List? raw}) =>
      StepRecord(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        recordTime: recordTime ?? this.recordTime,
        mode: mode ?? this.mode,
        steps: steps.present ? steps.value : this.steps,
        bucketMinutes: bucketMinutes ?? this.bucketMinutes,
        averageHeartRate: averageHeartRate.present
            ? averageHeartRate.value
            : this.averageHeartRate,
        flags: flags ?? this.flags,
        caloriesDeciKcal: caloriesDeciKcal.present
            ? caloriesDeciKcal.value
            : this.caloriesDeciKcal,
        distanceMeters:
            distanceMeters.present ? distanceMeters.value : this.distanceMeters,
        tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
        syncedAt: syncedAt ?? this.syncedAt,
        raw: raw ?? this.raw,
      );
  StepRecord copyWithCompanion(StepRecordsCompanion data) {
    return StepRecord(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      recordTime:
          data.recordTime.present ? data.recordTime.value : this.recordTime,
      mode: data.mode.present ? data.mode.value : this.mode,
      steps: data.steps.present ? data.steps.value : this.steps,
      bucketMinutes: data.bucketMinutes.present
          ? data.bucketMinutes.value
          : this.bucketMinutes,
      averageHeartRate: data.averageHeartRate.present
          ? data.averageHeartRate.value
          : this.averageHeartRate,
      flags: data.flags.present ? data.flags.value : this.flags,
      caloriesDeciKcal: data.caloriesDeciKcal.present
          ? data.caloriesDeciKcal.value
          : this.caloriesDeciKcal,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      raw: data.raw.present ? data.raw.value : this.raw,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepRecord(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('recordTime: $recordTime, ')
          ..write('mode: $mode, ')
          ..write('steps: $steps, ')
          ..write('bucketMinutes: $bucketMinutes, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('flags: $flags, ')
          ..write('caloriesDeciKcal: $caloriesDeciKcal, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      deviceId,
      userId,
      recordTime,
      mode,
      steps,
      bucketMinutes,
      averageHeartRate,
      flags,
      caloriesDeciKcal,
      distanceMeters,
      tzOffsetMinutes,
      syncedAt,
      $driftBlobEquality.hash(raw));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepRecord &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.recordTime == this.recordTime &&
          other.mode == this.mode &&
          other.steps == this.steps &&
          other.bucketMinutes == this.bucketMinutes &&
          other.averageHeartRate == this.averageHeartRate &&
          other.flags == this.flags &&
          other.caloriesDeciKcal == this.caloriesDeciKcal &&
          other.distanceMeters == this.distanceMeters &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.syncedAt == this.syncedAt &&
          $driftBlobEquality.equals(other.raw, this.raw));
}

class StepRecordsCompanion extends UpdateCompanion<StepRecord> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<int> recordTime;
  final Value<int> mode;
  final Value<int?> steps;
  final Value<int> bucketMinutes;
  final Value<int?> averageHeartRate;
  final Value<int> flags;
  final Value<int?> caloriesDeciKcal;
  final Value<int?> distanceMeters;
  final Value<int> tzOffsetMinutes;
  final Value<int> syncedAt;
  final Value<Uint8List> raw;
  const StepRecordsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.recordTime = const Value.absent(),
    this.mode = const Value.absent(),
    this.steps = const Value.absent(),
    this.bucketMinutes = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.flags = const Value.absent(),
    this.caloriesDeciKcal = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.raw = const Value.absent(),
  });
  StepRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    required String userId,
    required int recordTime,
    required int mode,
    this.steps = const Value.absent(),
    required int bucketMinutes,
    this.averageHeartRate = const Value.absent(),
    required int flags,
    this.caloriesDeciKcal = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    required int tzOffsetMinutes,
    required int syncedAt,
    required Uint8List raw,
  })  : deviceId = Value(deviceId),
        userId = Value(userId),
        recordTime = Value(recordTime),
        mode = Value(mode),
        bucketMinutes = Value(bucketMinutes),
        flags = Value(flags),
        tzOffsetMinutes = Value(tzOffsetMinutes),
        syncedAt = Value(syncedAt),
        raw = Value(raw);
  static Insertable<StepRecord> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<int>? recordTime,
    Expression<int>? mode,
    Expression<int>? steps,
    Expression<int>? bucketMinutes,
    Expression<int>? averageHeartRate,
    Expression<int>? flags,
    Expression<int>? caloriesDeciKcal,
    Expression<int>? distanceMeters,
    Expression<int>? tzOffsetMinutes,
    Expression<int>? syncedAt,
    Expression<Uint8List>? raw,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (recordTime != null) 'record_time': recordTime,
      if (mode != null) 'mode': mode,
      if (steps != null) 'steps': steps,
      if (bucketMinutes != null) 'bucket_minutes': bucketMinutes,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (flags != null) 'flags': flags,
      if (caloriesDeciKcal != null) 'calories_deci_kcal': caloriesDeciKcal,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (raw != null) 'raw': raw,
    });
  }

  StepRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? deviceId,
      Value<String>? userId,
      Value<int>? recordTime,
      Value<int>? mode,
      Value<int?>? steps,
      Value<int>? bucketMinutes,
      Value<int?>? averageHeartRate,
      Value<int>? flags,
      Value<int?>? caloriesDeciKcal,
      Value<int?>? distanceMeters,
      Value<int>? tzOffsetMinutes,
      Value<int>? syncedAt,
      Value<Uint8List>? raw}) {
    return StepRecordsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      recordTime: recordTime ?? this.recordTime,
      mode: mode ?? this.mode,
      steps: steps ?? this.steps,
      bucketMinutes: bucketMinutes ?? this.bucketMinutes,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      flags: flags ?? this.flags,
      caloriesDeciKcal: caloriesDeciKcal ?? this.caloriesDeciKcal,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      syncedAt: syncedAt ?? this.syncedAt,
      raw: raw ?? this.raw,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recordTime.present) {
      map['record_time'] = Variable<int>(recordTime.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (bucketMinutes.present) {
      map['bucket_minutes'] = Variable<int>(bucketMinutes.value);
    }
    if (averageHeartRate.present) {
      map['average_heart_rate'] = Variable<int>(averageHeartRate.value);
    }
    if (flags.present) {
      map['flags'] = Variable<int>(flags.value);
    }
    if (caloriesDeciKcal.present) {
      map['calories_deci_kcal'] = Variable<int>(caloriesDeciKcal.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<int>(distanceMeters.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (raw.present) {
      map['raw'] = Variable<Uint8List>(raw.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StepRecordsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('recordTime: $recordTime, ')
          ..write('mode: $mode, ')
          ..write('steps: $steps, ')
          ..write('bucketMinutes: $bucketMinutes, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('flags: $flags, ')
          ..write('caloriesDeciKcal: $caloriesDeciKcal, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }
}

class $HeartRateRecordsTable extends HeartRateRecords
    with TableInfo<$HeartRateRecordsTable, HeartRateRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeartRateRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordTimeMeta =
      const VerificationMeta('recordTime');
  @override
  late final GeneratedColumn<int> recordTime = GeneratedColumn<int>(
      'record_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
      'bpm', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sourceKeyMeta =
      const VerificationMeta('sourceKey');
  @override
  late final GeneratedColumn<int> sourceKey = GeneratedColumn<int>(
      'source_key', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tzOffsetMinutesMeta =
      const VerificationMeta('tzOffsetMinutes');
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
      'tz_offset_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<Uint8List> raw = GeneratedColumn<Uint8List>(
      'raw', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        userId,
        recordTime,
        bpm,
        sourceKey,
        tzOffsetMinutes,
        syncedAt,
        raw
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'heart_rate_records';
  @override
  VerificationContext validateIntegrity(Insertable<HeartRateRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('record_time')) {
      context.handle(
          _recordTimeMeta,
          recordTime.isAcceptableOrUnknown(
              data['record_time']!, _recordTimeMeta));
    } else if (isInserting) {
      context.missing(_recordTimeMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
          _bpmMeta, bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta));
    }
    if (data.containsKey('source_key')) {
      context.handle(_sourceKeyMeta,
          sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta));
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
          _tzOffsetMinutesMeta,
          tzOffsetMinutes.isAcceptableOrUnknown(
              data['tz_offset_minutes']!, _tzOffsetMinutesMeta));
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('raw')) {
      context.handle(
          _rawMeta, raw.isAcceptableOrUnknown(data['raw']!, _rawMeta));
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {deviceId, userId, recordTime},
      ];
  @override
  HeartRateRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeartRateRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recordTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}record_time'])!,
      bpm: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bpm']),
      sourceKey: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_key'])!,
      tzOffsetMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tz_offset_minutes'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at'])!,
      raw: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}raw'])!,
    );
  }

  @override
  $HeartRateRecordsTable createAlias(String alias) {
    return $HeartRateRecordsTable(attachedDatabase, alias);
  }
}

class HeartRateRecord extends DataClass implements Insertable<HeartRateRecord> {
  final int id;
  final String deviceId;
  final String userId;
  final int recordTime;
  final int? bpm;
  final int sourceKey;
  final int tzOffsetMinutes;
  final int syncedAt;
  final Uint8List raw;
  const HeartRateRecord(
      {required this.id,
      required this.deviceId,
      required this.userId,
      required this.recordTime,
      this.bpm,
      required this.sourceKey,
      required this.tzOffsetMinutes,
      required this.syncedAt,
      required this.raw});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['record_time'] = Variable<int>(recordTime);
    if (!nullToAbsent || bpm != null) {
      map['bpm'] = Variable<int>(bpm);
    }
    map['source_key'] = Variable<int>(sourceKey);
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    map['synced_at'] = Variable<int>(syncedAt);
    map['raw'] = Variable<Uint8List>(raw);
    return map;
  }

  HeartRateRecordsCompanion toCompanion(bool nullToAbsent) {
    return HeartRateRecordsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      userId: Value(userId),
      recordTime: Value(recordTime),
      bpm: bpm == null && nullToAbsent ? const Value.absent() : Value(bpm),
      sourceKey: Value(sourceKey),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      syncedAt: Value(syncedAt),
      raw: Value(raw),
    );
  }

  factory HeartRateRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeartRateRecord(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      recordTime: serializer.fromJson<int>(json['recordTime']),
      bpm: serializer.fromJson<int?>(json['bpm']),
      sourceKey: serializer.fromJson<int>(json['sourceKey']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      syncedAt: serializer.fromJson<int>(json['syncedAt']),
      raw: serializer.fromJson<Uint8List>(json['raw']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'recordTime': serializer.toJson<int>(recordTime),
      'bpm': serializer.toJson<int?>(bpm),
      'sourceKey': serializer.toJson<int>(sourceKey),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'syncedAt': serializer.toJson<int>(syncedAt),
      'raw': serializer.toJson<Uint8List>(raw),
    };
  }

  HeartRateRecord copyWith(
          {int? id,
          String? deviceId,
          String? userId,
          int? recordTime,
          Value<int?> bpm = const Value.absent(),
          int? sourceKey,
          int? tzOffsetMinutes,
          int? syncedAt,
          Uint8List? raw}) =>
      HeartRateRecord(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        recordTime: recordTime ?? this.recordTime,
        bpm: bpm.present ? bpm.value : this.bpm,
        sourceKey: sourceKey ?? this.sourceKey,
        tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
        syncedAt: syncedAt ?? this.syncedAt,
        raw: raw ?? this.raw,
      );
  HeartRateRecord copyWithCompanion(HeartRateRecordsCompanion data) {
    return HeartRateRecord(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      recordTime:
          data.recordTime.present ? data.recordTime.value : this.recordTime,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      raw: data.raw.present ? data.raw.value : this.raw,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeartRateRecord(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('recordTime: $recordTime, ')
          ..write('bpm: $bpm, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId, userId, recordTime, bpm,
      sourceKey, tzOffsetMinutes, syncedAt, $driftBlobEquality.hash(raw));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeartRateRecord &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.recordTime == this.recordTime &&
          other.bpm == this.bpm &&
          other.sourceKey == this.sourceKey &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.syncedAt == this.syncedAt &&
          $driftBlobEquality.equals(other.raw, this.raw));
}

class HeartRateRecordsCompanion extends UpdateCompanion<HeartRateRecord> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<int> recordTime;
  final Value<int?> bpm;
  final Value<int> sourceKey;
  final Value<int> tzOffsetMinutes;
  final Value<int> syncedAt;
  final Value<Uint8List> raw;
  const HeartRateRecordsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.recordTime = const Value.absent(),
    this.bpm = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.raw = const Value.absent(),
  });
  HeartRateRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    required String userId,
    required int recordTime,
    this.bpm = const Value.absent(),
    required int sourceKey,
    required int tzOffsetMinutes,
    required int syncedAt,
    required Uint8List raw,
  })  : deviceId = Value(deviceId),
        userId = Value(userId),
        recordTime = Value(recordTime),
        sourceKey = Value(sourceKey),
        tzOffsetMinutes = Value(tzOffsetMinutes),
        syncedAt = Value(syncedAt),
        raw = Value(raw);
  static Insertable<HeartRateRecord> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<int>? recordTime,
    Expression<int>? bpm,
    Expression<int>? sourceKey,
    Expression<int>? tzOffsetMinutes,
    Expression<int>? syncedAt,
    Expression<Uint8List>? raw,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (recordTime != null) 'record_time': recordTime,
      if (bpm != null) 'bpm': bpm,
      if (sourceKey != null) 'source_key': sourceKey,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (raw != null) 'raw': raw,
    });
  }

  HeartRateRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? deviceId,
      Value<String>? userId,
      Value<int>? recordTime,
      Value<int?>? bpm,
      Value<int>? sourceKey,
      Value<int>? tzOffsetMinutes,
      Value<int>? syncedAt,
      Value<Uint8List>? raw}) {
    return HeartRateRecordsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      recordTime: recordTime ?? this.recordTime,
      bpm: bpm ?? this.bpm,
      sourceKey: sourceKey ?? this.sourceKey,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      syncedAt: syncedAt ?? this.syncedAt,
      raw: raw ?? this.raw,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recordTime.present) {
      map['record_time'] = Variable<int>(recordTime.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<int>(sourceKey.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (raw.present) {
      map['raw'] = Variable<Uint8List>(raw.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeartRateRecordsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('recordTime: $recordTime, ')
          ..write('bpm: $bpm, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs with TableInfo<$SyncLogsTable, SyncLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
      'ended_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _announcedJsonMeta =
      const VerificationMeta('announcedJson');
  @override
  late final GeneratedColumn<String> announcedJson = GeneratedColumn<String>(
      'announced_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedJsonMeta =
      const VerificationMeta('receivedJson');
  @override
  late final GeneratedColumn<String> receivedJson = GeneratedColumn<String>(
      'received_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceResultCodeMeta =
      const VerificationMeta('deviceResultCode');
  @override
  late final GeneratedColumn<int> deviceResultCode = GeneratedColumn<int>(
      'device_result_code', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _confirmationMeta =
      const VerificationMeta('confirmation');
  @override
  late final GeneratedColumn<String> confirmation = GeneratedColumn<String>(
      'confirmation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
      'result', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deviceId,
        userId,
        syncId,
        startedAt,
        endedAt,
        announcedJson,
        receivedJson,
        deviceResultCode,
        confirmation,
        result,
        reason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SyncLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('announced_json')) {
      context.handle(
          _announcedJsonMeta,
          announcedJson.isAcceptableOrUnknown(
              data['announced_json']!, _announcedJsonMeta));
    } else if (isInserting) {
      context.missing(_announcedJsonMeta);
    }
    if (data.containsKey('received_json')) {
      context.handle(
          _receivedJsonMeta,
          receivedJson.isAcceptableOrUnknown(
              data['received_json']!, _receivedJsonMeta));
    } else if (isInserting) {
      context.missing(_receivedJsonMeta);
    }
    if (data.containsKey('device_result_code')) {
      context.handle(
          _deviceResultCodeMeta,
          deviceResultCode.isAcceptableOrUnknown(
              data['device_result_code']!, _deviceResultCodeMeta));
    }
    if (data.containsKey('confirmation')) {
      context.handle(
          _confirmationMeta,
          confirmation.isAcceptableOrUnknown(
              data['confirmation']!, _confirmationMeta));
    } else if (isInserting) {
      context.missing(_confirmationMeta);
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta,
          result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ended_at'])!,
      announcedJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}announced_json'])!,
      receivedJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}received_json'])!,
      deviceResultCode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}device_result_code']),
      confirmation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}confirmation'])!,
      result: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }
}

class SyncLog extends DataClass implements Insertable<SyncLog> {
  final int id;
  final String deviceId;
  final String userId;
  final String syncId;
  final int startedAt;
  final int endedAt;
  final String announcedJson;
  final String receivedJson;
  final int? deviceResultCode;
  final String confirmation;
  final String result;
  final String? reason;
  const SyncLog(
      {required this.id,
      required this.deviceId,
      required this.userId,
      required this.syncId,
      required this.startedAt,
      required this.endedAt,
      required this.announcedJson,
      required this.receivedJson,
      this.deviceResultCode,
      required this.confirmation,
      required this.result,
      this.reason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['sync_id'] = Variable<String>(syncId);
    map['started_at'] = Variable<int>(startedAt);
    map['ended_at'] = Variable<int>(endedAt);
    map['announced_json'] = Variable<String>(announcedJson);
    map['received_json'] = Variable<String>(receivedJson);
    if (!nullToAbsent || deviceResultCode != null) {
      map['device_result_code'] = Variable<int>(deviceResultCode);
    }
    map['confirmation'] = Variable<String>(confirmation);
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      userId: Value(userId),
      syncId: Value(syncId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      announcedJson: Value(announcedJson),
      receivedJson: Value(receivedJson),
      deviceResultCode: deviceResultCode == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceResultCode),
      confirmation: Value(confirmation),
      result: Value(result),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
    );
  }

  factory SyncLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLog(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      syncId: serializer.fromJson<String>(json['syncId']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int>(json['endedAt']),
      announcedJson: serializer.fromJson<String>(json['announcedJson']),
      receivedJson: serializer.fromJson<String>(json['receivedJson']),
      deviceResultCode: serializer.fromJson<int?>(json['deviceResultCode']),
      confirmation: serializer.fromJson<String>(json['confirmation']),
      result: serializer.fromJson<String>(json['result']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'syncId': serializer.toJson<String>(syncId),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int>(endedAt),
      'announcedJson': serializer.toJson<String>(announcedJson),
      'receivedJson': serializer.toJson<String>(receivedJson),
      'deviceResultCode': serializer.toJson<int?>(deviceResultCode),
      'confirmation': serializer.toJson<String>(confirmation),
      'result': serializer.toJson<String>(result),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  SyncLog copyWith(
          {int? id,
          String? deviceId,
          String? userId,
          String? syncId,
          int? startedAt,
          int? endedAt,
          String? announcedJson,
          String? receivedJson,
          Value<int?> deviceResultCode = const Value.absent(),
          String? confirmation,
          String? result,
          Value<String?> reason = const Value.absent()}) =>
      SyncLog(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        syncId: syncId ?? this.syncId,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        announcedJson: announcedJson ?? this.announcedJson,
        receivedJson: receivedJson ?? this.receivedJson,
        deviceResultCode: deviceResultCode.present
            ? deviceResultCode.value
            : this.deviceResultCode,
        confirmation: confirmation ?? this.confirmation,
        result: result ?? this.result,
        reason: reason.present ? reason.value : this.reason,
      );
  SyncLog copyWithCompanion(SyncLogsCompanion data) {
    return SyncLog(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      announcedJson: data.announcedJson.present
          ? data.announcedJson.value
          : this.announcedJson,
      receivedJson: data.receivedJson.present
          ? data.receivedJson.value
          : this.receivedJson,
      deviceResultCode: data.deviceResultCode.present
          ? data.deviceResultCode.value
          : this.deviceResultCode,
      confirmation: data.confirmation.present
          ? data.confirmation.value
          : this.confirmation,
      result: data.result.present ? data.result.value : this.result,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLog(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('syncId: $syncId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('announcedJson: $announcedJson, ')
          ..write('receivedJson: $receivedJson, ')
          ..write('deviceResultCode: $deviceResultCode, ')
          ..write('confirmation: $confirmation, ')
          ..write('result: $result, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      deviceId,
      userId,
      syncId,
      startedAt,
      endedAt,
      announcedJson,
      receivedJson,
      deviceResultCode,
      confirmation,
      result,
      reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLog &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.syncId == this.syncId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.announcedJson == this.announcedJson &&
          other.receivedJson == this.receivedJson &&
          other.deviceResultCode == this.deviceResultCode &&
          other.confirmation == this.confirmation &&
          other.result == this.result &&
          other.reason == this.reason);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLog> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String> syncId;
  final Value<int> startedAt;
  final Value<int> endedAt;
  final Value<String> announcedJson;
  final Value<String> receivedJson;
  final Value<int?> deviceResultCode;
  final Value<String> confirmation;
  final Value<String> result;
  final Value<String?> reason;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.announcedJson = const Value.absent(),
    this.receivedJson = const Value.absent(),
    this.deviceResultCode = const Value.absent(),
    this.confirmation = const Value.absent(),
    this.result = const Value.absent(),
    this.reason = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    required String userId,
    required String syncId,
    required int startedAt,
    required int endedAt,
    required String announcedJson,
    required String receivedJson,
    this.deviceResultCode = const Value.absent(),
    required String confirmation,
    required String result,
    this.reason = const Value.absent(),
  })  : deviceId = Value(deviceId),
        userId = Value(userId),
        syncId = Value(syncId),
        startedAt = Value(startedAt),
        endedAt = Value(endedAt),
        announcedJson = Value(announcedJson),
        receivedJson = Value(receivedJson),
        confirmation = Value(confirmation),
        result = Value(result);
  static Insertable<SyncLog> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? syncId,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? announcedJson,
    Expression<String>? receivedJson,
    Expression<int>? deviceResultCode,
    Expression<String>? confirmation,
    Expression<String>? result,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (syncId != null) 'sync_id': syncId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (announcedJson != null) 'announced_json': announcedJson,
      if (receivedJson != null) 'received_json': receivedJson,
      if (deviceResultCode != null) 'device_result_code': deviceResultCode,
      if (confirmation != null) 'confirmation': confirmation,
      if (result != null) 'result': result,
      if (reason != null) 'reason': reason,
    });
  }

  SyncLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? deviceId,
      Value<String>? userId,
      Value<String>? syncId,
      Value<int>? startedAt,
      Value<int>? endedAt,
      Value<String>? announcedJson,
      Value<String>? receivedJson,
      Value<int?>? deviceResultCode,
      Value<String>? confirmation,
      Value<String>? result,
      Value<String?>? reason}) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      syncId: syncId ?? this.syncId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      announcedJson: announcedJson ?? this.announcedJson,
      receivedJson: receivedJson ?? this.receivedJson,
      deviceResultCode: deviceResultCode ?? this.deviceResultCode,
      confirmation: confirmation ?? this.confirmation,
      result: result ?? this.result,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (announcedJson.present) {
      map['announced_json'] = Variable<String>(announcedJson.value);
    }
    if (receivedJson.present) {
      map['received_json'] = Variable<String>(receivedJson.value);
    }
    if (deviceResultCode.present) {
      map['device_result_code'] = Variable<int>(deviceResultCode.value);
    }
    if (confirmation.present) {
      map['confirmation'] = Variable<String>(confirmation.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('syncId: $syncId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('announcedJson: $announcedJson, ')
          ..write('receivedJson: $receivedJson, ')
          ..write('deviceResultCode: $deviceResultCode, ')
          ..write('confirmation: $confirmation, ')
          ..write('result: $result, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

abstract class _$WSDatabase extends GeneratedDatabase {
  _$WSDatabase(QueryExecutor e) : super(e);
  $WSDatabaseManager get managers => $WSDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $StepRecordsTable stepRecords = $StepRecordsTable(this);
  late final $HeartRateRecordsTable heartRateRecords =
      $HeartRateRecordsTable(this);
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final Index stepDeviceTime = Index('step_device_time',
      'CREATE INDEX step_device_time ON step_records (device_id, record_time)');
  late final Index heartDeviceTime = Index('heart_device_time',
      'CREATE INDEX heart_device_time ON heart_rate_records (device_id, record_time)');
  late final Index syncDeviceStarted = Index('sync_device_started',
      'CREATE INDEX sync_device_started ON sync_logs (device_id, started_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        devices,
        stepRecords,
        heartRateRecords,
        syncLogs,
        stepDeviceTime,
        heartDeviceTime,
        syncDeviceStarted
      ];
}

typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String deviceId,
  required String userId,
  Value<String> name,
  Value<String?> btMac,
  Value<String?> firmwareVersion,
  Value<Uint8List?> deviceInfoRaw,
  Value<Uint8List?> capabilitiesRaw,
  Value<int?> chipType,
  Value<int?> lastConnectedAt,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> deviceId,
  Value<String> userId,
  Value<String> name,
  Value<String?> btMac,
  Value<String?> firmwareVersion,
  Value<Uint8List?> deviceInfoRaw,
  Value<Uint8List?> capabilitiesRaw,
  Value<int?> chipType,
  Value<int?> lastConnectedAt,
  Value<int> rowid,
});

class $$DevicesTableFilterComposer
    extends Composer<_$WSDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get btMac => $composableBuilder(
      column: $table.btMac, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firmwareVersion => $composableBuilder(
      column: $table.firmwareVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get deviceInfoRaw => $composableBuilder(
      column: $table.deviceInfoRaw, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get capabilitiesRaw => $composableBuilder(
      column: $table.capabilitiesRaw,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get chipType => $composableBuilder(
      column: $table.chipType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastConnectedAt => $composableBuilder(
      column: $table.lastConnectedAt,
      builder: (column) => ColumnFilters(column));
}

class $$DevicesTableOrderingComposer
    extends Composer<_$WSDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get btMac => $composableBuilder(
      column: $table.btMac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firmwareVersion => $composableBuilder(
      column: $table.firmwareVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get deviceInfoRaw => $composableBuilder(
      column: $table.deviceInfoRaw,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get capabilitiesRaw => $composableBuilder(
      column: $table.capabilitiesRaw,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get chipType => $composableBuilder(
      column: $table.chipType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastConnectedAt => $composableBuilder(
      column: $table.lastConnectedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$WSDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get btMac =>
      $composableBuilder(column: $table.btMac, builder: (column) => column);

  GeneratedColumn<String> get firmwareVersion => $composableBuilder(
      column: $table.firmwareVersion, builder: (column) => column);

  GeneratedColumn<Uint8List> get deviceInfoRaw => $composableBuilder(
      column: $table.deviceInfoRaw, builder: (column) => column);

  GeneratedColumn<Uint8List> get capabilitiesRaw => $composableBuilder(
      column: $table.capabilitiesRaw, builder: (column) => column);

  GeneratedColumn<int> get chipType =>
      $composableBuilder(column: $table.chipType, builder: (column) => column);

  GeneratedColumn<int> get lastConnectedAt => $composableBuilder(
      column: $table.lastConnectedAt, builder: (column) => column);
}

class $$DevicesTableTableManager extends RootTableManager<
    _$WSDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$WSDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()> {
  $$DevicesTableTableManager(_$WSDatabase db, $DevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> btMac = const Value.absent(),
            Value<String?> firmwareVersion = const Value.absent(),
            Value<Uint8List?> deviceInfoRaw = const Value.absent(),
            Value<Uint8List?> capabilitiesRaw = const Value.absent(),
            Value<int?> chipType = const Value.absent(),
            Value<int?> lastConnectedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion(
            deviceId: deviceId,
            userId: userId,
            name: name,
            btMac: btMac,
            firmwareVersion: firmwareVersion,
            deviceInfoRaw: deviceInfoRaw,
            capabilitiesRaw: capabilitiesRaw,
            chipType: chipType,
            lastConnectedAt: lastConnectedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String deviceId,
            required String userId,
            Value<String> name = const Value.absent(),
            Value<String?> btMac = const Value.absent(),
            Value<String?> firmwareVersion = const Value.absent(),
            Value<Uint8List?> deviceInfoRaw = const Value.absent(),
            Value<Uint8List?> capabilitiesRaw = const Value.absent(),
            Value<int?> chipType = const Value.absent(),
            Value<int?> lastConnectedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion.insert(
            deviceId: deviceId,
            userId: userId,
            name: name,
            btMac: btMac,
            firmwareVersion: firmwareVersion,
            deviceInfoRaw: deviceInfoRaw,
            capabilitiesRaw: capabilitiesRaw,
            chipType: chipType,
            lastConnectedAt: lastConnectedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DevicesTable, Device>(table),
                    BaseReferences<_$WSDatabase, $DevicesTable, Device>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DevicesTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $DevicesTable,
    Device,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (Device, BaseReferences<_$WSDatabase, $DevicesTable, Device>),
    Device,
    PrefetchHooks Function()>;
typedef $$StepRecordsTableCreateCompanionBuilder = StepRecordsCompanion
    Function({
  Value<int> id,
  required String deviceId,
  required String userId,
  required int recordTime,
  required int mode,
  Value<int?> steps,
  required int bucketMinutes,
  Value<int?> averageHeartRate,
  required int flags,
  Value<int?> caloriesDeciKcal,
  Value<int?> distanceMeters,
  required int tzOffsetMinutes,
  required int syncedAt,
  required Uint8List raw,
});
typedef $$StepRecordsTableUpdateCompanionBuilder = StepRecordsCompanion
    Function({
  Value<int> id,
  Value<String> deviceId,
  Value<String> userId,
  Value<int> recordTime,
  Value<int> mode,
  Value<int?> steps,
  Value<int> bucketMinutes,
  Value<int?> averageHeartRate,
  Value<int> flags,
  Value<int?> caloriesDeciKcal,
  Value<int?> distanceMeters,
  Value<int> tzOffsetMinutes,
  Value<int> syncedAt,
  Value<Uint8List> raw,
});

class $$StepRecordsTableFilterComposer
    extends Composer<_$WSDatabase, $StepRecordsTable> {
  $$StepRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bucketMinutes => $composableBuilder(
      column: $table.bucketMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get flags => $composableBuilder(
      column: $table.flags, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caloriesDeciKcal => $composableBuilder(
      column: $table.caloriesDeciKcal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnFilters(column));
}

class $$StepRecordsTableOrderingComposer
    extends Composer<_$WSDatabase, $StepRecordsTable> {
  $$StepRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bucketMinutes => $composableBuilder(
      column: $table.bucketMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get flags => $composableBuilder(
      column: $table.flags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caloriesDeciKcal => $composableBuilder(
      column: $table.caloriesDeciKcal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnOrderings(column));
}

class $$StepRecordsTableAnnotationComposer
    extends Composer<_$WSDatabase, $StepRecordsTable> {
  $$StepRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => column);

  GeneratedColumn<int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get bucketMinutes => $composableBuilder(
      column: $table.bucketMinutes, builder: (column) => column);

  GeneratedColumn<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate, builder: (column) => column);

  GeneratedColumn<int> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<int> get caloriesDeciKcal => $composableBuilder(
      column: $table.caloriesDeciKcal, builder: (column) => column);

  GeneratedColumn<int> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);
}

class $$StepRecordsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $StepRecordsTable,
    StepRecord,
    $$StepRecordsTableFilterComposer,
    $$StepRecordsTableOrderingComposer,
    $$StepRecordsTableAnnotationComposer,
    $$StepRecordsTableCreateCompanionBuilder,
    $$StepRecordsTableUpdateCompanionBuilder,
    (StepRecord, BaseReferences<_$WSDatabase, $StepRecordsTable, StepRecord>),
    StepRecord,
    PrefetchHooks Function()> {
  $$StepRecordsTableTableManager(_$WSDatabase db, $StepRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<int> recordTime = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int?> steps = const Value.absent(),
            Value<int> bucketMinutes = const Value.absent(),
            Value<int?> averageHeartRate = const Value.absent(),
            Value<int> flags = const Value.absent(),
            Value<int?> caloriesDeciKcal = const Value.absent(),
            Value<int?> distanceMeters = const Value.absent(),
            Value<int> tzOffsetMinutes = const Value.absent(),
            Value<int> syncedAt = const Value.absent(),
            Value<Uint8List> raw = const Value.absent(),
          }) =>
              StepRecordsCompanion(
            id: id,
            deviceId: deviceId,
            userId: userId,
            recordTime: recordTime,
            mode: mode,
            steps: steps,
            bucketMinutes: bucketMinutes,
            averageHeartRate: averageHeartRate,
            flags: flags,
            caloriesDeciKcal: caloriesDeciKcal,
            distanceMeters: distanceMeters,
            tzOffsetMinutes: tzOffsetMinutes,
            syncedAt: syncedAt,
            raw: raw,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String deviceId,
            required String userId,
            required int recordTime,
            required int mode,
            Value<int?> steps = const Value.absent(),
            required int bucketMinutes,
            Value<int?> averageHeartRate = const Value.absent(),
            required int flags,
            Value<int?> caloriesDeciKcal = const Value.absent(),
            Value<int?> distanceMeters = const Value.absent(),
            required int tzOffsetMinutes,
            required int syncedAt,
            required Uint8List raw,
          }) =>
              StepRecordsCompanion.insert(
            id: id,
            deviceId: deviceId,
            userId: userId,
            recordTime: recordTime,
            mode: mode,
            steps: steps,
            bucketMinutes: bucketMinutes,
            averageHeartRate: averageHeartRate,
            flags: flags,
            caloriesDeciKcal: caloriesDeciKcal,
            distanceMeters: distanceMeters,
            tzOffsetMinutes: tzOffsetMinutes,
            syncedAt: syncedAt,
            raw: raw,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$StepRecordsTable, StepRecord>(table),
                    BaseReferences<_$WSDatabase, $StepRecordsTable, StepRecord>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StepRecordsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $StepRecordsTable,
    StepRecord,
    $$StepRecordsTableFilterComposer,
    $$StepRecordsTableOrderingComposer,
    $$StepRecordsTableAnnotationComposer,
    $$StepRecordsTableCreateCompanionBuilder,
    $$StepRecordsTableUpdateCompanionBuilder,
    (StepRecord, BaseReferences<_$WSDatabase, $StepRecordsTable, StepRecord>),
    StepRecord,
    PrefetchHooks Function()>;
typedef $$HeartRateRecordsTableCreateCompanionBuilder
    = HeartRateRecordsCompanion Function({
  Value<int> id,
  required String deviceId,
  required String userId,
  required int recordTime,
  Value<int?> bpm,
  required int sourceKey,
  required int tzOffsetMinutes,
  required int syncedAt,
  required Uint8List raw,
});
typedef $$HeartRateRecordsTableUpdateCompanionBuilder
    = HeartRateRecordsCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<String> userId,
  Value<int> recordTime,
  Value<int?> bpm,
  Value<int> sourceKey,
  Value<int> tzOffsetMinutes,
  Value<int> syncedAt,
  Value<Uint8List> raw,
});

class $$HeartRateRecordsTableFilterComposer
    extends Composer<_$WSDatabase, $HeartRateRecordsTable> {
  $$HeartRateRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnFilters(column));
}

class $$HeartRateRecordsTableOrderingComposer
    extends Composer<_$WSDatabase, $HeartRateRecordsTable> {
  $$HeartRateRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sourceKey => $composableBuilder(
      column: $table.sourceKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnOrderings(column));
}

class $$HeartRateRecordsTableAnnotationComposer
    extends Composer<_$WSDatabase, $HeartRateRecordsTable> {
  $$HeartRateRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get recordTime => $composableBuilder(
      column: $table.recordTime, builder: (column) => column);

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<int> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
      column: $table.tzOffsetMinutes, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);
}

class $$HeartRateRecordsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $HeartRateRecordsTable,
    HeartRateRecord,
    $$HeartRateRecordsTableFilterComposer,
    $$HeartRateRecordsTableOrderingComposer,
    $$HeartRateRecordsTableAnnotationComposer,
    $$HeartRateRecordsTableCreateCompanionBuilder,
    $$HeartRateRecordsTableUpdateCompanionBuilder,
    (
      HeartRateRecord,
      BaseReferences<_$WSDatabase, $HeartRateRecordsTable, HeartRateRecord>
    ),
    HeartRateRecord,
    PrefetchHooks Function()> {
  $$HeartRateRecordsTableTableManager(
      _$WSDatabase db, $HeartRateRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeartRateRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeartRateRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeartRateRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<int> recordTime = const Value.absent(),
            Value<int?> bpm = const Value.absent(),
            Value<int> sourceKey = const Value.absent(),
            Value<int> tzOffsetMinutes = const Value.absent(),
            Value<int> syncedAt = const Value.absent(),
            Value<Uint8List> raw = const Value.absent(),
          }) =>
              HeartRateRecordsCompanion(
            id: id,
            deviceId: deviceId,
            userId: userId,
            recordTime: recordTime,
            bpm: bpm,
            sourceKey: sourceKey,
            tzOffsetMinutes: tzOffsetMinutes,
            syncedAt: syncedAt,
            raw: raw,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String deviceId,
            required String userId,
            required int recordTime,
            Value<int?> bpm = const Value.absent(),
            required int sourceKey,
            required int tzOffsetMinutes,
            required int syncedAt,
            required Uint8List raw,
          }) =>
              HeartRateRecordsCompanion.insert(
            id: id,
            deviceId: deviceId,
            userId: userId,
            recordTime: recordTime,
            bpm: bpm,
            sourceKey: sourceKey,
            tzOffsetMinutes: tzOffsetMinutes,
            syncedAt: syncedAt,
            raw: raw,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$HeartRateRecordsTable, HeartRateRecord>(table),
                    BaseReferences<_$WSDatabase, $HeartRateRecordsTable,
                        HeartRateRecord>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HeartRateRecordsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $HeartRateRecordsTable,
    HeartRateRecord,
    $$HeartRateRecordsTableFilterComposer,
    $$HeartRateRecordsTableOrderingComposer,
    $$HeartRateRecordsTableAnnotationComposer,
    $$HeartRateRecordsTableCreateCompanionBuilder,
    $$HeartRateRecordsTableUpdateCompanionBuilder,
    (
      HeartRateRecord,
      BaseReferences<_$WSDatabase, $HeartRateRecordsTable, HeartRateRecord>
    ),
    HeartRateRecord,
    PrefetchHooks Function()>;
typedef $$SyncLogsTableCreateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  required String deviceId,
  required String userId,
  required String syncId,
  required int startedAt,
  required int endedAt,
  required String announcedJson,
  required String receivedJson,
  Value<int?> deviceResultCode,
  required String confirmation,
  required String result,
  Value<String?> reason,
});
typedef $$SyncLogsTableUpdateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<String> userId,
  Value<String> syncId,
  Value<int> startedAt,
  Value<int> endedAt,
  Value<String> announcedJson,
  Value<String> receivedJson,
  Value<int?> deviceResultCode,
  Value<String> confirmation,
  Value<String> result,
  Value<String?> reason,
});

class $$SyncLogsTableFilterComposer
    extends Composer<_$WSDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get announcedJson => $composableBuilder(
      column: $table.announcedJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receivedJson => $composableBuilder(
      column: $table.receivedJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deviceResultCode => $composableBuilder(
      column: $table.deviceResultCode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get confirmation => $composableBuilder(
      column: $table.confirmation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$WSDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get announcedJson => $composableBuilder(
      column: $table.announcedJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receivedJson => $composableBuilder(
      column: $table.receivedJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deviceResultCode => $composableBuilder(
      column: $table.deviceResultCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get confirmation => $composableBuilder(
      column: $table.confirmation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result => $composableBuilder(
      column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$WSDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get announcedJson => $composableBuilder(
      column: $table.announcedJson, builder: (column) => column);

  GeneratedColumn<String> get receivedJson => $composableBuilder(
      column: $table.receivedJson, builder: (column) => column);

  GeneratedColumn<int> get deviceResultCode => $composableBuilder(
      column: $table.deviceResultCode, builder: (column) => column);

  GeneratedColumn<String> get confirmation => $composableBuilder(
      column: $table.confirmation, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);
}

class $$SyncLogsTableTableManager extends RootTableManager<
    _$WSDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$WSDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()> {
  $$SyncLogsTableTableManager(_$WSDatabase db, $SyncLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> syncId = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<int> endedAt = const Value.absent(),
            Value<String> announcedJson = const Value.absent(),
            Value<String> receivedJson = const Value.absent(),
            Value<int?> deviceResultCode = const Value.absent(),
            Value<String> confirmation = const Value.absent(),
            Value<String> result = const Value.absent(),
            Value<String?> reason = const Value.absent(),
          }) =>
              SyncLogsCompanion(
            id: id,
            deviceId: deviceId,
            userId: userId,
            syncId: syncId,
            startedAt: startedAt,
            endedAt: endedAt,
            announcedJson: announcedJson,
            receivedJson: receivedJson,
            deviceResultCode: deviceResultCode,
            confirmation: confirmation,
            result: result,
            reason: reason,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String deviceId,
            required String userId,
            required String syncId,
            required int startedAt,
            required int endedAt,
            required String announcedJson,
            required String receivedJson,
            Value<int?> deviceResultCode = const Value.absent(),
            required String confirmation,
            required String result,
            Value<String?> reason = const Value.absent(),
          }) =>
              SyncLogsCompanion.insert(
            id: id,
            deviceId: deviceId,
            userId: userId,
            syncId: syncId,
            startedAt: startedAt,
            endedAt: endedAt,
            announcedJson: announcedJson,
            receivedJson: receivedJson,
            deviceResultCode: deviceResultCode,
            confirmation: confirmation,
            result: result,
            reason: reason,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncLogsTable, SyncLog>(table),
                    BaseReferences<_$WSDatabase, $SyncLogsTable, SyncLog>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncLogsTableProcessedTableManager = ProcessedTableManager<
    _$WSDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$WSDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()>;

class $WSDatabaseManager {
  final _$WSDatabase _db;
  $WSDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$StepRecordsTableTableManager get stepRecords =>
      $$StepRecordsTableTableManager(_db, _db.stepRecords);
  $$HeartRateRecordsTableTableManager get heartRateRecords =>
      $$HeartRateRecordsTableTableManager(_db, _db.heartRateRecords);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
}
