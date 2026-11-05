import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:jw_watch_sdk/src/storage/jw_database.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

void main() {
  test('feature support distinguishes discovery from device support', () {
    const unknown = JWFeatureSupport(
      feature: JWFeature.measurements,
      availability: JWFeatureAvailability.unknown,
    );
    const unsupported = JWFeatureSupport(
      feature: JWFeature.measurements,
      availability: JWFeatureAvailability.unsupported,
      reason: 'Firmware does not report manual measurement support',
    );

    expect(unknown.isSupported, isFalse);
    expect(unsupported.isSupported, isFalse);
    expect(unsupported.reason, isNotEmpty);
  });

  test('JW candidate filtering keeps FD50 discovery broad', () {
    final fd50 = WatchBleAdvertisement(
      deviceId: 'candidate',
      name: 'JW',
      rssi: -60,
      services: const [jwFd50ServiceUuid],
    );
    final other = WatchBleAdvertisement(
      deviceId: 'other',
      name: 'Other',
      rssi: -60,
      services: const ['180f'],
    );

    expect(isJWCandidate(fd50), isTrue);
    expect(isJWCandidate(other), isFalse);
  });

  test('identity is validated before bytes are parsed', () {
    expect(() => JWIdentity('mnop'), throwsArgumentError);
    expect(JWIdentity('A' * 32).bytes, hasLength(32));
    expect(JWIdentity('123456').value.length, 32);
  });

  test('device-function report follows Android JWDeviceFunctionInfo bits', () {
    final functions = JWDeviceFunctionInfo.fromWire(Uint8List.fromList([
      0x85, // music control, alarm, base switch
      0x50, // camera control, find device
      0x38, // multi-language, hour system, unit system
      0x34, // heart rate, blood pressure, sleep
      0x21, // temperature, SpO2
      0x0c, // SpO2 continuous, ECG
      0xa0, // HRV, blood sugar
      0x29, // readiness, sport control, pressure
    ]));

    expect(functions.supports(JWDeviceFunction.musicControl), isTrue);
    expect(functions.supports(JWDeviceFunction.alarm), isTrue);
    expect(functions.supports(JWDeviceFunction.cameraControl), isTrue);
    expect(functions.supports(JWDeviceFunction.findDevice), isTrue);
    expect(functions.supports(JWDeviceFunction.multiLanguage), isTrue);
    expect(functions.supports(JWDeviceFunction.rate), isTrue);
    expect(functions.supports(JWDeviceFunction.sleep), isTrue);
    expect(functions.supports(JWDeviceFunction.temperature), isTrue);
    expect(functions.supports(JWDeviceFunction.ecgFunction), isTrue);
    expect(functions.supports(JWDeviceFunction.bloodSugar), isTrue);
    expect(functions.supports(JWDeviceFunction.pressure), isTrue);
    expect(functions.supports(JWDeviceFunction.nfc), isFalse);
  });

  test('SDK initialization is explicit and cannot run twice', () async {
    final store =
        JWHistoryStore.forDatabase(JWDatabase(NativeDatabase.memory()));
    addTearDown(store.dispose);
    final watch = JWWatch(historyStore: store);
    addTearDown(watch.dispose);

    expect(watch.isInitialized, isFalse);
    await watch.initialize();
    expect(watch.isInitialized, isTrue);
    expect(watch.historyStore, same(store));
    await expectLater(watch.initialize(), throwsA(isA<StateError>()));
  });

  test('identity store writes a stable protocol identity', () async {
    final root = await Directory.systemTemp.createTemp('jw_identity_test_');
    addTearDown(() => root.delete(recursive: true));
    final store = JWIdentityStore(File('${root.path}/identity.json'),
        randomBytes: (_) => Uint8List.fromList(List<int>.filled(16, 0xab)));

    final first = await store.loadOrCreate();
    final second = await store.loadExisting();

    expect(first.value, 'ab' * 16);
    expect(await File('${root.path}/identity.json').readAsString(),
        contains('"userId"'));
    expect(first.bytes, Uint8List.fromList(('ab' * 16).codeUnits));
    expect(second.value, first.value);
  });
}
