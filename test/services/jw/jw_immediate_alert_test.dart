import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_raw_channel.dart';

void main() {
  test('IAS concrete values and audit at dedicated GATT boundary', () async {
    final down = StreamController<void>.broadcast(sync: true);
    final writes = <int>[];
    final dynamic port = Function.apply(JwRawChannel.new, [], {
      #mtu: 247,
      #notifications: const Stream<Uint8List>.empty(),
      #disconnected: down.stream,
      #subscribeFn: () async {},
      #writeFn: (Uint8List b, {required bool withResponse}) async {},
      #readFn: (String uuid) async => null,
      #disconnectFn: () async {},
      #immediateAlertWriteFn: (Uint8List bytes) async {
        writes.add(bytes.single);
      },
      #immediateAlertWithResponse: false
    });
    final audit = <int>[];
    final sub = port.immediateAlertAttempts.listen((dynamic a) {
      expect(a.withResponse, false);
      audit.add(a.level);
    }) as StreamSubscription;
    await port.subscribe();
    expect(port.immediateAlertAvailable, true);
    await port.writeImmediateAlert(true);
    await port.writeImmediateAlert(false);
    expect(writes, [2, 0]);
    expect(audit, [2, 0]);
    await port.disconnect();
    await expectLater(port.writeImmediateAlert(true), throwsStateError);
    expect(writes, [2, 0]);
    await sub.cancel();
    await down.close();
  });
  test('IAS shares FF02 serialization and preserves transport failure',
      () async {
    final down = StreamController<void>.broadcast(sync: true);
    final gate = Completer<void>();
    final order = <String>[];
    final dynamic port = Function.apply(JwRawChannel.new, [], {
      #mtu: 247,
      #notifications: const Stream<Uint8List>.empty(),
      #disconnected: down.stream,
      #subscribeFn: () async {},
      #writeFn: (Uint8List b, {required bool withResponse}) async {
        order.add('frame');
        await gate.future;
      },
      #readFn: (String uuid) async => null,
      #disconnectFn: () async {},
      #immediateAlertWriteFn: (Uint8List bytes) async {
        order.add('IAS');
        throw StateError('native IAS write failed');
      }
    });
    await port.subscribe();
    final frame =
        port.write(Uint8List.fromList([1]), withResponse: true) as Future<void>;
    final alert = port.writeImmediateAlert(true) as Future<void>;
    final check = expectLater(alert, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['frame']);
    gate.complete();
    await frame;
    await check;
    expect(order, ['frame', 'IAS']);
    await port.disconnect();
    await down.close();
  });
}
