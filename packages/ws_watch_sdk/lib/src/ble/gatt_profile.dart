/// 私有协议 GATT：HoneyProtocol BLE UART Profile（见 ws-watch-sdk-design.md §4.1）。
abstract final class WSGattProfile {
  static const String service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// App → 设备，带响应写。
  static const String write = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// 设备 → App（Notify）。
  static const String notify = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
}
