import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'package:honeybox/services/jw/jw_device_repository.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_remaining_models.dart';
import 'package:honeybox/services/jw/jw_session.dart';
import '../../helpers/fake_jw_transport.dart';
import '../../helpers/jw_device_script.dart';

void main() {
  const contract = JwConfigurationContract.v101S200;
  late JwDeviceRepository repository;
  late FakeJwTransport transport;
  final resets = <JwMessage>[];
  Future<void> create(
      {bool ack = true,
      int login = 0,
      String firmware = 'T005',
      String functions = '4dd17dfce34ad83d'}) async {
    resets.clear();
    final directory = await Directory.systemTemp.createTemp('jw_reset_');
    transport = FakeJwTransport();
    installJwDeviceScript(transport, functions: functions, loginResult: login);
    transport.readValues['2a26'] = Uint8List.fromList(firmware.codeUnits);
    final original = transport.onWrite!;
    transport.onWrite = (bytes) {
      final frame = JwFrameDecoder().add(bytes).single;
      if (frame.ack) return;
      final message = JwCodec.decodeL2(frame.payload);
      if (message.command == 5 && message.fields.single.key == 0xfa) {
        resets.add(message);
        if (ack) transport.emitAck(frame.seq);
        return;
      }
      original(bytes);
    };
    repository = JwDeviceRepository(
        session:
            JwSession(transport, ackTimeout: const Duration(milliseconds: 25)),
        transport: transport,
        identityStore: JwIdentityStore(File('${directory.path}/id.json')),
        historyStoreFactory: () =>
            throw StateError('reset must not open local history'));
    addTearDown(() async {
      await repository.dispose();
      await transport.dispose();
      await directory.delete(recursive: true);
    });
    await repository.initialize();
  }

  Future<JwSubmission> reset() async =>
      await (repository as dynamic).resetHistoryCursor(contract: contract)
          as JwSubmission;
  test(
      'reset sends one empty 05/FA ACK-only submission without local store access',
      () async {
    await create();
    final result = await reset();
    expect(resets.single.fields.single.value, isEmpty);
    expect(result.acknowledged, true);
    expect(result.responseRaw, isNull);
  });
  test('lost ACK never retries cursor mutation', () async {
    await create(ack: false);
    await expectLater(reset(), throwsA(isA<JwLinkException>()));
    expect(resets, hasLength(1));
  });
  test('wrong firmware rejects reset before write', () async {
    await create(firmware: 'T004');
    await expectLater(reset(), throwsA(isA<JwConfigurationException>()));
    expect(resets, isEmpty);
  });
  test('absent history capabilities rejects reset before write', () async {
    await create(functions: '0000000000000000');
    await expectLater(reset(), throwsA(isA<JwConfigurationException>()));
    expect(resets, isEmpty);
  });
  test('login rejection rejects reset before write', () async {
    await create(login: 1);
    await expectLater(reset(), throwsStateError);
    expect(resets, isEmpty);
  });
  test('active operation rejects reset rather than queueing a mutation',
      () async {
    await create(ack: false);
    final firstCheck = expectLater(reset(), throwsA(isA<JwLinkException>()));
    await expectLater(reset(), throwsStateError);
    await firstCheck;
    expect(resets, hasLength(1));
  });
}
