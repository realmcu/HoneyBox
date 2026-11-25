import 'dart:io';

import 'firmware_inspection.dart';
import 'ota_preflight.dart';
import 'rtl87x3g_firmware_image.dart';

final class Rtl87x3gFirmwareParser implements FirmwareParser {
  const Rtl87x3gFirmwareParser();

  @override
  Future<FirmwareParseResult> parse(
    String path,
    DeviceCapabilities capabilities,
  ) async {
    try {
      final package = Rtl87x3gOtaPackage.parse(await File(path).readAsBytes());
      final image = package.image;
      final deviceIc = capabilities.otaDeviceInfo?.icType ??
          capabilities.icType ??
          capabilities.expectedIcType;
      final chipMatches = deviceIc == rtl87x3gIcType;
      final compatibility = deviceIc == null
          ? OtaCheckStatus.warn
          : chipMatches
              ? OtaCheckStatus.pass
              : OtaCheckStatus.block;
      final capacity = image.imageSize <= rtl87x3gAppBankSize
          ? OtaCheckStatus.pass
          : OtaCheckStatus.block;
      final current = capabilities.currentVersion;
      final version = current == null
          ? OtaCheckStatus.warn
          : image.version == current
              ? OtaCheckStatus.warn
              : image.version < current
                  ? OtaCheckStatus.warn
                  : OtaCheckStatus.pass;
      final batteryValue = capabilities.batteryPercent;
      final battery = capabilities.charging == true ||
              (batteryValue != null &&
                  batteryValue >= 30 &&
                  batteryValue <= 100)
          ? OtaCheckStatus.pass
          : OtaCheckStatus.warn;
      final versionText = current == null
          ? '目标版本 ${formatRtl87x3gVersion(image.version)}，设备当前版本未知'
          : image.version == current
              ? '目标与设备版本相同，将执行重复升级'
              : image.version < current
                  ? '目标版本低于设备当前版本，将执行降级'
                  : '将从 ${formatRtl87x3gVersion(current)} 升级到 '
                      '${formatRtl87x3gVersion(image.version)}';
      final checks = <OtaCheck>[
        const OtaCheck(
          'format',
          OtaCheckStatus.pass,
          '固件格式通过：Realtek MP + RTL87x3G IMGHDR + MCUAPP',
        ),
        OtaCheck(
          'compatibility',
          compatibility,
          deviceIc == null
              ? '兼容性：设备芯片未知，固件为 RTL8773G MCUAPP'
              : chipMatches
                  ? '兼容性通过：设备与固件均为 RTL8773G'
                  : '芯片不匹配：设备 0x${deviceIc.toRadixString(16)}，固件 0x13',
        ),
        OtaCheck(
          'capacity',
          capacity,
          '容量：${image.imageSize} / $rtl87x3gAppBankSize 字节',
        ),
        OtaCheck('version', version, versionText),
        OtaCheck(
          'battery',
          battery,
          batteryValue == null
              ? '无法读取设备电量，请确认升级期间供电稳定'
              : '设备电量 $batteryValue%${capabilities.charging == true ? '，正在充电' : ''}',
        ),
      ];
      return FirmwareParseResult(
        rawStatus: {
          'type': 'Realtek MP + RTL87x3G IMGHDR',
          'mpImageId': package.mpImageId,
          'mpImageSize': package.mpImageSize,
          'images': [
            {
              'imageId': image.imageId,
              'version': image.version,
              'version64': image.version64,
              'size': image.imageSize,
              'icType': image.icType,
              'commitId': image.commitId,
            },
          ],
        },
        type: 'Realtek RTL87x3G',
        images: [
          'MCUAPP 0x${image.imageId.toRadixString(16)} '
              '${formatRtl87x3gVersion(image.version)}',
        ],
        checks: checks,
      );
    } catch (error) {
      return FirmwareParseResult(
        checks: [
          OtaCheck('format', OtaCheckStatus.block, '固件格式无效：$error'),
          const OtaCheck(
            'compatibility',
            OtaCheckStatus.unknown,
            '固件格式无效，未执行兼容性检查',
          ),
        ],
      );
    }
  }
}

String formatRtl87x3gVersion(int value) =>
    '0x${value.toRadixString(16).padLeft(8, '0')} '
    '(${value & 0xff}.${(value >> 8) & 0xff}.${(value >> 16) & 0xffff})';
