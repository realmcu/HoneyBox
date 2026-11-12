import 'dart:async';

import '../wire/ws_data_command.dart';
import '../wire/ws_l2_message.dart';
import '../connection/ws_link.dart';
import '../model/ws_heart_rate.dart';
import 'ws_heart_rate_codec.dart';

abstract final class WSHistorySync {
  /// Single-type heart rate pull (`0x05` sync key `0x03`).
  static Future<List<WSHeartRate>> syncHeartRate(WSLink link) async {
    final collected = <WSHeartRate>[];
    final done = Completer<void>();
    late final StreamSubscription<WSL2Message> sub;
    sub = link.incoming.listen((message) {
      if (message.command != WSDataCommand.command ||
          message.version != WSDataCommand.version) {
        return;
      }
      if (message.key == WSDataCommand.keyDataHeartRate) {
        collected.addAll(WSHeartRateCodec.decodeDataFrame(message));
      } else if (message.key == WSDataCommand.keySyncEnd) {
        if (!done.isCompleted) done.complete();
      }
    });
    try {
      await link.send(WSDataCommand.syncRequest(WSDataCommand.keySyncHeartRate));
      await done.future.timeout(const Duration(seconds: 10));
      await link.send(WSDataCommand.syncConfirm());
      return collected;
    } finally {
      await sub.cancel();
    }
  }
}
