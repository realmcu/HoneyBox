import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_demo/src/ws_data_catalog.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  test('jwDataQueryDay uses millisecond bounds for WSHistoryQuery', () async {
    const scope = WSHistoryScope(userId: 'u', deviceMac: 'ws-watch-simulator');
    final store = await WSHistoryStore.open(databasePath: 'test');
  addTearDown(store.dispose);

    final day = DateTime(2026, 11, 10, 15, 30);
    final t = day.millisecondsSinceEpoch;
    await store.writeActivities(scope, [
      WSActivity(
        time: day,
        steps: 100,
        distance: 0,
        energy: 0,
        activeTime: 0,
        mode: 0,
      ),
    ]);

    final rows = await jwDataQueryDay(
      store: store,
      scope: scope,
      id: WsDataTypeId.activity,
      day: day,
    );
    expect(rows, hasLength(1));
    expect((rows.first as WSActivity).steps, 100);

    final miss = await jwDataQueryDay(
      store: store,
      scope: scope,
      id: WsDataTypeId.activity,
      day: day.add(const Duration(days: 1)),
    );
    expect(miss, isEmpty);
  });
}
