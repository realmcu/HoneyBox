import 'package:watch_transport/watch_transport.dart';

String normalizeBleUuid(String uuid) {
  final value = uuid.toLowerCase();
  if (value.length == 4) return '0000$value-0000-1000-8000-00805f9b34fb';
  if (value.length == 8) return '$value-0000-1000-8000-00805f9b34fb';
  return value;
}

enum BleWriteMode { withResponse, withoutResponse, preferWithoutResponse }

enum BleConnectionStage {
  connecting,
  discovering,
  subscribing,
  ready,
  write,
  read,
  cleanup
}

class WatchBleException extends WatchTransportException {
  const WatchBleException(super.code, super.message, {required this.stage});
  final BleConnectionStage stage;
}

/// Protocol owners supply UUIDs; this package does not select a protocol.
final class WatchBleProfile {
  WatchBleProfile(
      {required String service,
      required String tx,
      required String rx,
      this.writeMode = BleWriteMode.withResponse})
      : service = normalizeBleUuid(service),
        tx = normalizeBleUuid(tx),
        rx = normalizeBleUuid(rx) {
    for (final uuid in [this.service, this.tx, this.rx]) {
      if (!RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(uuid)) {
        throw ArgumentError.value(uuid, 'uuid');
      }
    }
  }
  final String service, tx, rx;
  final BleWriteMode writeMode;
}

final class WatchBleConfig {
  WatchBleConfig(
      {required this.profile,
      this.connectTimeout = const Duration(seconds: 20),
      this.operationTimeout = const Duration(seconds: 10),
      this.maxBufferedBytes = 64 * 1024,
      this.requestThroughput = false}) {
    if (connectTimeout <= Duration.zero ||
        operationTimeout <= Duration.zero ||
        maxBufferedBytes <= 0) {
      throw ArgumentError('Timeouts and receive capacity must be positive');
    }
  }
  final WatchBleProfile profile;
  final Duration connectTimeout, operationTimeout;
  final int maxBufferedBytes;
  final bool requestThroughput;
}
