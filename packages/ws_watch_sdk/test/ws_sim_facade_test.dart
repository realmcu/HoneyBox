import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  const userId = '0123456789abcdef0123456789abcdef';

  test('sim today query returns protocol example totals', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      final snapshot = await session.today.queryToday();
      expect(snapshot.steps, 0x146E);
      expect(snapshot.distanceMeters, 0x0E42);
      expect(snapshot.recentHeartRateBpm, 0x48);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim device info and capabilities read', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.readDeviceInfo();
      expect(session.state.device?.modelId, 1);
      expect(session.state.device?.serialNumber, 'WS2026000001');
      await session.readDeviceFeatures();
      expect(session.state.capabilities, isNotNull);
      expect(session.state.capabilities!.raw.length, 16);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim battery query', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      expect(await session.control.queryBatteryPercent(), 75);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim heart rate auto measure round-trip', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      const cfg = WSAutoMeasureConfig(enabled: true, intervalMinutes: 10);
      await session.measure.setHeartRateAutoMeasure(cfg);
      final read = await session.measure.readHeartRateAutoMeasure();
      expect(read.enabled, isTrue);
      expect(read.intervalMinutes, 10);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim spo2 spot start succeeds', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      await session.measure.startSpO2SpotMeasure();
      await session.measure.stopSpO2SpotMeasure();
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });

  test('sim heart rate spot start succeeds', () async {
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig(simulationEnabled: true),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.bindFirstTime(userId, confirmed: true);
      await session.measure.startHeartRateSpot();
      await session.measure.stopHeartRateSpot();
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });
}
