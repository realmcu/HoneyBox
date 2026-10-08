import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/services/jw/jw_scan_policy.dart';

void main() {
  test('advertising hints accept exact known UUID/company format only', () {
    bool candidate(Set<String> uuids, Map<int, List<int>> data) =>
        JwScanPolicy.isCandidate(serviceUuids: uuids, manufacturerData: data);
    expect(candidate({'FD50'}, {}), isTrue);
    expect(candidate({'000001ff-3c17-d293-8e48-14fe2e4da212'}, {}), isTrue);
    expect(
        candidate({}, {
          0xfec5: [1, 2, 3, 4, 5, 6]
        }),
        isTrue);
    expect(
        candidate({}, {
          0x07d0: [1, 2, 3, 4, 5, 6]
        }),
        isTrue);
    expect(
        candidate({}, {
          0xfec5: [1]
        }),
        isFalse);
    expect(
        candidate({
          '001ff'
        }, {
          1: [1, 2, 3, 4, 5, 6]
        }),
        isFalse);
  });
  test(
      'Watch default includes unnamed candidates; user filters retain old semantics',
      () {
    final d = ScanDevice(
        deviceId: '64:1A:B2:B8:00:3A', name: '', rssi: -42, jwCandidate: true);
    expect(
        JwScanPolicy.matches(
            query: 'Watch', isDefaultWatchFilter: true, device: d),
        isTrue);
    expect(
        JwScanPolicy.matches(
            query: 'eBadge', isDefaultWatchFilter: false, device: d),
        isFalse);
    expect(
        JwScanPolicy.matches(
            query: '00:3a', isDefaultWatchFilter: false, device: d),
        isTrue);
    expect(
        JwScanPolicy.matches(
            query: 'Watch', isDefaultWatchFilter: false, device: d),
        isFalse);
  });
  test(
      'late name merges by ID and later empty advertising cannot erase identity or hint',
      () {
    final n = ScannedDevicesNotifier();
    addTearDown(n.dispose);
    n.addDevice(
        ScanDevice(deviceId: 'a', name: '', rssi: -42, jwCandidate: true));
    final first = n.state.single.firstSeen;
    n.addDevice(ScanDevice(deviceId: 'a', name: 'S200', rssi: -43));
    n.addDevice(ScanDevice(deviceId: 'a', name: '未知设备', rssi: -44));
    expect(n.state, hasLength(1));
    expect(n.state.single.name, 'S200');
    expect(n.state.single.jwCandidate, isTrue);
    expect(n.state.single.firstSeen, first);
    expect(n.state.single.identitySeen, isNotNull);
  });
}
