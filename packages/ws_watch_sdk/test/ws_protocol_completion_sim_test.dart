import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completed protocol surfaces work end-to-end on simulator', () async {
    const userId = '0123456789abcdef0123456789abcdef';
    final store = await WSHistoryStore.open(databasePath: 'test');
    final watch = WSWatch(
      config: const WSConfig.simulation(),
      historyStore: store,
    );
    await watch.initialize();
    final session = watch.createSession(kWsWatchSimDeviceId);
    try {
      await session.connect();
      await session.superBind(userId, 'super-key', confirmed: true);
      expect(session.state.isReady, isTrue);
      expect(session.state.device?.serialNumber, 'WS2026000001');

      const display = WSDisplayFormat(
        hour12: true,
        dayFirst: true,
        imperialDistance: false,
        pounds: false,
      );
      await session.settings.setDisplayFormat(display);
      final readDisplay = await session.settings.readDisplayFormat();
      expect(readDisplay.hour12, isTrue);
      expect(readDisplay.dayFirst, isTrue);

      const heartSchedule = WSAutoMeasureSchedule(
        enabled: true,
        startHour: 8,
        startMinute: 30,
        endHour: 22,
        endMinute: 15,
        intervalMinutes: 10,
      );
      await session.measure.setHeartRateAutoMeasureSchedule(heartSchedule);
      final readHeartSchedule =
          await session.measure.readHeartRateAutoMeasureSchedule();
      expect(readHeartSchedule.startHour, 8);
      expect(readHeartSchedule.endMinute, 15);

      await session.settings.setBloodPressureUnit(WSBloodPressureUnit.kPa);
      expect(await session.settings.readBloodPressureUnit(),
          WSBloodPressureUnit.kPa);

      const alarm = WSAlarmSetting(
        slot: 0,
        enabled: true,
        hour: 7,
        minute: 30,
        repeatBits: 0x1f,
        label: 'wake',
      );
      await session.settings.addAlarm(alarm);
      final alarms = await session.settings.readAlarms();
      expect(alarms.items.single.label, 'wake');

      final battery = await session.notifications.queryBattery();
      expect(battery.percent, 75);

      final capabilities = await session.history.queryDeviceDataCapabilities();
      expect(capabilities.displayWidth, 410);

      const todayConfig = WSTodayNotificationConfig(
        enabled: true,
        startHour: 0,
        startMinute: 0,
        endHour: 0,
        endMinute: 0,
        intervalMinutes: 1,
      );
      final configResult =
          await session.today.setNotificationConfig(todayConfig);
      expect(configResult.isSuccess, isTrue);

      final detail = await session.history.fetchSportDetail(42);
      expect(detail.sportId, 42);
      expect(detail.points, hasLength(1));

      final status = await session.measure.querySpotStatus();
      expect(status.active, isFalse);
      final resultFuture = session.measure.events
          .where((event) => event is WSSpotResultEvent)
          .cast<WSSpotResultEvent>()
          .firstWhere((event) => event.lane.dataTypeCode == 0x06);
      await session.measure.startHrvSpotMeasure();
      final result = await resultFuture;
      expect(result.result, 0);
      expect(result.record, isA<WSHrv>());

      expect(await session.measure.querySportModes(), [1, 2, 3]);
      expect(await session.measure.startSport(1), 0);
      final sportState = await session.measure.querySportState();
      expect(sportState.hasActiveSport, isTrue);
      await session.measure.controlSport(0);
    } finally {
      await session.dispose();
      await watch.dispose();
    }
  });
}
