// Separate Windows debug acceptance target. Never imported by production main.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show ScanResult;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../app_info.dart';
import '../pages/launcher/app_catalog.dart' show AppId;
import '../pages/watch/health/jw_health_page.dart';
import '../pages/watch/watch_app_root.dart';
import '../providers/ble_provider.dart';
import '../providers/current_app_provider.dart';
import '../providers/jw_device_provider.dart';
import '../services/ble_manager.dart' as manager;
import '../services/jw/health/jw_health_goals.dart';
import '../services/jw/health/jw_health_models.dart';
import '../services/jw/health/jw_health_repository.dart';
import '../services/jw/history/jw_history_decoder.dart';
import '../services/jw/history/jw_history_models.dart';
import '../services/jw/history/jw_history_store.dart';
import '../services/jw/jw_codec.dart';
import '../services/jw/jw_device_repository.dart';
import '../services/jw/jw_identity_store.dart';
import '../services/jw/jw_models.dart';
import '../services/jw/jw_session.dart';
import '../services/jw/jw_transport.dart';
import '../theme/app_theme.dart';

const jwHealthFixtureMarker = 'JW_HEALTH_UI_SIMULATED_ONLY';
const jwHealthFixtureDeviceId = 'JW-HEALTH-SIMULATED-PLATFORM';
const jwHealthFixtureName = 'SIMULATED S200 - health acceptance';
const jwHealthFixtureHistoryKey = 'jw:JW-HEALTH-SIMULATED-SERIAL';

class JwHealthAcceptanceOptions {
  final String mode;
  final Directory output;
  final Directory? fixtureData;
  JwHealthAcceptanceOptions._(this.mode, this.output, this.fixtureData);
  static JwHealthAcceptanceOptions parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      final equal = argument.indexOf('=');
      if (equal < 0) throw ArgumentError('Expected named acceptance arguments');
      final key = argument.substring(0, equal);
      if (![
            '--jw-health-mode',
            '--jw-health-output',
            '--jw-health-fixture-data'
          ].contains(key) ||
          values.containsKey(key)) {
        throw ArgumentError('Unknown or repeated acceptance argument');
      }
      values[key] = argument.substring(equal + 1);
    }
    final mode = values['--jw-health-mode'];
    if (mode != 'real' && mode != 'fixture') {
      throw ArgumentError('Explicit --jw-health-mode=real|fixture required');
    }
    Directory directory(String? value) {
      if (value == null ||
          !Directory(value).isAbsolute ||
          Directory(value)
                  .uri
                  .normalizePath()
                  .pathSegments
                  .where((part) => part.isNotEmpty)
                  .length <=
              (Platform.isWindows ? 1 : 0)) {
        throw ArgumentError('Absolute non-root acceptance directory required');
      }
      return Directory(value);
    }

    final output = directory(values['--jw-health-output']);
    final data = values['--jw-health-fixture-data'];
    if (mode == 'real' && data != null) {
      throw ArgumentError('Fixture data is invalid in real mode');
    }
    return JwHealthAcceptanceOptions._(
        mode!,
        output,
        mode == 'fixture'
            ? directory(data ?? '${output.path}/fixture-data')
            : null);
  }
}

class _FixtureAudit {
  final File file;
  _FixtureAudit(Directory output)
      : file = File('${output.path}/simulated-events.jsonl');
  void record(String event, [Map<String, Object?> detail = const {}]) {
    file.writeAsStringSync(
        '${jsonEncode({
              'kind': jwHealthFixtureMarker,
              'utc': DateTime.now().toUtc().toIso8601String(),
              'event': event,
              ...detail,
            })}\n',
        mode: FileMode.append,
        flush: true);
  }
}

class _FixtureHistoryStore extends FileJwHistoryStore {
  final Duration commitDelay;
  final _FixtureAudit audit;
  bool seeded = false;
  int durableCommits = 0;
  _FixtureHistoryStore(super.root, this.audit, this.commitDelay);
  @override
  Future<void> commit(JwHistoryBatchCommit batch) async {
    if (seeded) {
      audit.record('durableCommitPending', {
        'batchId': batch.batchId,
        'recordIds': batch.recordIds,
        'delayMs': commitDelay.inMilliseconds
      });
      await Future<void>.delayed(commitDelay);
    }
    await super.commit(batch);
    if (seeded) {
      durableCommits++;
      audit.record('durableCommitComplete',
          {'batchId': batch.batchId, 'recordIds': batch.recordIds});
    }
  }
}

class JwHealthAcceptanceFixture {
  final Directory output, data;
  final _FixtureHistoryStore _store;
  FileJwHistoryStore get store => _store;
  final JwHealthGoalStore goals;
  final _FixtureManager _bleManager;
  final _FixtureAudit _audit;
  final _repositories = <JwDeviceRepository>[];
  JwHealthAcceptanceFixture._(this.output, this.data, this._store, this.goals,
      this._bleManager, this._audit);
  static Future<JwHealthAcceptanceFixture> open(Directory output,
      {required Directory data,
      Duration commitDelay = const Duration(seconds: 6)}) async {
    await output.create(recursive: true);
    final marker = File('${data.path}/fixture-owner.json');
    if (await data.exists()) {
      if (await marker.exists()) {
        final owned = jsonDecode(await marker.readAsString());
        if (owned is! Map || owned['kind'] != jwHealthFixtureMarker) {
          throw StateError('Fixture directory ownership mismatch');
        }
      } else if (!await data.list().isEmpty) {
        throw StateError(
            'Refusing to use an unmarked nonempty fixture directory');
      }
    }
    await data.create(recursive: true);
    await marker.writeAsString(jsonEncode({'kind': jwHealthFixtureMarker}),
        flush: true);
    final audit = _FixtureAudit(output);
    final store = _FixtureHistoryStore(
        Directory('${data.path}/history'), audit, commitDelay);
    await store.open();
    try {
      final fixture = JwHealthAcceptanceFixture._(
          output,
          data,
          store,
          JwHealthGoalStore(File('${data.path}/goals.json')),
          _FixtureManager(audit),
          audit);
      await fixture._seed();
      store.seeded = true;
      await fixture._writeManifest();
      audit.record('fixtureReady', {'fixtureData': data.absolute.path});
      return fixture;
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  List<Override> get overrides => [
        bleManagerProvider.overrideWith((ref) => _bleManager),
        jwHistoryStoreProvider.overrideWith((ref) async => store),
        jwHealthGoalStoreProvider.overrideWith((ref) async => goals),
        jwRepositoryProvider.overrideWith((ref) async {
          final connected = ref.watch(connectedDeviceProvider);
          if (connected?.isJw != true) return null;
          final transport = ref.read(bleManagerProvider).jwTransport;
          if (transport == null) {
            throw StateError('Fixture JW transport unavailable');
          }
          final repository = JwDeviceRepository(
              session: JwSession(transport),
              transport: transport,
              identityStore:
                  JwIdentityStore(File('${data.path}/identity.json')),
              platformDeviceKey: connected!.deviceId,
              historyStoreFactory: () =>
                  ref.read(jwHistoryStoreProvider.future),
              ownsHistoryStore: false);
          _repositories.add(repository);
          ref.onDispose(() => unawaited(repository.dispose()));
          _audit.record(
              'repositoryCreated', {'platformDeviceKey': connected.deviceId});
          return repository;
        }),
      ];
  Future<void> close() async {
    for (final repository in _repositories) {
      await repository.dispose();
    }
    await _bleManager.close();
    await store.close();
  }

  Future<void> _seed() async {
    final done = File('${data.path}/seed-complete.json');
    if (await done.exists()) {
      _audit.record('seedRetained');
      return;
    }
    final grouped = _fixtureFields();
    for (final entry in grouped.entries) {
      final batch = '000000-health-seed-${entry.key}';
      final rows = <JwHistoryRecord>[];
      for (final field in entry.value) {
        rows.addAll(decodeJwHistoryField(
            jwHealthFixtureHistoryKey, field.key, field.value,
            batchId: batch, firstSeenOrdinal: rows.length));
      }
      await store.beginBatch(batch, jwHealthFixtureHistoryKey);
      await store.append(batch, rows);
      if (entry.key == '2026-10-02') {
        await store.noteFailure(batch, 'SIMULATED-partial',
            'Validation-only interrupted seed round');
        await store.flush();
      } else {
        await store.commit(JwHistoryBatchCommit(
            batchId: batch,
            deviceKey: jwHealthFixtureHistoryKey,
            recordIds: rows.map((r) => r.recordId)));
      }
    }
    await done.writeAsString(
        jsonEncode({'kind': jwHealthFixtureMarker, 'version': 1}),
        flush: true);
    _audit.record('seedComplete');
  }

  Future<void> _writeManifest() async {
    final repository = JwHealthRepository(store);
    Map<String, Object?> totals(JwHealthTotals t) => {
          'steps': t.steps,
          'distanceMeters': t.distanceMeters,
          'energyKcal': t.energyKcal,
          'sleepMinutes': t.sleepMinutes
        };
    Map<String, Object?> snapshot(JwHealthSnapshot s) => {
          'date': jwHealthDayKey(s.date),
          'start': jwHealthDayKey(s.start),
          'endExclusive': jwHealthDayKey(s.endExclusive),
          'totals': totals(s.totals),
          'days': [
            for (final d in s.days)
              {'date': jwHealthDayKey(d.date), ...totals(d.totals)}
          ],
          'metrics': {
            for (final e in s.metrics.entries)
              e.key.name: {
                'count': e.value.samples.length,
                'mean': e.value.average,
                'min': e.value.minimum,
                'max': e.value.maximum,
                'samples': [
                  for (final p in e.value.samples)
                    {
                      'time': p.time.toIso8601String(),
                      'value': p.value,
                      'secondaryValue': p.secondaryValue,
                      'recordId': p.recordId
                    }
                ]
              }
          },
          'sleep': [
            for (final p in s.sleepSegments)
              {
                'stage': p.stage.name,
                'start': p.start.toIso8601String(),
                'end': p.end.toIso8601String(),
                'minutes': p.minutes
              }
          ],
          'sport': [for (final row in s.sportRecords) row.toJson()],
          'partialRecordIds': s.coverage.partialRecordIds.toList(),
          'issues': s.coverage.issues.toList(),
        };
    final day = await repository.load(
        deviceKey: jwHealthFixtureHistoryKey,
        date: DateTime.utc(2026, 10, 5),
        period: JwHealthPeriod.day);
    final week = await repository.load(
        deviceKey: jwHealthFixtureHistoryKey,
        date: DateTime.utc(2026, 10, 5),
        period: JwHealthPeriod.week);
    final inventory = await store.inventory(jwHealthFixtureHistoryKey);
    await File('${output.path}/seed-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'kind': jwHealthFixtureMarker,
          'fixtureData': data.absolute.path,
          'deviceKey': jwHealthFixtureHistoryKey,
          'selectedDate': '2026-10-05',
          'noDataDate': '2026-10-01',
          'validZeroDate': '2026-09-30',
          'partialDate': '2026-10-02',
          'goalsAtLaunch':
              (await goals.read(jwHealthFixtureHistoryKey)).toJson(),
          'freshSeedDay': {
            'steps': 1234,
            'distanceMeters': 890,
            'energyKcal': 123.45,
            'sleepMinutes': 150
          },
          'syncAfterDay': {
            'steps': 2234,
            'distanceMeters': 990,
            'energyKcal': 223.45,
            'sleepMinutes': 150
          },
          'freshSeedWeekSteps': 11234,
          'syncAfterWeekSteps': 12234,
          'currentDay': snapshot(day),
          'currentWeek': snapshot(week),
          'recordIds': inventory.recordIds,
          'counts': inventory.counts,
          'syncCommitDelayMs': _store.commitDelay.inMilliseconds,
        }),
        flush: true);
  }
}

// These are real firmware layouts decoded by the unchanged product decoder.
// No hand-made health snapshots are injected into providers.
Uint8List _calendar(int length, DateTime date) {
  final raw = Uint8List(length);
  final bytes = ByteData.sublistView(raw);
  bytes.setUint16(0, ((date.year - 2000) << 9) | (date.month << 5) | date.day);
  bytes.setUint16(2, 1);
  return raw;
}

void _word(Uint8List raw, int offset, BigInt value) {
  for (var i = 7; i >= 0; i--) {
    raw[offset + i] = (value & BigInt.from(255)).toInt();
    value >>= 8;
  }
}

Uint8List _step(DateTime date, int steps, int distance, int calories) {
  final raw = _calendar(12, date);
  _word(
      raw,
      4,
      (BigInt.from(48) << 53) |
          (BigInt.from(steps) << 39) |
          (BigInt.from(calories) << 16) |
          BigInt.from(distance));
  return raw;
}

Uint8List _sleep(DateTime date, int minute, int mode) {
  final raw = _calendar(8, date);
  ByteData.sublistView(raw).setUint32(4, (minute << 16) | mode);
  return raw;
}

Uint8List _heart(DateTime date, int minute, int bpm, int temperatureTenths) {
  final raw = _calendar(12, date);
  _word(
      raw,
      4,
      (BigInt.one << 48) |
          (BigInt.from(temperatureTenths) << 32) |
          (BigInt.from(minute) << 16) |
          BigInt.from(bpm));
  return raw;
}

Map<String, List<JwField>> _fixtureFields() {
  final day = DateTime.utc(2026, 10, 5);
  final bp = <Uint8List>[];
  for (var i = 0; i < 2; i++) {
    final raw = _calendar(12, day);
    _word(
        raw,
        4,
        (BigInt.from(300 + 900 * i) << 32) |
            (BigInt.from(72) << 16) |
            (BigInt.from(80 + 2 * i) << 8) |
            BigInt.from(120 + 4 * i));
    bp.add(raw);
  }
  final oxygen = Uint8List(8);
  _word(
      oxygen,
      0,
      (BigInt.from(26) << 57) |
          (BigInt.from(10) << 53) |
          (BigInt.from(5) << 48) |
          (BigInt.from(300) << 32) |
          (BigInt.from(97) << 16) |
          (BigInt.from(98) << 8) |
          BigInt.from(96));
  final local = day
      .add(const Duration(hours: 5))
      .difference(DateTime.utc(2000))
      .inSeconds;
  final hrv = Uint8List(8)..[0] = 1;
  ByteData.sublistView(hrv).setUint32(1, local + 946656000);
  hrv[5] = 42;
  final pressure = Uint8List(8)..[4] = 6;
  ByteData.sublistView(pressure).setUint32(0, local, Endian.little);
  final sport = _calendar(32, day)..[8] = 1;
  final bytes = ByteData.sublistView(sport);
  bytes.setUint16(5, 600);
  bytes.setUint16(9, 30);
  sport[11] = 5;
  bytes.setUint32(16, 100);
  bytes.setUint32(20, 500);
  bytes.setUint32(24, 2500);
  sport[28] = 90;
  sport[29] = 72;
  sport[30] = 60;
  return {
    '2026-09-29': [
      JwField(2, _step(DateTime.utc(2026, 9, 29), 1000, 700, 25000))
    ],
    '2026-09-30': [JwField(2, _step(DateTime.utc(2026, 9, 30), 0, 0, 0))],
    // October 1 intentionally has no saved records.
    '2026-10-02': [
      JwField(2, _step(DateTime.utc(2026, 10, 2), 2000, 1400, 50000)),
      JwField(0x29, _heart(DateTime.utc(2026, 10, 2), 300, 68, 310))
    ],
    '2026-10-03': [
      JwField(2, _step(DateTime.utc(2026, 10, 3), 3000, 2100, 75000))
    ],
    '2026-10-04': [
      JwField(2, _step(DateTime.utc(2026, 10, 4), 4000, 2800, 100000)),
      JwField(3, _sleep(DateTime.utc(2026, 10, 4), 1380, 1))
    ],
    '2026-10-05': [
      JwField(2, _step(day, 1234, 890, 123450)),
      JwField(
          0x29,
          Uint8List.fromList(
              [..._heart(day, 60, 70, 312), ..._heart(day, 1380, 74, 322)])),
      JwField(
          3,
          Uint8List.fromList([
            for (final (minute, mode) in [
              (60, 2),
              (120, 4),
              (150, 3),
              (180, 0)
            ])
              ..._sleep(day, minute, mode)
          ])),
      JwField(0x13, Uint8List.fromList(bp.expand((r) => r).toList())),
      JwField(0x2c, oxygen),
      JwField(0x3c, hrv),
      JwField(0x5b, pressure),
      JwField(0x16, sport)
    ],
  };
}

class _FixtureManager implements manager.BleManager {
  final _FixtureAudit audit;
  final _state = StreamController<manager.BleState>.broadcast(sync: true);
  final _transports = <_FixtureTransport>[];
  _FixtureTransport? _current;
  manager.BleState _status = manager.BleState.disconnected;
  bool _disposed = false;
  _FixtureManager(this.audit);
  void _publish(manager.BleState value) {
    _status = value;
    if (!_state.isClosed) _state.add(value);
  }

  @override
  Stream<manager.BleState> get onStateChanged => _state.stream;
  @override
  manager.BleState get state => _status;
  @override
  int get mtu => 247;
  @override
  String? get deviceId => _current == null ? null : jwHealthFixtureDeviceId;
  @override
  String? get deviceName => _current == null ? null : jwHealthFixtureName;
  @override
  JwTransport? get jwTransport => _current;
  @override
  Future<bool> connect(String deviceId, String deviceName,
      {bool allowJw = false}) async {
    if (_disposed || deviceId != jwHealthFixtureDeviceId || !allowJw) {
      return false;
    }
    await disconnect();
    _publish(manager.BleState.connecting);
    late _FixtureTransport transport;
    transport = _FixtureTransport(audit, () {
      if (identical(_current, transport)) {
        _current = null;
        _publish(manager.BleState.disconnected);
      }
    });
    _transports.add(transport);
    _current = transport;
    _publish(manager.BleState.connected);
    audit.record('managerConnected', {'deviceId': deviceId});
    return true;
  }

  @override
  Future<void> disconnect() async {
    final port = _current;
    if (port != null) {
      _publish(manager.BleState.disconnecting);
      await port.disconnect();
      audit.record('managerDisconnected');
    }
  }

  @override
  Future<void> startScan(void Function(ScanResult) callback,
      {String? serviceUuid}) async {
    if (_current == null) _publish(manager.BleState.scanning);
  }

  @override
  void stopScan() {
    if (_status == manager.BleState.scanning) {
      _publish(manager.BleState.disconnected);
    }
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    for (final transport in _transports) {
      await transport.close();
    }
    await _state.close();
  }

  @override
  void dispose() => unawaited(close());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureTransport implements JwTransport {
  final _FixtureAudit audit;
  final void Function() onDisconnect;
  final _rx = StreamController<Uint8List>.broadcast(sync: true);
  final _down = StreamController<void>.broadcast(sync: true);
  int _sequence = 0;
  bool _subscribed = false, _disconnected = false;
  _FixtureTransport(this.audit, this.onDisconnect);
  @override
  int get mtu => 247;
  @override
  Stream<Uint8List> get notifications => _rx.stream;
  @override
  Stream<void> get disconnected => _down.stream;
  @override
  Future<void> subscribe() async {
    if (_disconnected) throw StateError('Simulated transport disconnected');
    _subscribed = true;
  }

  @override
  Future<void> disconnect() async {
    if (_disconnected) return;
    _disconnected = true;
    _subscribed = false;
    _down.add(null);
    onDisconnect();
  }

  Future<void> close() async {
    await disconnect();
    await _rx.close();
    await _down.close();
  }

  @override
  Future<Uint8List?> read(String uuid) async {
    audit.record('gattRead', {'uuid': uuid});
    if (uuid == '2a19') return Uint8List.fromList([70]);
    final value = {
      '2a00': jwHealthFixtureName,
      '2a25': 'JW-HEALTH-SIMULATED-SERIAL',
      '2a26': 'T005',
      '2a27': 'H001'
    }[uuid];
    return value == null ? null : Uint8List.fromList(utf8.encode(value));
  }

  void _reply(int command, int key, Uint8List value, {bool noAck = false}) {
    _rx.add(JwCodec.encode(
        seq: ++_sequence,
        noAck: noAck,
        payload: JwCodec.encodeL2(command, [JwField(key, value)])));
  }

  @override
  Future<void> write(Uint8List bytes, {required bool withResponse}) async {
    if (!_subscribed || _disconnected || !withResponse) {
      throw StateError('Simulated transport unavailable');
    }
    final frame = JwFrameDecoder().add(bytes).single;
    if (frame.ack) {
      audit.record('appL1Ack', {'sequence': frame.seq});
      return;
    }
    final message = JwCodec.decodeL2(frame.payload);
    final field = message.fields.single;
    audit.record('appCommand', {
      'command': message.command,
      'key': field.key,
      'value': field.value.toList()
    });
    _rx.add(JwCodec.encode(seq: frame.seq, payload: Uint8List(0), ack: true));
    if (message.command == 2 && field.key == 0x36) {
      // Saved metrics still render with unknown/unsupported live capabilities.
      _reply(2, 0x37, Uint8List(8));
    } else if (message.command == 6 && field.key == 0x3d) {
      _reply(6, 0x3e, Uint8List.fromList([3]));
    } else if (message.command == 3 && field.key == 3) {
      _reply(3, 4, Uint8List.fromList([0]));
    } else if (message.command == 5 && field.key == 1) {
      audit.record('freshSyncStarted');
      _reply(
          5,
          7,
          Uint8List.fromList([
            for (var i = 0; i < 6; i++) ...[i, 0, i == 0 ? 1 : 0]
          ]),
          noAck: true);
      _reply(5, 2, _step(DateTime.utc(2026, 10, 5), 2234, 990, 223450),
          noAck: true);
      _reply(5, 8, Uint8List(0), noAck: true);
    } else if (message.command == 5 && field.key == 0x1c) {
      audit.record('applicationHistoryConfirmation');
    } else {
      // Explicitly fail unknown simulated commands; never contact physical BLE.
      throw UnsupportedError(
          'Unscripted simulated command ${message.command}/${field.key}');
    }
  }
}

// Observer caches already-published state. Capture never initializes a provider,
// runs a callback, or waits behind the store's mutation queue.
class JwHealthAcceptanceObserver extends ProviderObserver {
  final _values = <ProviderBase<Object?>, Object?>{};
  @override
  void didAddProvider(ProviderBase<Object?> provider, Object? value,
      ProviderContainer container) {
    _values[provider] = value;
  }

  @override
  void didUpdateProvider(ProviderBase<Object?> provider, Object? previousValue,
      Object? newValue, ProviderContainer container) {
    _values[provider] = newValue;
  }

  @override
  void didDisposeProvider(
      ProviderBase<Object?> provider, ProviderContainer container) {
    _values.remove(provider);
  }

  Map<String, Object?> snapshot() {
    final connected = _values[connectedDeviceProvider] as ConnectedDeviceInfo?;
    final device = _values[jwDeviceProvider] as JwDeviceState?;
    final asyncRepo = _values[jwRepositoryProvider];
    final repository =
        asyncRepo is AsyncValue<JwDeviceRepository?> && !asyncRepo.isLoading
            ? asyncRepo.valueOrNull
            : null;
    return {
      'bleState': (_values[bleNotifierProvider] as BleState?)?.name,
      'connectedDeviceId': connected?.deviceId,
      'connectedIsJw': connected?.isJw,
      'repositoryHistoryKey': repository?.historyDeviceKey,
      'repositoryPhase': repository?.state.phase.name,
      'phase': device?.phase.name,
      'operationInProgress': device?.operationInProgress,
      'operationError': device?.operationError,
      'historyProgress': device?.historyProgress?.toJson(),
      'lastHistoryResult': device?.lastHistoryResult?.toJson(),
    };
  }
}

List<Map<String, Object?>> jwHealthUiGeometry(BuildContext context) {
  final geometry = <Map<String, Object?>>[];
  final view = View.of(context);
  final bounds = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  void inspect(Element element) {
    final widget = element.widget;
    if (widget is Offstage && widget.offstage ||
        widget is Visibility && !widget.visible) {
      return;
    }
    if (widget.key != null ||
        widget is Text ||
        widget is AppBar ||
        widget is IconButton ||
        widget is Tooltip ||
        widget is BackButton) {
      final render = element.findRenderObject();
      if (render is RenderBox &&
          render.hasSize &&
          render.attached &&
          render.size.width > 0 &&
          render.size.height > 0) {
        final point = render.localToGlobal(Offset.zero);
        if (point.dx.isFinite &&
            point.dy.isFinite &&
            render.size.width.isFinite &&
            render.size.height.isFinite) {
          var rect = point & render.size;
          for (RenderObject? parent = render.parent;
              parent != null;
              parent = parent.parent) {
            if (parent is RenderViewportBase && parent.hasSize) {
              rect = rect
                  .intersect(parent.localToGlobal(Offset.zero) & parent.size);
            }
          }
          final visible =
              rect.overlaps(bounds) && rect.width > 0 && rect.height > 0;
          String? tooltip;
          if (widget is Tooltip) tooltip = widget.message;
          if (widget is IconButton) tooltip = widget.tooltip;
          if (widget is BackButton) {
            tooltip = MaterialLocalizations.of(element).backButtonTooltip;
          }
          geometry.add({
            'key': widget.key?.toString(),
            'text': widget is Text
                ? widget.data ?? widget.textSpan?.toPlainText()
                : null,
            'widgetType': widget.runtimeType.toString(),
            'tooltip': tooltip,
            'x': point.dx,
            'y': point.dy,
            'width': render.size.width,
            'height': render.size.height,
            'visible': visible,
          });
        }
      }
    }
    element.visitChildren(inspect);
  }

  (context as Element).visitChildren(inspect);
  return geometry;
}

void _registerCapture(GlobalKey capture, JwHealthAcceptanceObserver observer,
    String mode, JwHealthAcceptanceFixture? fixture) {
  developer.registerExtension('ext.jw.healthUiSnapshot', (_, __) async {
    final context = capture.currentContext;
    final render = context?.findRenderObject();
    if (context == null ||
        render is! RenderRepaintBoundary ||
        !render.hasSize) {
      return developer.ServiceExtensionResponse.result(
          jsonEncode({'error': 'No mounted rendered frame'}));
    }
    final geometry = jwHealthUiGeometry(context);
    final providers = observer.snapshot();
    final devicePixelRatio = View.of(context).devicePixelRatio;
    final logicalSize = render.size;
    final image = await render.toImage(pixelRatio: 1);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return developer.ServiceExtensionResponse.result(jsonEncode({
        'kind': mode == 'fixture'
            ? jwHealthFixtureMarker
            : 'actual Windows Flutter rendered UI; ordinary HoneyBoxApp/providers',
        'mode': mode,
        'pngBase64': base64Encode(png!.buffer.asUint8List()),
        'geometry': geometry,
        'providers': providers,
        'devicePixelRatio': devicePixelRatio,
        'logicalWidth': logicalSize.width,
        'logicalHeight': logicalSize.height,
        if (fixture != null)
          'fixture': {
            'deviceKey': jwHealthFixtureHistoryKey,
            'durableSyncCommitsThisLaunch': fixture._store.durableCommits
          },
      }));
    } finally {
      image.dispose();
    }
  });
}

class JwHealthFixtureApp extends ConsumerStatefulWidget {
  final GlobalKey capture;
  const JwHealthFixtureApp({super.key, required this.capture});
  @override
  ConsumerState<JwHealthFixtureApp> createState() => _JwHealthFixtureAppState();
}

class _JwHealthFixtureAppState extends ConsumerState<JwHealthFixtureApp> {
  double _scale = 1;
  bool _busy = false;
  Future<void> _connection(bool connect) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ble = ref.read(bleNotifierProvider.notifier);
      if (connect) {
        await ble.connect(jwHealthFixtureDeviceId, jwHealthFixtureName,
            allowJw: true);
      } else {
        await ble.disconnect();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: jwHealthFixtureMarker,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/watch-root',
        routes: {'/watch-root': (_) => const WatchAppRoot()},
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (context) => Scaffold(
                  appBar: AppBar(
                      title: const Text('SIMULATED acceptance launcher')),
                  body: Center(
                      child: FilledButton(
                          key: const Key('jw-health-fixture-open-watch'),
                          onPressed: () {
                            ref.read(currentAppProvider.notifier).state =
                                AppId.watch;
                            Navigator.of(context).push(MaterialPageRoute<void>(
                                settings:
                                    const RouteSettings(name: '/watch-root'),
                                builder: (_) => const WatchAppRoot()));
                          },
                          child: const Text('Open production Watch'))))),
          MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/watch-root'),
              builder: (_) => const WatchAppRoot()),
        ],
        builder: (context, child) => RepaintBoundary(
            key: widget.capture,
            child: Column(children: [
              Material(
                  color: Colors.amber,
                  child: SafeArea(
                      bottom: false,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Column(children: [
                            const Text(
                                'JW_HEALTH_UI_SIMULATED_ONLY - no physical BLE',
                                textScaler: TextScaler.noScaling),
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  key:
                                      const Key('jw-health-fixture-disconnect'),
                                  onPressed:
                                      _busy ? null : () => _connection(false),
                                  child: const Text('Simulated disconnect')),
                              TextButton(
                                  key: const Key('jw-health-fixture-reconnect'),
                                  onPressed:
                                      _busy ? null : () => _connection(true),
                                  child: const Text('Simulated reconnect')),
                              TextButton(
                                  key:
                                      const Key('jw-health-fixture-textscale2'),
                                  onPressed: () => setState(
                                      () => _scale = _scale == 1 ? 2 : 1),
                                  child: Text(
                                      'Text scale ${_scale == 1 ? 2 : 1}')),
                            ]),
                          ])))),
              Expanded(
                  child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(_scale)),
                      child: child!)),
            ])),
      );
}

Future<void> main(List<String> arguments) async {
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Health acceptance requires a Windows debug build');
  }
  final options = JwHealthAcceptanceOptions.parse(arguments);
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.init();
  await options.output.create(recursive: true);
  final capture = GlobalKey();
  final observer = JwHealthAcceptanceObserver();
  JwHealthAcceptanceFixture? fixture;
  if (options.mode == 'fixture') {
    fixture = await JwHealthAcceptanceFixture.open(options.output,
        data: options.fixtureData!);
    final container =
        ProviderContainer(overrides: fixture.overrides, observers: [observer]);
    container.read(currentAppProvider.notifier).state = AppId.watch;
    await container
        .read(bleNotifierProvider.notifier)
        .connect(jwHealthFixtureDeviceId, jwHealthFixtureName, allowJw: true);
    runApp(UncontrolledProviderScope(
        container: container, child: JwHealthFixtureApp(capture: capture)));
  } else {
    runApp(ProviderScope(
        observers: [observer],
        child: RepaintBoundary(key: capture, child: const HoneyBoxApp())));
  }
  _registerCapture(capture, observer, options.mode, fixture);
  await File('${options.output.path}/health-host.json').writeAsString(
      jsonEncode({
        'mode': options.mode,
        'kind': options.mode == 'fixture'
            ? jwHealthFixtureMarker
            : 'ordinary HoneyBoxApp/providers',
        'output': options.output.absolute.path,
        'fixtureData': options.fixtureData?.absolute.path,
        'captureExtension': 'ext.jw.healthUiSnapshot',
        'appVersion': AppInfo.version,
      }),
      flush: true);
}
