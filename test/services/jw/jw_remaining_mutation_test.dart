import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_remaining_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  const contract = JwConfigurationContract.v101S200;
  late FakeJwTransport t;
  late JwDeviceRepository repository;
  dynamic repo;
  final sent = <JwMessage>[];
  var wrist = 1;
  var heat = <int>[0x52, 4, 0x80];
  var alarms = <int>[];
  var longSit = <int>[0, 1, 0, 0, 30, 9, 18, 127];
  var sport = <int>[0, 0, 255];
  var health = <int>[0, 0, 0, 0, 0, 0, 0, 0];
  bool dropMutationAck = false;
  setUp(() {
    wrist = 1;
    heat = [0x52, 4, 0x80];
    alarms = [];
    longSit = [0, 1, 0, 0, 30, 9, 18, 127];
    sport = [0, 0, 255];
    health = [0, 0, 0, 0, 0, 0, 0, 0];
    dropMutationAck = false;
  });
  Future<void> create({String functions = '4dd17dfce34ad83d'}) async {
    final dir = await Directory.systemTemp.createTemp('jw_mutation_');
    t = FakeJwTransport();
    installJwDeviceScript(t, functions: functions);
    final original = t.onWrite!;
    t.onWrite = (bytes) {
      final f = JwFrameDecoder().add(bytes).single;
      if (f.ack) return;
      final m = JwCodec.decodeL2(f.payload);
      final key = m.fields.single.key;
      final value = m.fields.single.value;
      final replies = <String, (int, int, List<int>)>{
        '2/43': (2, 44, [wrist]),
        '2/135': (2, 136, heat),
        '2/3': (2, 4, alarms),
        '2/38': (2, 39, longSit),
        '2/72': (2, 73, [0, 0, 0]),
        '5/58': (5, 59, health),
        '2/59': (5, 23, [15, 61, 107, 254])
      };
      final id = '${m.command}/$key';
      if (replies.containsKey(id)) {
        sent.add(m);
        t.emitAck(f.seq);
        final rep = replies[id]!;
        t.emitMessage(rep.$1, rep.$2, Uint8List.fromList(rep.$3));
        return;
      }
      if ({
        '2/42',
        '2/134',
        '2/2',
        '2/33',
        '7/17',
        '2/16',
        '2/5',
        '2/6',
        '5/13',
        '5/45',
        '5/32',
        '5/20',
        '2/45',
        '2/71',
        '2/117'
      }.contains(id)) {
        sent.add(m);
        if (dropMutationAck) return;
        if (id == '2/42') wrist = value.single;
        if (id == '2/134') heat = value.toList();
        if (id == '2/2') alarms = value.toList();
        if (id == '2/33') longSit = value.toList();
        t.emitAck(f.seq);
        if (id == '5/32') {
          t.emitMessage(5, 33, Uint8List.fromList([value.single]));
        }
        return;
      }
      if (id == '5/92') {
        sent.add(m);
        t.emitAck(f.seq);
        if (value[0] == 1) sport = [0, 1, value[1]];
        if (value[0] == 2) sport = [0, 2, sport[2]];
        if (value[0] == 3) sport = [0, 1, sport[2]];
        if (value[0] == 4) sport = [0, 0, 255];
        t.emitMessage(5, 93, Uint8List.fromList(sport));
        return;
      }
      original(bytes);
    };
    repository = JwDeviceRepository(
        session: JwSession(t,
            ackTimeout: const Duration(milliseconds: 25),
            replyTimeout: const Duration(milliseconds: 50)),
        identityStore: JwIdentityStore(File('${dir.path}/id.json')),
        transport: t);
    repo = repository;
    addTearDown(() async {
      await repository.dispose();
      await t.dispose();
      await dir.delete(recursive: true);
    });
    await repository.initialize();
    sent.clear();
    t.writes.clear();
  }

  List<JwMessage> writes(int cmd, int key) => sent
      .where((m) => m.command == cmd && m.fields.single.key == key)
      .toList();
  test('wrist expected current readback and conflict prevents SET', () async {
    await create();
    final before = await repository.readTurnOverWrist(contract: contract);
    final change = await repo.setTurnOverWrist(false,
        expectedCurrent: before, contract: contract);
    expect(change.observed.savedEnabled, false);
    expect(writes(2, 42).single.fields.single.value, [0]);
    await expectLater(
        repo.setTurnOverWrist(true,
            expectedCurrent: before, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'conflict')));
    expect(writes(2, 42).length, 1);
  });
  test('heat window bounded probe/readback', () async {
    await create();
    final before = await repository.queryHeatStressReminder(contract: contract);
    final target =
        JwHeatStressReminderStatus(Uint8List.fromList([0x54, 4, 0x80]));
    final change = await repo.setHeatStressReminder(target,
        expectedCurrent: before, contract: contract);
    expect(change.observed.raw, target.raw);
  });
  test('camera owns short mode and inverted wire polarity', () async {
    await create();
    await repo.setTakePhotoControl(true, contract: contract);
    await repo.setTakePhotoControl(false, contract: contract);
    expect(writes(7, 17).map((m) => m.fields.single.value.single), [0, 1]);
  });
  test('camera rejects stopping foreign mode zero TX', () async {
    await create();
    await expectLater(
        repo.setTakePhotoControl(false, contract: contract), throwsStateError);
    expect(sent, isEmpty);
  });
  test('IAS absent yields unsupported without fallback JW write', () async {
    await create();
    await expectLater(
        repo.findDevice(true, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'unsupported')));
    expect(sent, isEmpty);
  });
  test('new mutation does not blindly retry lost ACK', () async {
    await create();
    dropMutationAck = true;
    await expectLater(repo.setTakePhotoControl(true, contract: contract),
        throwsA(isA<JwLinkException>()));
    expect(writes(7, 17).length, 1);
  });
  test('read/set long-sit preserves S200 minute bytes and readback', () async {
    await create();
    final before = await repo.readLongSit(contract: contract);
    expect(before.startMinute, 0);
    expect(before.endMinute, 0);
    final requested = before.withEnabled(false);
    final change = await repo.setLongSit(requested,
        expectedCurrent: before, contract: contract);
    expect(change.observed.enabled, false);
    expect(
        writes(2, 33).single.fields.single.value, [0, 0, 0, 0, 30, 9, 18, 127]);
  });
  test('long-sit rejects JS invalid minute208', () async {
    await create();
    longSit = [0, 1, 7, 208, 30, 9, 18, 127];
    await expectLater(
        repo.readLongSit(contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'invalid')));
  });
  test('alarm CRUD preserves unrelated raw records and restores', () async {
    await create();
    final original = await repository.readAlarm(contract: contract);
    final record = JwAlarmRecord([0x69, 0x42, 0x70, 8, 127]);
    final added = await repo.addAlarm(record,
        expectedCurrent: original, contract: contract);
    expect(added.observed.records.length, 1);
    final changed = await repo.modifyAlarm(
        0, JwAlarmRecord([0x69, 0x42, 0x80, 8, 127]),
        expectedCurrent: added.observed, contract: contract);
    final deleted = await repo.deleteAlarm(0,
        expectedCurrent: changed.observed, contract: contract);
    expect(deleted.observed.raw, isEmpty);
    expect(writes(2, 2).length, 3);
  });
  test(
      'review retained one-shot record not round-trippable blocks unrelated whole-table write',
      () async {
    await create();
    alarms = [0x69, 0x42, 0x70, 0x38, 0];
    final before = await repository.readAlarm(contract: contract);
    await expectLater(
        repo.addAlarm(JwAlarmRecord([0x69, 0x42, 0x80, 0x38, 127]),
            expectedCurrent: before, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'unsupported')));
    expect(writes(2, 2), isEmpty);
    expect(alarms, before.raw);
  });
  test('alarm optimistic conflict prevents whole table overwrite', () async {
    await create();
    final before = await repository.readAlarm(contract: contract);
    alarms = [0x69, 0x42, 0x70, 8, 127];
    await expectLater(
        repo.addAlarm(JwAlarmRecord([0x69, 0x42, 0x80, 8, 127]),
            expectedCurrent: before, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'conflict')));
    expect(writes(2, 2), isEmpty);
  });
  test('profile and goals use firmware BE, submission evidence explicit',
      () async {
    await create();
    final result = await repo.syncUserInfo(
        gender: 1,
        age: 30,
        heightCm: 175.0,
        weightKg: 70.0,
        targetSteps: 10000,
        targetSleepMinutes: 480,
        contract: contract);
    expect(result.submissions.length, 3);
    expect(writes(2, 5).single.fields.single.value, [0, 0, 0x27, 0x10]);
    expect(writes(2, 6).single.fields.single.value, [1, 0xe0]);
  });
  test('profile validates all goals before any write', () async {
    await create();
    await expectLater(
        repo.syncUserInfo(
            gender: 1,
            age: 30,
            heightCm: 175.0,
            weightKg: 70.0,
            targetSteps: 10000,
            targetSleepMinutes: 65536,
            contract: contract),
        throwsRangeError);
    expect(sent, isEmpty);
  });
  for (final method in [
    'controlHeartRateMeasurement',
    'controlSpO2Measurement',
    'controlTemperatureMeasurement'
  ]) {
    test('$method owned start/stop submission', () async {
      await create();
      Future<dynamic> run(bool on) => switch (method) {
            'controlHeartRateMeasurement' =>
              repo.controlHeartRateMeasurement(on, contract: contract),
            'controlSpO2Measurement' =>
              repo.controlSpO2Measurement(on, contract: contract),
            _ => repo.controlTemperatureMeasurement(on, contract: contract)
          };
      final submission = await run(true);
      expect(submission.acknowledged, true);
      await run(false);
    });
  }
  test('manual BP capability false zero TX despite factory and auto BP',
      () async {
    await create();
    await expectLater(
        repo.controlBloodPressureMeasurement(true, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'unsupported')));
    expect(sent, isEmpty);
  });
  test('manual HR foreign task rejected without control write', () async {
    await create();
    health = [0, 0, 0, 0, 0, 0, 0, 1];
    await expectLater(
        repo.controlHeartRateMeasurement(true, contract: contract),
        throwsStateError);
    expect(writes(5, 13), isEmpty);
  });
  test('sport owned lifecycle uses direct action replies', () async {
    await create();
    await repository.readSupportDeviceSport(contract: contract);
    final start = await repo.startDeviceSport(5, contract: contract);
    expect(start.state, 1);
    expect((await repo.pauseDeviceSport(contract: contract)).state, 2);
    expect((await repo.resumeDeviceSport(contract: contract)).state, 1);
    expect((await repo.stopDeviceSport(contract: contract)).state, 0);
    expect(writes(5, 92).map((m) => m.fields.single.value.first),
        [0, 1, 0, 2, 0, 3, 0, 4]);
  });
  test('sport refuses foreign running session', () async {
    await create();
    await repository.readSupportDeviceSport(contract: contract);
    sport = [0, 1, 5];
    await expectLater(
        repo.startDeviceSport(5, contract: contract), throwsStateError);
    expect(writes(5, 92).map((m) => m.fields.single.value.first), [0]);
  });
  test('sport stop requires owned session before any TX', () async {
    await create();
    await expectLater(
        repo.stopDeviceSport(contract: contract), throwsStateError);
    expect(sent, isEmpty);
  });
  test('pairing coupled setters default deny zero TX', () async {
    await create();
    await expectLater(repo.setSocialReminder(0, contract: contract),
        throwsA(isA<JwConfigurationException>()));
    await expectLater(
        repo.setDisturb(JwDisturbStatus(Uint8List(3)), contract: contract),
        throwsA(isA<JwConfigurationException>()));
    expect(sent, isEmpty);
  });
  test(
      'offline explicitly acknowledged notification risk encodes exact four-byte mask',
      () async {
    await create();
    final receipt = await repo.setSocialReminder(0x80000007,
        contract: contract, acknowledgedPairingRisk: true);
    expect(receipt.acknowledged, true);
    expect(writes(2, 45).single.fields.single.value, [0x80, 0, 0, 7]);
  });
  test('offline explicitly acknowledged DND risk encodes saved intent only',
      () async {
    await create();
    final receipt = await repo.setDisturb(
        JwDisturbStatus(Uint8List.fromList([0x52, 4, 0x80])),
        contract: contract,
        acknowledgedPairingRisk: true);
    expect(receipt.acknowledged, true);
    expect(writes(2, 71).single.fields.single.value, [0x52, 4, 0x80]);
  });
  test('shared FTL high HR blocked despite advertised bit11', () async {
    await create();
    await expectLater(
        repo.setHeartRateReminder(
            enabled: true, threshold: 180, contract: contract),
        throwsA(isA<JwConfigurationException>()
            .having((e) => e.stage, 'stage', 'unsupported')));
    expect(sent, isEmpty);
  });
  test(
      'actual disabled dormant long-sit preserves bytes but cannot enable invalid minutes',
      () {
    final value = JwLongSitSettings([0, 0, 0, 200, 60, 8, 18, 255]);
    expect(value.enabled, false);
    expect((value as dynamic).hasValidSchedule, false);
    expect(value.raw, [0, 0, 0, 200, 60, 8, 18, 255]);
    expect(() => value.withEnabled(true),
        throwsA(isA<JwConfigurationException>()));
  });
  test('disabled dormant long-sit can restore after valid active trial',
      () async {
    await create();
    longSit = [0, 0, 0, 200, 60, 8, 18, 255];
    final original = await repository.readLongSit(contract: contract);
    final trial = JwLongSitSettings([0, 1, 0, 0, 60, 8, 18, 255]);
    await repository.setLongSit(trial,
        expectedCurrent: original, contract: contract);
    final restored = await repository.setLongSit(original,
        expectedCurrent: trial, contract: contract);
    expect(restored.observed.raw, original.raw);
    expect(writes(2, 33).length, 2);
  });
}
