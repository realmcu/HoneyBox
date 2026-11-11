import 'dart:async';

import '../honey/honey_data.dart';
import '../honey/honey_l2.dart';
import '../connection/ws_link.dart';
import '../model/ws_heart_rate.dart';
import 'honey_heart_rate_codec.dart';

abstract final class WSHistorySync {
  /// Single-type heart rate pull (`0x05` sync key `0x03`).
  static Future<List<WSHeartRate>> syncHeartRate(WSLink link) async {
    final collected = <WSHeartRate>[];
    final done = Completer<void>();
    late final StreamSubscription<HoneyL2Message> sub;
    sub = link.incoming.listen((message) {
      if (message.command != HoneyDataCommand.command ||
          message.version != HoneyDataCommand.version) {
        return;
      }
      if (message.key == HoneyDataCommand.keyDataHeartRate) {
        collected.addAll(HoneyHeartRateCodec.decodeDataFrame(message));
      } else if (message.key == HoneyDataCommand.keySyncEnd) {
        if (!done.isCompleted) done.complete();
      }
    });
    try {
      await link.send(HoneyDataCommand.syncRequest(HoneyDataCommand.keySyncHeartRate));
      await done.future.timeout(const Duration(seconds: 10));
      await link.send(HoneyDataCommand.syncConfirm());
      return collected;
    } finally {
      await sub.cancel();
    }
  }
}
