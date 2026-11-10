import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';
import 'package:honeybox/services/watch_bind_protocol.dart';

void main() {
  late StreamController<Uint8List> notifications;
  late List<Uint8List> sent;
  final userId = Uint8List.fromList(
    '0123456789abcdef0123456789abcdef'.codeUnits,
  );

  setUp(() {
    notifications = StreamController<Uint8List>.broadcast();
    sent = [];
  });

  tearDown(() async {
    await notifications.close();
  });

  WatchBindNotifier createNotifier({
    bool available = true,
    Duration timeout = const Duration(milliseconds: 20),
    int? Function(Uint8List)? send,
    DateTime Function()? clock,
  }) {
    return WatchBindNotifier(
      commandAvailable: () => available,
      sendCommand: send ??
          (frame) {
            sent.add(Uint8List.fromList(frame));
            return 7;
          },
      notifications: notifications.stream,
      userId: userId,
      timeout: timeout,
      clock: clock ?? () => DateTime(2024, 7, 27, 15, 42, 36),
    );
  }

  test('starts unavailable and does not send without a command channel', () {
    final notifier = createNotifier(available: false);
    addTearDown(notifier.dispose);

    notifier.bind();

    expect(notifier.state.phase, WatchBindPhase.unavailable);
    expect(sent, isEmpty);
  });

  test('sends login first and ignores a duplicate bind call', () {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);

    notifier.bind();
    notifier.bind();

    expect(notifier.state.phase, WatchBindPhase.binding);
    expect(sent, [WatchBindProtocol.buildLoginRequest(userId)]);
  });

  test('successful login skips bind and synchronizes time', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(_bindResponse(0x04, 0x00));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.success);
    expect(notifier.state.timeSyncPhase, WatchTimeSyncPhase.synced);
    expect(sent, hasLength(2));
    expect(sent.last, [
      0x02,
      0x00,
      0x01,
      0x00,
      0x05,
      0x00,
      0x66,
      0xA5,
      0x15,
      0x6C,
    ]);
  });

  test('login miss sends bind request and bind success completes flow',
      () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(_bindResponse(0x04, 0x01));
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(2));
    expect(sent.last, WatchBindProtocol.buildRequest(userId));

    notifications.add(_bindResponse(0x02, 0x00));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.phase, WatchBindPhase.success);
    expect(notifier.state.timeSyncPhase, WatchTimeSyncPhase.synced);
    expect(sent, hasLength(3));
  });

  test('bind rejection maps to retryable failure', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();
    notifications.add(_bindResponse(0x04, 0x01));
    await Future<void>.delayed(Duration.zero);

    notifications.add(_bindResponse(0x02, 0x02));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.failure);
    expect(notifier.state.message, '设备绑定失败');
  });

  test('ignores malformed and unrelated responses', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(Uint8List.fromList([0x03, 0x00, 0x04, 0x00, 0x02, 0]));
    notifications.add(Uint8List.fromList([0x0D, 0x00, 0x02, 0x00, 0x01, 0]));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.binding);
    expect(sent, hasLength(1));
  });

  test('times out while waiting for login and permits retry', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(notifier.state.phase, WatchBindPhase.failure);
    expect(notifier.state.message, '等待手环登录响应超时');

    notifier.bind();
    expect(notifier.state.phase, WatchBindPhase.binding);
    expect(sent, hasLength(2));
  });

  test('keeps binding successful when time submission fails', () async {
    var calls = 0;
    final notifier = createNotifier(send: (frame) {
      sent.add(Uint8List.fromList(frame));
      calls++;
      return calls == 1 ? 7 : null;
    });
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(_bindResponse(0x04, 0x00));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.success);
    expect(notifier.state.timeSyncPhase, WatchTimeSyncPhase.failed);
    expect(notifier.state.message, '设备绑定成功，时间同步失败');
  });

  test('retry sends a fresh time frame after login success', () async {
    var now = DateTime(2024, 7, 27, 15, 42, 36);
    var calls = 0;
    final notifier = createNotifier(
      clock: () => now,
      send: (frame) {
        sent.add(Uint8List.fromList(frame));
        calls++;
        return calls == 2 ? null : 7;
      },
    );
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(_bindResponse(0x04, 0x00));
    await Future<void>.delayed(Duration.zero);
    now = DateTime(2024, 7, 27, 15, 43, 1);

    notifier.retryTimeSync();

    expect(sent, hasLength(3));
    expect(sent.where((frame) => frame[2] == 0x03), hasLength(1));
    expect(sent.last, isNot(equals(sent[1])));
    expect(notifier.state.timeSyncPhase, WatchTimeSyncPhase.synced);
  });

  test('loads the persistent user identity when not supplied', () async {
    final notifier = WatchBindNotifier(
      commandAvailable: () => true,
      sendCommand: (frame) {
        sent.add(Uint8List.fromList(frame));
        return 1;
      },
      notifications: notifications.stream,
      userIdLoader: () async => userId,
    );
    addTearDown(notifier.dispose);

    await notifier.bind();

    expect(sent.single, WatchBindProtocol.buildLoginRequest(userId));
  });
}

Uint8List _bindResponse(int key, int status) => Uint8List.fromList([
      0x03,
      0x00,
      key,
      0x00,
      0x01,
      status,
    ]);
