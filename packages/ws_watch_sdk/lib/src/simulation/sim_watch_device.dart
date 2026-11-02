import 'dart:async';
import 'dart:typed_data';

import '../config.dart';
import '../link/link.dart';
import '../protocol/address.dart';
import '../protocol/message.dart';
import 'sim_watch_session.dart';

/// M2 device subset. Authentication and historical storage arrive in M3/M5.
class SimWatchDevice {
  SimWatchDevice(this.transport,
      {WSLinkConfig linkConfig = const WSLinkConfig()})
      : link = WSLink(transport, config: linkConfig) {
    unawaited(link.terminated.then((_) {
      _cancelDelays();
    }));
    _subscription = link.payloads.listen((payload) {
      try {
        for (final message
            in WSMessage.decode(payload.bytes, WSWireDirection.phoneToDevice)) {
          final a = message.address;
          if (a.cmd != 2 || a.version != 0 || a.key != 3) continue;
          if (a.settingOpcode == 0 && message.data.length == 1) {
            language = message.data[0];
            unawaited(notifyLanguage(language).catchError((Object _) {}));
          } else if (a.settingOpcode == 1 && message.data.isEmpty) {
            if (!suppressReplies) unawaited(_reply().catchError((Object _) {}));
          }
        }
      } catch (_) {
        /* Unknown/malformed commands have no fabricated L2 reply. */
      }
    });
  }
  final SimWatchSession transport;
  final WSLink link;
  late final StreamSubscription<WSReceivedPayload> _subscription;
  int language = 1;
  bool suppressReplies = false;
  Duration replyDelay = Duration.zero;
  final Set<Timer> _timers = {};
  final Set<Completer<void>> _delays = {};
  bool _disposed = false;
  Future<void> _reply() async {
    if (replyDelay > Duration.zero) {
      final done = Completer<void>();
      _delays.add(done);
      late final Timer timer;
      timer = Timer(replyDelay, () {
        _timers.remove(timer);
        _delays.remove(done);
        done.complete();
      });
      _timers.add(timer);
      await done.future;
    }
    if (_disposed || link.isClosed) return;
    await _sendLanguage(2, language);
  }

  Future<void> notifyLanguage(int value) => _sendLanguage(3, value);
  Future<void> _sendLanguage(int opcode, int value) => link.send(WSMessage(
      WSProtocolAddress(
          cmd: 2,
          version: 0,
          key: 3,
          settingOpcode: opcode,
          direction: WSWireDirection.deviceToPhone),
      Uint8List.fromList([value])).encode());
  void _cancelDelays() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final done in _delays) {
      if (!done.isCompleted) done.complete();
    }
    _delays.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelDelays();
    await _subscription.cancel();
    await link.close();
  }
}
