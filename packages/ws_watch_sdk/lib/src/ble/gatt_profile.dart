/// 私有协议的 GATT 服务和特征值，与 Java v2 `BleManager` 一致。
abstract final class WSGattProfile {
  static const String service = '000001ff-3c17-d293-8e48-14fe2e4da212';

  /// App → 设备，带响应写。
  static const String write = '0000ff02-0000-1000-8000-00805f9b34fb';

  /// 设备 → App。
  static const String notify = '0000ff03-0000-1000-8000-00805f9b34fb';
}
