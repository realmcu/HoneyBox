import 'dart:typed_data';

import '../wire/ws_data_command.dart';
import '../wire/ws_l2_message.dart';

/// One unsolicited `0x05` field observed during [WSWatchSession.syncHealthData].
final class WSHistorySyncFrame {
  const WSHistorySyncFrame({required this.key, required this.value});

  final int key;
  final Uint8List value;

  WSL2Message toMessage() => WSL2Message(
        command: WSDataCommand.command,
        version: WSDataCommand.version,
        key: key,
        value: Uint8List.fromList(value),
      );
}
