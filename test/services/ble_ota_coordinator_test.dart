import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ota/android_realtek_ota_platform.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('honeybox/realtek-ota');
  test(
      'native OTA holds shared BLE ownership until native close confirms it stopped',
      () async {
    var processing = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'close' && processing) {
        throw PlatformException(code: 'busy');
      }
      return null;
    });
    final ota = AndroidRealtekOtaPlatform();
    addTearDown(() async {
      processing = false;
      await ota.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await ota.prepare('ota-device', sessionId: 'test');
    await ota.start('/tmp/test.bin');
    await expectLater(ota.close(), throwsA(isA<PlatformException>()));
    expect(() => WatchBleCoordinator.shared.acquire('other-device'),
        throwsA(isA<WatchTransportException>()));
    processing = false;
    await ota.close();
    WatchBleCoordinator.shared.acquire('other-device').release();
  });
  test(
      'native OTA cannot prepare over an existing capture or ordinary device lease',
      () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final lease = WatchBleCoordinator.shared.acquire('capture-device');
    addTearDown(lease.release);
    final ota = AndroidRealtekOtaPlatform();
    await expectLater(ota.prepare('ota-device', sessionId: 'test'),
        throwsA(isA<WatchTransportException>()));
    expect(calls, 0);
    await ota.close();
  });
}
