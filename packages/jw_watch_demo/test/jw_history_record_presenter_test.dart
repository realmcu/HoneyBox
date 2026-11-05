import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_history_record_presenter.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('summarizes activity records', () {
    final record = JWActivity(
      time: DateTime.utc(2026, 1, 2, 3, 4, 5),
      steps: 100,
      distance: 200,
      energy: 30,
      activeTime: 40,
      mode: 1,
    );
    expect(
      jwHistoryRecordSummary(record),
      contains('步数 100'),
    );
    expect(jwHistoryRecordFields(record)['steps'], 100);
  });
}
