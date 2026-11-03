import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('watch_transport_ble/link');
  test('Windows tuning uses its own package channel and balances release',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final tuning = BleLinkTuning(supported: true);
    expect(await tuning.requestThroughput('AA:BB:CC:DD:EE:FF'), isTrue);
    await tuning.release('AA:BB:CC:DD:EE:FF');
    expect(
        calls.map((c) => c.method), ['requestThroughput', 'releaseThroughput']);
    expect(calls.first.arguments, {'remoteId': 'AA:BB:CC:DD:EE:FF'});
  });
  test('missing or unsupported tuner does not prevent a BLE connection',
      () async {
    expect(
        await BleLinkTuning(supported: false).requestThroughput('id'), isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (_) async => throw MissingPluginException());
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final tuning = BleLinkTuning(supported: true);
    expect(await tuning.requestThroughput('id'), isFalse);
    await tuning.release('id');
  });
}
