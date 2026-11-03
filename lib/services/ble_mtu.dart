export 'package:watch_transport_ble/watch_transport_ble.dart'
    show kMinAttMtu, kMaxAttMtu, resolveAttMtu, negotiatePlatformMtu;

/// KS frame overhead belongs to the projection protocol, not BLE transport.
int streamChunkSizeForMtu(int mtu) {
  final chunk = (mtu - 3) - 13;
  return chunk < 1 ? 1 : chunk;
}
