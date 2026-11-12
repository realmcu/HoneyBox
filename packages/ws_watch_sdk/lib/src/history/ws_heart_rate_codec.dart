import '../wire/ws_l2_message.dart';
import 'ws_history_models.dart';
import 'ws_health_codecs.dart';

/// Decodes `0x23` payloads from [WS protocol 0x05-data.rst] (5B records).
abstract final class WSHeartRateCodec {
  static List<WSHeartRate> decodeDataFrame(WSL2Message frame) {
    return WSHealthCodecs.decodeHeartRateDataFrame(frame);
  }
}
