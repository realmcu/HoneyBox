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

abstract class _$WSDatabase extends GeneratedDatabase {
  _$WSDatabase(QueryExecutor e) : super(e);
  $WSDatabaseManager get managers => $WSDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [devices];
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

class $WSDatabaseManager {
  final _$WSDatabase _db;
  $WSDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
}
