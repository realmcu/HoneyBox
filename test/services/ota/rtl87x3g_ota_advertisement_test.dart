import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ota/rtl87x3g_ota_platform.dart';

void main() {
  const normalDeviceId = 'AA:BB:CC:DD:EE:FF';
  const manufacturerAddress = [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff];

  test('matches BeTgt only when the manufacturer address is unchanged', () {
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: 'BeTgt',
        platformName: 'Watch',
        manufacturerData: manufacturerAddress,
        normalDeviceId: normalDeviceId,
      ),
      isTrue,
    );
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: 'BeTgt',
        platformName: 'Watch',
        manufacturerData: const [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0x00],
        normalDeviceId: normalDeviceId,
      ),
      isFalse,
    );
  });

  test('rejects a matching address without the BeTgt name', () {
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: 'Watch',
        platformName: 'Watch',
        manufacturerData: manufacturerAddress,
        normalDeviceId: normalDeviceId,
      ),
      isFalse,
    );
  });

  test('accepts a platform name and either manufacturer byte order', () {
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: null,
        platformName: 'BeTgt',
        manufacturerData: manufacturerAddress.reversed.toList(),
        normalDeviceId: normalDeviceId,
      ),
      isTrue,
    );
  });

  test('rejects missing manufacturer data or an invalid normal address', () {
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: 'BeTgt',
        platformName: 'BeTgt',
        manufacturerData: null,
        normalDeviceId: normalDeviceId,
      ),
      isFalse,
    );
    expect(
      matchesRtl87x3gOtaAdvertisement(
        advName: 'BeTgt',
        platformName: 'BeTgt',
        manufacturerData: manufacturerAddress,
        normalDeviceId: 'not-an-address',
      ),
      isFalse,
    );
  });
}
