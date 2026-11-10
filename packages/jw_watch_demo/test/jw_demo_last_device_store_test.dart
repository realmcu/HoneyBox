import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_demo_last_device_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('last device json round-trips', () async {
    final root = await Directory.systemTemp.createTemp('jw-demo-last-device-');
    PathProviderPlatform.instance = _FakePathProvider(root);
    addTearDown(() => root.delete(recursive: true));

    const device = JwDemoLastDevice(name: 'IK-SKR7', deviceMac: 'AA:BB:CC:DD:EE:FF');
    await JwDemoLastDeviceStore.write(device);
    final read = await JwDemoLastDeviceStore.read();
    expect(read?.name, device.name);
    expect(read?.deviceMac, device.deviceMac);
  });
}
