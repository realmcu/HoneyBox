import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:ws_watch_sdk/src/ble/ws_ble_profile.dart';

void main() {
  test('WS scan accepts NUS and Realtek Honey gap_init adverts', () {
    final nus = WatchBleAdvertisement(
      deviceId: 'nus',
      name: 'UART',
      rssi: -55,
      services: const [wsNusServiceUuid],
    );
    final watch = WatchBleAdvertisement(
      deviceId: 'watch',
      name: 'Watch',
      rssi: -55,
      services: const [
        wsRealtekFee7ServiceUuid,
        jwWristbandServiceUuidFromLegacyScanRsp,
      ],
      manufacturerData: {
        0xfec5: [1, 2, 3, 4, 5, 6],
      },
    );
    final legacyJw = WatchBleAdvertisement(
      deviceId: 'jw',
      name: 'Band',
      rssi: -55,
      services: const ['000001ff-3c17-d293-8e48-14fe2e4da212'],
      manufacturerData: {
        0x07d0: [1, 2, 3, 4, 5, 6],
      },
    );

    expect(isWSCandidate(nus), isTrue);
    expect(isWSCandidate(watch), isTrue);
    expect(isWSCandidate(legacyJw), isFalse);
    expect(wsBleScanServiceUuids, isEmpty);
  });
}

/// Scan response still lists JW UUID on Honey WS firmware (`hmi_ble_gap_init.c`).
const jwWristbandServiceUuidFromLegacyScanRsp =
    '000001ff-3c17-d293-8e48-14fe2e4da212';
