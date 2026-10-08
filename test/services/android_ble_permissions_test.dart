import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:honeybox/services/android_ble_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  for (final scenario in <String, (int, int, int, bool)>{
    'all required permissions granted': (1, 1, 1, true),
    'nearby grants cannot bypass denied location': (1, 1, 0, false),
    'location cannot replace denied Bluetooth scan': (0, 1, 1, false),
    'location cannot replace denied Bluetooth connect': (1, 0, 1, false),
    'permanently denied nearby permission stays blocked': (4, 1, 1, false),
    'limited location does not satisfy fine-location scanning': (
      1,
      1,
      3,
      false
    ),
  }.entries) {
    test(scenario.key, () async {
      final statuses = <int, int>{
        Permission.bluetoothScan.value: scenario.value.$1,
        Permission.bluetoothConnect.value: scenario.value.$2,
        Permission.locationWhenInUse.value: scenario.value.$3
      };
      // Only the OS boundary is replaced; the real permission_handler decoding
      // and application policy execute. Android <31 maps Bluetooth groups to
      // the manifest Bluetooth grant in the installed native plugin.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'requestPermissions');
        return <int, int>{
          for (final id in call.arguments as List<Object?>)
            id as int: statuses[id]!
        };
      });
      expect(await requestAndroidBlePermissions(), scenario.value.$4);
    });
  }
}
