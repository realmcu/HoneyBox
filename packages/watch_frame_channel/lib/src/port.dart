import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';

/// Byte operations on an already prepared connection. The channel owns close.
/// Legacy SDK ports can adapt here without acquiring a second device lease.
class WatchFramePort {
  const WatchFramePort(
      {required this.received,
      required this.disconnected,
      required this.maxWriteLength,
      required this.write,
      required this.close});

  factory WatchFramePort.fromConnection(WatchTransportConnection connection) =>
      WatchFramePort(
          received: connection.received,
          disconnected: connection.disconnected.map<void>((_) {}),
          maxWriteLength: () => connection.writeLimits.maxWriteLength,
          write: connection.write,
          close: () async {
            try {
              await connection.disconnect();
            } finally {
              await connection.dispose();
            }
          });

  final Stream<Uint8List> received;
  final Stream<void> disconnected;
  final int Function() maxWriteLength;
  final Future<void> Function(Uint8List bytes) write;
  final Future<void> Function() close;
}
