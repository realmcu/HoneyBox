import '../../providers/ble_provider.dart';
import 'jw_gatt_profile.dart';

abstract final class JwScanPolicy {
  static bool isCandidate(
      {required Set<String> serviceUuids,
      required Map<int, List<int>> manufacturerData,
      String deviceName = ''}) {
    final uuids = serviceUuids.map(JwGattProfile.normalize).toSet();
    if (isHoneyWsAdvertisement(
        serviceUuids: uuids,
        manufacturerData: manufacturerData,
        deviceName: deviceName)) {
      return false;
    }
    if (uuids.contains('0000fd50-0000-1000-8000-00805f9b34fb') ||
        uuids.contains(JwGattProfile.service)) {
      return true;
    }
    final legacy = manufacturerData[0x07d0];
    return legacy != null && legacy.length >= 6;
  }

  static bool isHoneyWsAdvertisement({
    required Set<String> serviceUuids,
    required Map<int, List<int>> manufacturerData,
    String deviceName = '',
  }) {
    if (serviceUuids.contains(
        '6e400001-b5a3-f393-e0a9-e50e24dcca9e')) {
      return true;
    }
    final fec5 = manufacturerData[0xfec5];
    if (fec5 == null || fec5.length < 6) {
      return false;
    }
    if (serviceUuids.contains('0000fee7-0000-1000-8000-00805f9b34fb')) {
      return true;
    }
    return deviceName.trim().toLowerCase() == 'watch';
  }

  static bool matches(
      {required String query,
      required bool isDefaultWatchFilter,
      required ScanDevice device,
      bool onlyNamed = false,
      bool onlyConnectable = false}) {
    final name = device.name.trim().toLowerCase();
    if (onlyConnectable && !device.connectable) return false;
    if (onlyNamed && (name.isEmpty || name == 'n/a' || name == '未知设备')) {
      return false;
    }
    final q = query.trim().toLowerCase();
    final hexQuery = q.replaceAll(RegExp(r'[:\-\s]'), '');
    final isFullHexSequence = RegExp(r'^[0-9a-f]{12}$').hasMatch(hexQuery);
    final matchesAdvertisement = isFullHexSequence &&
        device.manufacturerData.values.any((bytes) {
          final hex =
              bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          for (var i = 0; i + hexQuery.length <= hex.length; i += 2) {
            if (hex.substring(i, i + hexQuery.length) == hexQuery) return true;
          }
          return false;
        });
    if (isFullHexSequence) {
      return matchesAdvertisement ||
          device.deviceId.toLowerCase().replaceAll(RegExp(r'[:\-\s]'), '') ==
              hexQuery;
    }
    return q.isEmpty ||
        (isDefaultWatchFilter && device.jwCandidate) ||
        device.name.toLowerCase().contains(q) ||
        device.deviceId.toLowerCase().contains(q);
  }
}
