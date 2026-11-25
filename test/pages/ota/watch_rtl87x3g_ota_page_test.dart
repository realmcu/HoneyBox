import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ota/watch_rtl87x3g_ota_page.dart';
import 'package:honeybox/providers/watch_ota_result_provider.dart';
import 'package:honeybox/services/ota/ota_session.dart';
import 'package:honeybox/services/ota/rtl87x3g_firmware_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Watch firmware is a Realtek MP OTA image', () async {
    final directory = await Directory.systemTemp.createTemp('watch-ota-asset-');
    addTearDown(() => directory.delete(recursive: true));

    final path = await stageWatchRtl87x3gBundledFirmware(
      directory: directory,
    );
    final bytes = await File(path).readAsBytes();

    expect(bytes.length, greaterThan(1500000));
    expect(bytes.sublist(0, 2), [0x01, 0x00]);
    expect(
        String.fromCharCodes(bytes.sublist(0x13, 0x1A)), contains('RTL8773'));

    // The bundled file must be the Realtek MP OTA package the device expects,
    // not the bare download image.
    final package = Rtl87x3gOtaPackage.parse(bytes);
    expect(package.mpImageSize, greaterThan(0));
    expect(package.image.icType, rtl87x3gIcType);
    expect(package.image.imageId, rtl87x3gMcuAppImageId);
  });

  group('watchOtaResultMessage', () {
    test('reports a verified upgrade as success', () {
      expect(
        watchOtaResultMessage(OtaOutcome.verified, '已核验', reconnected: true),
        'Watch 固件升级成功',
      );
    });

    test('carries the failure reason through', () {
      expect(
        watchOtaResultMessage(OtaOutcome.failed, '阶段超时', reconnected: true),
        'Watch 固件升级失败：阶段超时',
      );
    });

    test('flags a device that did not reconnect', () {
      expect(
        watchOtaResultMessage(OtaOutcome.verified, '已核验', reconnected: false),
        'Watch 固件升级成功（设备未自动重连，请重新扫描连接）',
      );
    });

    test('distinguishes an unverified flash from a failure', () {
      expect(
        watchOtaResultMessage(OtaOutcome.pendingVerification, '无法连接设备',
            reconnected: true),
        '固件已写入，版本待核验：无法连接设备',
      );
    });
  });
}
