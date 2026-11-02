import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  group('WSConfig', () {
    test('link defaults follow the design doc', () {
      final link = const WSConfig().link;
      expect(link.ackTimeout, const Duration(seconds: 5));
      expect(link.maxRetries, 3);
      expect(link.chunkWriteTimeout, const Duration(seconds: 3));
      expect(const WSConfig().session.replyTimeout, const Duration(seconds: 5));
      expect(link.rxAssembleTimeout, const Duration(seconds: 5));
      expect(const WSConfig().session.queueCapacity, 64);
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

  test('simulation lab opens language exchange on watch.debug', () async {
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
    );
    await watch.openSimulationLab();
    expect(watch.isSimulationLabOpen, isTrue);
    await watch.labSetLanguage(9);
    expect(await watch.labGetLanguage(), 9);
    await watch.closeSimulationLab();
    expect(watch.isSimulationLabOpen, isFalse);
    await watch.dispose();
  });

  test('lab APIs fail when lab is closed', () async {
    final watch = WSWatch(config: const WSConfig(simulationEnabled: true));
    await expectLater(
      watch.labGetLanguage(),
      throwsA(isA<WSSessionInvalidatedException>()),
    );
    await watch.dispose();
  });

  test('GATT UUIDs match HoneyProtocol BLE UART Profile', () {
    expect(WSGattProfile.service, '6e400001-b5a3-f393-e0a9-e50e24dcca9e');
    expect(WSGattProfile.write, '6e400002-b5a3-f393-e0a9-e50e24dcca9e');
    expect(WSGattProfile.notify, '6e400003-b5a3-f393-e0a9-e50e24dcca9e');
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
