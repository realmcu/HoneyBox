import '../honey/honey_l2.dart';
import 'ws_history_models.dart';
import 'honey_health_codecs.dart';

/// Decodes `0x23` payloads from [HoneyProtocol 0x05-data.rst] (5B records).
abstract final class HoneyHeartRateCodec {
  static List<WSHeartRate> decodeDataFrame(HoneyL2Message frame) {
    return HoneyHealthCodecs.decodeHeartRateDataFrame(frame);
  }
}
