import 'dart:async';

import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import '../control/jw_control_protocol.dart';
import 'jw_measure_codec.dart';
import 'jw_measure_config_cache.dart';
import 'jw_measure_protocol.dart';

/// Merges unsolicited measure-related payloads into [JWMeasureConfigCache].
final class JWMeasureConfigIngest {
  JWMeasureConfigIngest({
    required JWLink link,
    required JWMeasureConfigCache cache,
  })  : _link = link,
        _cache = cache;

  final JWLink _link;
  final JWMeasureConfigCache _cache;
  StreamSubscription<JWProtocolMessage>? _events;

  void start() {
    if (_events != null) return;
    _events = _link.events.listen(_onMessage);
  }

  void stop() {
    unawaited(_events?.cancel());
    _events = null;
  }

  void _onMessage(JWProtocolMessage message) {
    if (message.command == JWMeasureProtocol.sportCommand) {
      if (message.key == JWMeasureProtocol.heartRateAutoMeasureRspKey) {
        _cache.setHeartRateAutoMeasure(decodeAutoMeasureConfig(message.value));
        return;
      }
      if (message.key == JWMeasureProtocol.heartRateIntervalOptionsRspKey) {
        _cache.setHeartRateIntervalOptions(
            decodeHeartRateIntervalOptions(message.value));
        return;
      }
    }
    if (message.command == JWControlProtocol.command &&
        message.key == JWMeasureProtocol.deviceSyncSwitchRspKey) {
      for (final item in decodeDeviceSyncSwitchItems(message.value)) {
        if (item.type == _kSyncSwitchHeartRateAutoMeasure) {
          _cache.mergeHeartRateAutoEnabled(item.value == 1);
        }
      }
    }
  }
}

const _kSyncSwitchHeartRateAutoMeasure = 2;
