import 'dart:async';
import 'dart:typed_data';
import 'package:watch_transport_ble/watch_transport_ble.dart';

// Diagnostic-only JW language query (0x02/0x4f -> 0x50), matching the existing
// JW implementation. Protocol bytes intentionally stay outside the BLE package.
int _crc(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1;
    }
  }
  return crc;
}

Uint8List jwLanguageRequest() {
  final payload = [2, 0, 0x4f, 0, 0];
  final crc = _crc(payload);
  return Uint8List.fromList(
      [0xab, 0, 0, 5, crc >> 8, crc & 255, 0, 0, ...payload]);
}

WatchBleProfile jwDiagnosticProfile() => WatchBleProfile(
    service: '000001ff-3c17-d293-8e48-14fe2e4da212', tx: 'ff02', rx: 'ff03');
bool isJwCandidate(WatchBleAdvertisement device) =>
    device.services.map(normalizeBleUuid).any((s) =>
        s == jwDiagnosticProfile().service || s == normalizeBleUuid('fd50')) ||
    device.manufacturerData.entries.any(
        (e) => (e.key == 0x07d0 || e.key == 0xfec5) && e.value.length >= 6);

/// Runs on an already connected diagnostic port. No login/bind or data mutation.
Future<int> queryJwLanguage(WatchBleConnection connection) async {
  final response = Completer<int>();
  final buffer = <int>[];
  final acknowledgements = <Future<void>>[];
  final outcome = response.future.timeout(const Duration(seconds: 10));
  outcome.ignore();
  final subscription = connection.received.listen((chunk) {
    buffer.addAll(chunk);
    while (buffer.isNotEmpty) {
      if (buffer.first != 0xab) {
        buffer.removeAt(0);
        continue;
      }
      if (buffer.length < 8) break;
      final n = (buffer[2] << 8) | buffer[3];
      if (n > 236) {
        buffer.removeAt(0);
        continue;
      }
      if (buffer.length < n + 8) break;
      final frame = buffer.sublist(0, n + 8);
      buffer.removeRange(0, n + 8);
      final payload = frame.sublist(8);
      if (_crc(payload) != ((frame[4] << 8) | frame[5])) continue;
      if (frame[1] & 0x10 != 0) continue; // ACK alone does not pass this probe.
      if (frame[1] & 0x40 == 0) {
        final ack = connection.write(
            Uint8List.fromList([0xab, 0x10, 0, 0, 0, 0, frame[6], frame[7]]));
        ack.ignore();
        acknowledgements.add(ack);
      }
      if (payload.length == 6 &&
          payload[0] == 2 &&
          payload[1] == 0 &&
          payload[2] == 0x50 &&
          payload[3] == 0 &&
          payload[4] == 1 &&
          payload[5] <= 17 &&
          !response.isCompleted) {
        response.complete(payload[5]);
      }
    }
  }, onError: (Object error) {
    if (!response.isCompleted) response.completeError(error);
  });
  final down = connection.disconnected.listen((_) {
    if (!response.isCompleted) {
      response.completeError(StateError('Device disconnected during query'));
    }
  });
  try {
    await connection.write(jwLanguageRequest());
    final language = await outcome;
    await Future.wait(acknowledgements);
    return language;
  } finally {
    await subscription.cancel();
    await down.cancel();
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
