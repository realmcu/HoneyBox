import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'production simulator and native persistence connect and reconnect',
      (tester) async {
    await tester.runAsync(() async {
      final watch = WSWatch(config: const WSConfig(simulationEnabled: true));
      final readyChanges = watch.stateChanges
          .where((change) => change.current == WSConnectionState.ready)
          .take(2)
          .toList();
      try {
        await watch
            .connect(kWsWatchSimDeviceId)
            .timeout(const Duration(seconds: 25));
        expect(watch.state, WSConnectionState.ready);
        await watch.settings.setTime();
        await watch.settings.getDisplayFormat();
        final result = await watch.data.sync(type: WSHistoryType.steps).result;
        expect(result.status, WSSyncStatus.completed);
        expect(result.progress.committed, 2);
        final query =
            WSRecordQuery(deviceId: kWsWatchSimDeviceId, userId: watch.userId);
        expect(await watch.data.steps.query(query), hasLength(2));
        await watch.disconnect();
        expect(await watch.data.steps.query(query), hasLength(2));
        await watch
            .connect(kWsWatchSimDeviceId)
            .timeout(const Duration(seconds: 25));
        expect(watch.state, WSConnectionState.ready);
        final repeat = await watch.data.sync(type: WSHistoryType.steps).result;
        expect(repeat.progress.duplicates, 2);
        final hr = await watch.data.sync(type: WSHistoryType.heartRate).result;
        expect(hr.status, WSSyncStatus.completed);
        expect((await watch.data.heartRate.query(query)).map((r) => r.bpm),
            [72, 75]);
        await watch.dispose();
        final reopened =
            WSWatch(config: const WSConfig(simulationEnabled: true));
        try {
          expect(await reopened.data.steps.query(query), hasLength(2));
        } finally {
          await reopened.dispose();
        }
        expect(await readyChanges.timeout(const Duration(seconds: 5)),
            hasLength(2));
      } finally {
        await watch.dispose();
      }
    });
  });
}
