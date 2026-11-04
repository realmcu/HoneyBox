import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_demo_controller.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('resetConnectionScanUi clears stale scan rows', () {
    final controller = JWDemoController();
    addTearDown(controller.dispose);

    controller.scanDevices.value = const [
      JWScanDevice(id: 'aa:bb', name: 'PEARCE', rssi: -50),
    ];
    controller.resetConnectionScanUi();

    expect(controller.devices, isEmpty);
  });
}
