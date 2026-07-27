import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/watch_bind_provider.dart';

void main() {
  late StreamController<Uint8List> notifications;
  late List<Uint8List> sent;

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
  }) {
    return WatchBindNotifier(
      commandAvailable: () => available,
      sendCommand: send ??
          (frame) {
            sent.add(Uint8List.fromList(frame));
            return 7;
          },
      notifications: notifications.stream,
      userId: Uint8List.fromList(List<int>.generate(32, (i) => i)),
      timeout: timeout,
    );
  }

  test('starts unavailable and does not send without a command channel', () {
    final notifier = createNotifier(available: false);
    addTearDown(notifier.dispose);

    notifier.bind();

    expect(notifier.state.phase, WatchBindPhase.unavailable);
    expect(sent, isEmpty);
  });

  test('sends one request and ignores a duplicate bind call', () {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);

    notifier.bind();
    notifier.bind();

    expect(notifier.state.phase, WatchBindPhase.binding);
    expect(sent, hasLength(1));
    expect(sent.single.sublist(0, 5), [0x03, 0x00, 0x01, 0x00, 0x20]);
  });

  test('ignores unrelated notifications then accepts a success response',
      () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(Uint8List.fromList([0x0D, 0x00, 0x02, 0x00, 0x01, 0x00]));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.phase, WatchBindPhase.binding);

    notifications.add(Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x00]));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.success);
    expect(notifier.state.message, '设备绑定成功');
  });

  test('maps a nonzero device response to a retryable failure', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    notifications.add(Uint8List.fromList([0x03, 0x00, 0x02, 0x00, 0x01, 0x01]));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.phase, WatchBindPhase.failure);
    expect(notifier.state.message, '设备绑定失败');
  });

  test('times out while waiting for a response and permits retry', () async {
    final notifier = createNotifier();
    addTearDown(notifier.dispose);
    notifier.bind();

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(notifier.state.phase, WatchBindPhase.failure);
    expect(notifier.state.message, '等待设备响应超时');

    notifier.bind();
    expect(notifier.state.phase, WatchBindPhase.binding);
    expect(sent, hasLength(2));
  });

  test('becomes unavailable when sendCommand returns null', () {
    final notifier = createNotifier(send: (_) => null);
    addTearDown(notifier.dispose);

    notifier.bind();

    expect(notifier.state.phase, WatchBindPhase.unavailable);
  });
}
