import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_raw_channel.dart';

class Rig {
  final rx = StreamController<Uint8List>.broadcast();
  final down = StreamController<void>.broadcast(sync: true);
  final chunks = <Uint8List>[];
  final responses = <bool>[];
  Completer<void>? gate;
  bool subscribeFails = false;
  bool writeFails = false;
  int subscribeCount = 0;
  late JwRawChannel channel;
  Rig({int mtu = 23}) {
    channel = JwRawChannel(
        mtu: mtu,
        notifications: rx.stream,
        disconnected: down.stream,
        subscribeFn: () async {
          subscribeCount++;
          if (subscribeFails) throw StateError('CCCD refused');
        },
        writeFn: (bytes, {required bool withResponse}) async {
          chunks.add(Uint8List.fromList(bytes));
          responses.add(withResponse);
          if (writeFails) throw StateError('write failed');
          if (gate != null && chunks.length == 1) await gate!.future;
        },
        readFn: (uuid) async => Uint8List.fromList([70]),
        disconnectFn: () async {
          down.add(null);
        });
  }
  Future<void> close() async {
    channel.invalidate();
    await rx.close();
    await down.close();
  }
}

void main() {
  test('MTU23 serializes 45 bytes into response writes 20/20/5', () async {
    final r = Rig();
    addTearDown(r.close);
    r.gate = Completer<void>();
    await r.channel.subscribe();
    final pending = r.channel.write(Uint8List(45), withResponse: true);
    await Future<void>.delayed(Duration.zero);
    expect(r.chunks.map((c) => c.length), [20]);
    r.gate!.complete();
    await pending;
    expect(r.chunks.map((c) => c.length), [20, 20, 5]);
    expect(r.responses, [true, true, true]);
  });
  test('MTU247 sends one complete frame and subscription is idempotent',
      () async {
    final r = Rig(mtu: 247);
    addTearDown(r.close);
    await Future.wait([r.channel.subscribe(), r.channel.subscribe()]);
    await r.channel.write(Uint8List(244), withResponse: true);
    expect(r.chunks.single.length, 244);
    expect(r.subscribeCount, 1);
  });
  test('unsubscribed, oversized and no-response writes never reach GATT',
      () async {
    final r = Rig();
    addTearDown(r.close);
    await expectLater(
        r.channel.write(Uint8List(8), withResponse: true), throwsStateError);
    await r.channel.subscribe();
    await expectLater(r.channel.write(Uint8List(245), withResponse: true),
        throwsArgumentError);
    await expectLater(r.channel.write(Uint8List(8), withResponse: false),
        throwsArgumentError);
    expect(r.chunks, isEmpty);
  });
  test('CCCD failure blocks transmission and write errors reach caller',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.subscribeFails = true;
    await expectLater(r.channel.subscribe(), throwsStateError);
    await expectLater(
        r.channel.write(Uint8List(8), withResponse: true), throwsStateError);
    expect(r.chunks, isEmpty);
    final good = Rig();
    addTearDown(good.close);
    await good.channel.subscribe();
    good.writeFails = true;
    await expectLater(
        good.channel.write(Uint8List(8), withResponse: true), throwsStateError);
  });
  test('concurrent complete frames never interleave chunks', () async {
    final r = Rig();
    addTearDown(r.close);
    await r.channel.subscribe();
    await Future.wait([
      r.channel
          .write(Uint8List.fromList(List.filled(25, 1)), withResponse: true),
      r.channel
          .write(Uint8List.fromList(List.filled(25, 2)), withResponse: true)
    ]);
    expect(r.chunks.map((c) => c.first), [1, 1, 2, 2]);
  });
  test('disconnect cancels queued callers even when a GATT write is stuck',
      () async {
    final r = Rig();
    addTearDown(r.close);
    await r.channel.subscribe();
    r.gate = Completer<void>();
    final a = r.channel.write(Uint8List(45), withResponse: true);
    final b = r.channel.write(Uint8List(8), withResponse: true);
    final ea = expectLater(a, throwsStateError);
    final eb = expectLater(b, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    r.down.add(null);
    await Future.wait([ea, eb]);
    r.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(r.chunks.length, 1);
  });
}
