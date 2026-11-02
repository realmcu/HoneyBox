import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  group('WSConfig', () {
    test('link defaults follow the design doc', () {
      final link = const WSConfig().link;
      expect(link.ackTimeout, const Duration(seconds: 5));
      expect(link.maxRetries, 3);
      expect(link.chunkWriteTimeout, const Duration(seconds: 3));
      expect(link.replyTimeout, const Duration(seconds: 5));
      expect(link.rxAssembleTimeout, const Duration(seconds: 5));
      expect(link.queueCapacity, 64);
    });

    test('connect timeouts follow the design doc', () {
      final timeouts = const WSConfig().connectTimeouts;
      expect(timeouts.connecting, const Duration(seconds: 15));
      expect(timeouts.discovering, const Duration(seconds: 10));
      expect(timeouts.awaitingConfirm, const Duration(seconds: 60));
    });

    test('auto reconnect is off by default', () {
      expect(const WSConfig().autoReconnect, isFalse);
    });
  });

  group('WSWatch', () {
    test('starts disconnected', () async {
      final watch = WSWatch();
      expect(watch.state, WSConnectionState.disconnected);
      await watch.dispose();
    });

    test('dispose closes stateChanges and is idempotent', () async {
      final watch = WSWatch();
      final done = expectLater(watch.stateChanges, emitsDone);
      await watch.dispose();
      await watch.dispose();
      expect(watch.isDisposed, isTrue);
      await done;
    });

    test('uses the logger from config', () {
      final logger = _RecordingLogger();
      final watch = WSWatch(config: WSConfig(logger: logger));
      expect(watch.logger, same(logger));
    });
  });

  test('GATT UUIDs match the private protocol service', () {
    expect(WSGattProfile.service, '000001ff-3c17-d293-8e48-14fe2e4da212');
    expect(WSGattProfile.write, '0000ff02-0000-1000-8000-00805f9b34fb');
    expect(WSGattProfile.notify, '0000ff03-0000-1000-8000-00805f9b34fb');
  });
}

class _RecordingLogger implements WSLogger {
  @override
  void log(
    WSLogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
