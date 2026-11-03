import 'dart:async';
import 'dart:typed_data';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_frame_channel/watch_frame_channel.dart';

WatchBleProfile jwDiagnosticProfile() => WatchBleProfile(
    service: '000001ff-3c17-d293-8e48-14fe2e4da212', tx: 'ff02', rx: 'ff03');
bool isJwCandidate(WatchBleAdvertisement device) =>
    device.services.map(normalizeBleUuid).any((s) =>
        s == jwDiagnosticProfile().service || s == normalizeBleUuid('fd50')) ||
    device.manufacturerData.entries.any(
        (e) => (e.key == 0x07d0 || e.key == 0xfec5) && e.value.length >= 6);

/// Runs on an already connected diagnostic port. No login/bind or data mutation.
Future<int> queryJwLanguage(WatchBleConnection connection) async {
  final channel = WatchFrameChannel(
      WatchFramePort(
          received: connection.received,
          disconnected: connection.disconnected.map<void>((_) {}),
          maxWriteLength: () => connection.writeLimits.maxWriteLength,
          write: connection.write,
          // Probe releases its subscriptions; caller owns connection for battery read.
          close: () async {}),
      profile: WatchFrameProfile.jw,
      config: const WatchFrameConfig(
          maxPayloadLength: 236,
          ackTimeout: Duration(seconds: 3),
          maxRetries: 2));
  final response = Completer<int>();
  final outcome = response.future.timeout(const Duration(seconds: 10));
  outcome.ignore();
  WatchFrameSend? send;
  final sub = channel.payloads.listen((frame) {
    final payload = frame.bytes;
    if (payload.length == 6 &&
        payload[0] == 2 &&
        payload[1] == 0 &&
        payload[2] == 0x50 &&
        payload[3] == 0 &&
        payload[4] == 1 &&
        payload[5] <= 17 &&
        !response.isCompleted) {
      if (send != null) channel.confirmReceived(send);
      response.complete(payload[5]);
    }
  });
  unawaited(channel.terminated.then((error) {
    if (!response.isCompleted) response.completeError(error);
  }));
  try {
    send = channel.startSend(Uint8List.fromList([2, 0, 0x4f, 0, 0]));
    await send.completed;
    final language = await outcome;
    await channel.flushWrites();
    return language;
  } finally {
    await sub.cancel();
    await channel.close();
  }
}

/// Standard Battery Service, as used by the existing Android JW SDK.
Future<int> readJwBattery(WatchBleConnection connection) async {
  final bytes =
      await connection.readGatt(service: '180f', characteristic: '2a19');
  if (bytes.length != 1 || bytes.single > 100) {
    throw const FormatException('Invalid Battery Level');
  }
  return bytes.single;
}
