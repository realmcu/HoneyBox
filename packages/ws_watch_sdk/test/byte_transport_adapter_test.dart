import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';
import 'package:ws_watch_sdk/src/errors.dart';
import 'package:ws_watch_sdk/src/transport/byte_transport_adapter.dart';

void main() {
  test('WS adapter preserves identity, limits, bytes and maps transport errors',
      () async {
    final (host, peer) = WatchSimulationConnection.pair(
        target: WatchDeviceTarget(
            transportId: 'simulation', deviceId: 'ws-watch-sim'),
        maxWriteLength: 3);
    final adapter = WSByteTransportAdapter(host);
    addTearDown(adapter.dispose);
    addTearDown(peer.dispose);
    expect(adapter.deviceId, 'ws-watch-sim');
    expect(adapter.maxWriteLength, 3);
    await expectLater(
        adapter.write(Uint8List(1)), throwsA(isA<WSDisconnectedException>()));
    await adapter.prepare();
    await peer.connect();
    final incoming = adapter.received.first;
    await peer.write(Uint8List.fromList([1, 2]));
    expect(await incoming, [1, 2]);
    await expectLater(adapter.write(Uint8List(4)), throwsArgumentError);
    final down = adapter.disconnected.first;
    await peer.disconnect();
    await down;
    await expectLater(
        adapter.write(Uint8List(1)), throwsA(isA<WSDisconnectedException>()));
  });
}
