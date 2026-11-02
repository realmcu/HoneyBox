import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_sdk/src/connection/environment.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/simulation/sim_watch_device.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/src/features/settings.dart';
import 'package:ws_watch_sdk/src/transport/connection_factory.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_02_settings.dart';
import 'package:ws_watch_sdk/src/session/session.dart';

const config = WSConfig(
    simulationEnabled: true,
    session: WSSessionConfig(replyTimeout: Duration(milliseconds: 100)));
void main() {
  late SimWatchState device;
  late WSDriftDeviceStore store;
  late WSWatch watch;
  late List<WSFrameEvent> frames;
  setUp(() {
    device = SimWatchState()..confirmationDelay = Duration.zero;
    store = WSDriftDeviceStore(WSDatabase(NativeDatabase.memory()));
    frames = [];
    watch = runZoned(() => WSWatch(config: config), zoneValues: {
      wsEnvironmentZoneKey: WSConnectionEnvironment(
          openTransport: (_, c) =>
              WSConnectionEnvironment.openSimulator(c, device),
          openStore: (_) async => store,
          now: () => DateTime(2026, 10, 10, 16, 52))
    });
    watch.debug.frames.listen(frames.add);
  });
  tearDown(() async {
    await watch.dispose();
    await store.close();
  });
  List<WSFrameEvent> displayWrites() => frames
      .where((f) =>
          f.direction == WSFrameDirection.tx &&
          f.kind == WSFrameKind.data &&
          f.keys.any((k) => k.address.key == 4 && k.address.settingOpcode == 0))
      .toList();

  test('not-ready APIs fail immediately and settings facade remains stable',
      () async {
    final settings = watch.settings;
    expect(watch.settings, same(settings));
    for (final call in <Future<dynamic> Function()>[
      settings.setTime,
      settings.getLanguage,
      settings.getDisplayFormat,
      () => settings.setLanguage(WSLanguage.english),
      () => settings.setDisplayFormat(WSDisplayFormat()),
      () => settings.setHourSystem(WSHourSystem.twelveHour),
      () => settings.setDistanceUnit(WSDistanceUnit.imperial),
    ]) {
      await expectLater(call(), throwsA(isA<WSNotReadyException>()));
    }
    expect(frames, isEmpty);
    await watch.dispose();
    await expectLater(
        settings.getLanguage(), throwsA(isA<WSDisposedException>()));
  });
  test('language and time round trip, notifications update observed values',
      () async {
    final settings = watch.settings;
    await watch.connect(kWsWatchSimDeviceId);
    expect(settings.languageSupport, WSFeatureSupport.unknown);
    expect(settings.displayFormatSupport, WSFeatureSupport.unknown);
    await settings.setLanguage(WSLanguage(255));
    expect(await settings.getLanguage(), WSLanguage(255));
    expect(settings.observed.language, WSLanguage(255));
    await settings.setTime();
    expect(device.timeBytes, [0x6a, 0xca, 0x6d, 0x30]);
    await Future<void>.delayed(Duration.zero);
    expect(settings.observed.time,
        WSWallClock(year: 2026, month: 10, day: 10, hour: 16, minute: 52));
  });
  test('ACK alone does not optimistically change observed settings', () async {
    device.emitSettingsNotifications = false;
    final settings = watch.settings;
    await watch.connect(kWsWatchSimDeviceId);
    await settings.setLanguage(WSLanguage.english);
    await settings
        .setDisplayFormat(WSDisplayFormat(hourSystem: WSHourSystem.twelveHour));
    await settings.setTime();
    expect(settings.observed.language, isNull);
    expect(settings.observed.displayFormat, isNull);
    expect(settings.observed.time, isNull);
    expect(await settings.getLanguage(), WSLanguage.english);
    expect((await settings.getDisplayFormat()).hourSystem,
        WSHourSystem.twelveHour);
  });
  test(
      'whole format, concurrent convenience setters and unknown field preservation',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    await watch.settings
        .setDisplayFormat(WSDisplayFormat.fromBytes([0, 0xfe, 0, 0xfd]));
    frames.clear();
    await Future.wait([
      watch.settings.setHourSystem(WSHourSystem.twelveHour),
      watch.settings.setDistanceUnit(WSDistanceUnit.imperial),
    ]);
    expect((await watch.settings.getDisplayFormat()).raw, [1, 0xfe, 1, 0xfd]);
    expect(displayWrites(), hasLength(2));
    final requests = frames
        .where((f) =>
            f.direction == WSFrameDirection.tx && f.kind == WSFrameKind.data)
        .expand((f) => f.keys)
        .where((k) => k.address.key == 4)
        .map((k) => k.address.settingOpcode)
        .toList();
    expect(requests, [1, 0, 1, 0, 1]);
    expect(await watch.settings.getHourSystem(), WSHourSystem.twelveHour);
    expect(await watch.settings.getDistanceUnit(), WSDistanceUnit.imperial);
  });
  test('Raw and full setter cannot interleave with a compound setter',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    device.displayReplyDelay = const Duration(milliseconds: 20);
    frames.clear();
    final first = watch.settings.setHourSystem(WSHourSystem.twelveHour);
    final raw = watch.debug.sendRaw(WSRawRequest(
        cmd: 2, version: 0, key: 4, settingOpcode: 0, data: [0, 1, 0, 1]));
    final whole = watch.settings
        .setDisplayFormat(WSDisplayFormat.fromBytes([1, 1, 1, 1]));
    await Future.wait([first, raw, whole]);
    final requests = frames
        .where((f) =>
            f.direction == WSFrameDirection.tx && f.kind == WSFrameKind.data)
        .expand((f) => f.keys)
        .where((k) => k.address.key == 4)
        .map((k) => k.address.settingOpcode)
        .toList();
    expect(requests, [1, 0, 0, 0]);
    expect(device.displayFormat, [1, 1, 1, 1]);
  });
  test(
      'read notification cannot complete a query or supply a convenience write',
      () async {
    await watch.connect(kWsWatchSimDeviceId);
    device.displayFormat = Uint8List.fromList([0, 1, 0, 1]);
    device.notifyBeforeDisplayReply = Uint8List.fromList([0, 9, 0, 9]);
    device.displayReplyDelay = const Duration(milliseconds: 25);
    await watch.settings.setHourSystem(WSHourSystem.twelveHour);
    expect(device.displayFormat, [1, 1, 0, 1]);
  });
  for (final malformed in [false, true]) {
    test('failed read ($malformed) never sends a write', () async {
      await watch.connect(kWsWatchSimDeviceId);
      frames.clear();
      if (malformed) {
        device.displayReplyOverride = Uint8List.fromList([0, 1]);
      } else {
        device.suppressDisplayReplies = true;
      }
      await expectLater(watch.settings.setHourSystem(WSHourSystem.twelveHour),
          throwsA(isA<WSException>()));
      expect(displayWrites(), isEmpty);
    });
  }
  test('dispose cancels compound and queued settings, and closes observations',
      () async {
    final settings = watch.settings;
    await watch.connect(kWsWatchSimDeviceId);
    device.displayReplyDelay = const Duration(milliseconds: 60);
    final started = watch.debug.frames.firstWhere((f) =>
        f.direction == WSFrameDirection.tx &&
        f.kind == WSFrameKind.data &&
        f.keys.any((k) => k.address.key == 4));
    final pending = expectLater(settings.setHourSystem(WSHourSystem.twelveHour),
        throwsA(isA<WSException>()));
    final queued = expectLater(
        settings.setDistanceUnit(WSDistanceUnit.imperial),
        throwsA(isA<WSException>()));
    var changesDone = false;
    final sub =
        settings.changes.listen((_) {}, onDone: () => changesDone = true);
    await started;
    await watch.dispose();
    await pending;
    await queued;
    expect(changesDone, isTrue);
    expect(settings.observed.displayFormat, isNull);
    expect(device.displayFormat, [0, 0, 0, 0]);
    await sub.cancel();
  });

  test('explicit unsupported capability rejects before any wire traffic',
      () async {
    final harness = await WSPreparedSimulation.open(config: config);
    final controller = WSSettingsController(
      requireSession: () => harness.session,
      support: (_) => WSFeatureSupport.unsupported,
      now: DateTime.now,
      states: const Stream<WSConnectionChange>.empty(),
    );
    final seen = <WSFrameEvent>[];
    final sub = harness.debug.frames.listen(seen.add);
    try {
      await expectLater(
          controller.getLanguage(), throwsA(isA<WSUnsupportedException>()));
      await expectLater(controller.setDisplayFormat(WSDisplayFormat()),
          throwsA(isA<WSUnsupportedException>()));
      expect(seen, isEmpty);
    } finally {
      await sub.cancel();
      await controller.dispose();
      await harness.dispose();
    }
  });

  test('compound executor expires after callback and cannot bypass the queue',
      () async {
    final harness = await WSPreparedSimulation.open(config: config);
    WSSessionTransaction? expired;
    try {
      await harness.session.transaction((tx) async {
        expired = tx;
        expect(await tx.query(WSSettingsProtocol.getLanguage, null), 1);
      });
      await expectLater(expired!.query(WSSettingsProtocol.getLanguage, null),
          throwsA(isA<WSSessionInvalidatedException>()));
      expect(
          await harness.session.query(WSSettingsProtocol.getLanguage, null), 1);
    } finally {
      await harness.dispose();
    }
  });

  test('disconnect invalidates queued operations and clears observed snapshot',
      () async {
    final settings = watch.settings;
    await watch.connect(kWsWatchSimDeviceId);
    await settings.getDisplayFormat();
    device.displayReplyDelay = const Duration(milliseconds: 60);
    final queuedRead = watch.debug.frames.firstWhere((f) =>
        f.direction == WSFrameDirection.tx &&
        f.kind == WSFrameKind.data &&
        f.keys.any((k) => k.address.key == 4 && k.address.settingOpcode == 1));
    final pending = expectLater(settings.setHourSystem(WSHourSystem.twelveHour),
        throwsA(isA<WSException>()));
    final later = expectLater(settings.setDistanceUnit(WSDistanceUnit.imperial),
        throwsA(isA<WSException>()));
    await queuedRead;
    await watch.disconnect();
    await pending;
    await later;
    await Future<void>.delayed(Duration.zero);
    expect(settings.observed.displayFormat, isNull);
    device.displayReplyDelay = Duration.zero;
    await watch.connect(kWsWatchSimDeviceId);
    expect((await settings.getDisplayFormat()).raw, [0, 0, 0, 0]);
  });
}
