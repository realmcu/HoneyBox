import 'dart:async';
import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'package:watch_transport_ble_example/jw_smoke.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'JW real BLE: scan, language reply and battery read, disconnect and reconnect',
      (tester) async {
    final scanner = WatchBleScanner();
    addTearDown(scanner.dispose);
    const scanSeconds =
        int.fromEnvironment('BLE_SCAN_SECONDS', defaultValue: 10);
    await scanner.start(timeout: const Duration(seconds: scanSeconds + 5));
    await Future<void>.delayed(const Duration(seconds: scanSeconds));
    await scanner.stop();
    for (final device in scanner.devices) {
      debugPrint(
          'BLE inventory: ${device.name} ${device.deviceId} RSSI=${device.rssi} JW=${isJwCandidate(device)}');
    }
    const requested = String.fromEnvironment('BLE_DEVICE_ID');
    const name = String.fromEnvironment('BLE_DEVICE_NAME');
    const mac = String.fromEnvironment('BLE_DEVICE_MAC');
    final candidates = scanner.devices.where((d) {
      if (requested.isNotEmpty &&
          d.deviceId.toLowerCase() != requested.toLowerCase()) {
        return false;
      }
      if (name.isNotEmpty && d.name.toLowerCase() != name.toLowerCase()) {
        return false;
      }
      if (mac.isNotEmpty && !advertisesMac(d, mac)) return false;
      return requested.isNotEmpty ||
          name.isNotEmpty ||
          mac.isNotEmpty ||
          isJwCandidate(d);
    }).toList();
    for (final d in scanner.devices.where(isJwCandidate)) {
      debugPrint(
          'JW candidate ${d.name} ${d.deviceId} manufacturer=${d.manufacturerData}');
    }
    expect(candidates.length, 1,
        reason:
            'Specify BLE_DEVICE_ID / BLE_DEVICE_NAME / BLE_DEVICE_MAC; all specified selectors must match');
    final device = candidates.single;
    debugPrint(
        'JW selected ${device.name} ${device.deviceId} manufacturer=${device.manufacturerData}');
    for (var attempt = 0; attempt < 2; attempt++) {
      final connection = WatchBleTransport(
              config: WatchBleConfig(profile: jwDiagnosticProfile()))
          .createConnection(
              WatchDeviceTarget(transportId: 'ble', deviceId: device.deviceId));
      final subscription =
          connection.received.listen((data) => debugPrint('JW RX: $data'));
      try {
        await connection.connect();
        debugPrint('JW connected attempt=$attempt mtu=${connection.mtu}');
        final language = await queryJwLanguage(connection);
        expect(language, inInclusiveRange(0, 17));
        debugPrint('JW language reply=$language attempt=$attempt');
        final battery = await readJwBattery(connection);
        expect(battery, inInclusiveRange(0, 100));
        debugPrint('JW battery read=$battery% attempt=$attempt');
        if (attempt == 0) await verifyFrameReliability(connection);
      } finally {
        await subscription.cancel();
        await connection.dispose();
      }
      expect(connection.state, WatchTransportState.disposed);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

// Read-only fault probe: five-byte writes and one dropped real ACK.
Future<void> verifyFrameReliability(WatchBleConnection connection) async {
  final filtered = StreamController<Uint8List>.broadcast(sync: true);
  var dropped = false;
  final parser = WatchFrameAssembler(
      timeout: const Duration(seconds: 3),
      maxPayloadLength: 236,
      profile: WatchFrameProfile.jw,
      onFrame: (frame, raw) {
        if (frame.isAck && frame.seq == 0x2000 && !frame.isError && !dropped) {
          dropped = true;
          return;
        }
        filtered.add(raw);
      },
      onError: (kind, _, __) => filtered.addError(StateError('RX $kind')));
  final rx = connection.received
      .listen(parser.add, onError: filtered.addError, onDone: filtered.close);
  final chunks = <Uint8List>[];
  final frames = <WatchFrameEvent>[];
  final channel = WatchFrameChannel(
      WatchFramePort(
          received: filtered.stream,
          disconnected: connection.disconnected.map<void>((_) {}),
          maxWriteLength: () => 5,
          write: (bytes) {
            chunks.add(bytes);
            return connection.write(bytes);
          },
          close: () async {}),
      profile: WatchFrameProfile.jw,
      config: const WatchFrameConfig(
          maxPayloadLength: 236,
          initialSequence: 0x2000,
          ackTimeout: Duration(seconds: 1),
          maxRetries: 1));
  final observations = channel.frames.listen(frames.add);
  final reply = channel.payloads.first.timeout(const Duration(seconds: 5));
  reply.ignore();
  try {
    await channel.send(Uint8List.fromList([2, 0, 0x4f, 0, 0]));
    final payload = (await reply).bytes;
    expect(payload.length, 6);
    expect(payload.sublist(0, 5), [2, 0, 0x50, 0, 1]);
    expect(payload[5], inInclusiveRange(0, 17));
    await channel.flushWrites();
    final requests = frames
        .where((e) =>
            e.direction == WatchFrameDirection.tx &&
            (e.kind == WatchFrameKind.data || e.kind == WatchFrameKind.retry))
        .toList();
    expect(dropped, isTrue);
    expect(requests, hasLength(2));
    expect(requests[0].raw, requests[1].raw);
    expect(requests.every((e) => e.seq == 0x2000), isTrue);
    expect(chunks.every((c) => c.length <= 5), isTrue);
    debugPrint(
        'JW frame probe: five-byte chunks, lost ACK, identical-seq retry PASS');
  } finally {
    await observations.cancel();
    await channel.close();
    await rx.cancel();
    parser.dispose();
    await filtered.close();
  }
}

bool advertisesMac(WatchBleAdvertisement device, String mac) {
  String compact(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[:\-\s]'), '');
  final expected = compact(mac);
  if (!RegExp(r'^[0-9a-f]{12}$').hasMatch(expected)) {
    throw ArgumentError('Invalid BLE_DEVICE_MAC');
  }
  if (compact(device.deviceId) == expected) return true;
  final reversed =
      [for (var i = 10; i >= 0; i -= 2) expected.substring(i, i + 2)].join();
  return device.manufacturerData.values.any((bytes) {
    final data = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    for (var i = 0; i + 12 <= data.length; i += 2) {
      final candidate = data.substring(i, i + 12);
      if (candidate == expected || candidate == reversed) return true;
    }
    return false;
  });
}
