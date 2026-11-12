import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/simulation/ws_sim_fixtures.dart';

int _indexOfSublist(Uint8List haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

void main() {
  test('liveBytes shifts record times near now', () {
    final anchor = DateTime(2026, 3, 15, 12, 0);
    final epochs = WsSimFixtures.liveEpochSeconds(now: anchor);
    final frame =
        WsSimFixtures.liveBytes(WsSimFixtures.dataHeartRate, now: anchor);
    expect(frame.length, greaterThanOrEqualTo(8));
    final t0 = frame[3] | (frame[4] << 8) | (frame[5] << 16) | (frame[6] << 24);
    expect(t0, epochs.older);
    expect(epochs.older, lessThan(anchor.millisecondsSinceEpoch ~/ 1000));
  });

  test('full sync plan keeps sleep slot with count 0', () {
    expect(WsSimFixtures.includeSleepInFullSync, isFalse);
    expect(WsSimFixtures.totalWireRecords, 17);
    final start = WsSimFixtures.syncStartMulti();
    expect(start.length % 3, 0);
    expect(start.length, 30);
    expect(start.sublist(0, 3), [0x01, 0x00, 0x02]);
    expect(start.sublist(3, 6), [0x02, 0x00, 0x00]);
    expect(start.sublist(6, 9), [0x03, 0x00, 0x02]);
    expect(
      _indexOfSublist(start, [0x01, 0x00, 0x02, 0x00, 0x02]),
      -1,
      reason: 'sleep count 0 must not duplicate next type as orphan bytes',
    );
  });
}
