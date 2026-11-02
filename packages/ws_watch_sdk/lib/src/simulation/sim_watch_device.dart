import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../config.dart';
import '../link/link.dart';
import '../protocol/address.dart';
import '../protocol/message.dart';
import 'sim_watch_session.dart';

/// Physical state outlives a transport connection, just as on a real watch.
class SimWatchState {
  String? boundUserId;
  int? bindResult =
      0; // null: no confirmation, 1: timeout, 2: reject (test-only controls).
  Duration confirmationDelay = const Duration(milliseconds: 300);
  int? failInitializationKey;
  int? phoneSystem;
  Uint8List? timeBytes;
  int language = 1;
  Uint8List displayFormat = Uint8List(4);
  bool emitSettingsNotifications = true;
  bool suppressDisplayReplies = false;
  Duration displayReplyDelay = Duration.zero;
  Uint8List? displayReplyOverride;
  Uint8List? notifyBeforeDisplayReply;
}

/// Simulator supports M2 lab exchange and the M3 authentication handshake.
class SimWatchDevice {
  SimWatchDevice(this.transport,
      {WSLinkConfig linkConfig = const WSLinkConfig(), SimWatchState? state})
      : state = state ?? SimWatchState(),
        link = WSLink(transport, config: linkConfig) {
    unawaited(link.terminated.then((_) {
      _cancelDelays();
    }));
    _subscription = link.payloads.listen((payload) {
      try {
        for (final message
            in WSMessage.decode(payload.bytes, WSWireDirection.phoneToDevice)) {
          final a = message.address;
          if (a.version == 0 && a.cmd == 3) {
            unawaited(_authentication(message).catchError((Object _) {}));
            continue;
          }
          if (a.cmd == 2 && a.version == 0 && a.key == 4) {
            unawaited(_displaySettings(message).catchError((Object _) {}));
            continue;
          }
          if (a.cmd == 2 && a.version == 0 && a.key != 3) {
            unawaited(_initialize(message).catchError((Object _) {}));
            continue;
          }
          if (a.cmd != 2 || a.version != 0 || a.key != 3) continue;
          if (a.settingOpcode == 0 && message.data.length == 1) {
            language = message.data[0];
            if (this.state.emitSettingsNotifications) {
              unawaited(notifyLanguage(language).catchError((Object _) {}));
            }
          } else if (a.settingOpcode == 1 && message.data.isEmpty) {
            if (!suppressReplies) unawaited(_reply().catchError((Object _) {}));
          }
        }
      } catch (_) {
        /* Unknown/malformed commands have no fabricated L2 reply. */
      }
    });
  }
  final SimWatchState state;
  final SimWatchSession transport;
  final WSLink link;
  late final StreamSubscription<WSReceivedPayload> _subscription;
  int get language => state.language;
  set language(int value) => state.language = value;
  bool suppressReplies = false;
  Duration replyDelay = Duration.zero;
  final Set<Timer> _timers = {};
  final Set<Completer<void>> _delays = {};
  bool _disposed = false;
  Future<void> _delay(Duration duration) async {
    final done = Completer<void>();
    _delays.add(done);
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      _delays.remove(done);
      done.complete();
    });
    _timers.add(timer);
    await done.future;
  }

  Future<void> _authentication(WSMessage message) async {
    final key = message.address.key;
    if (key == 5 && message.data.length == 1 && message.data[0] == 0) {
      state.boundUserId = null;
      return;
    }
    if ((key != 1 && key != 3) || message.data.length != 32) return;
    final id = ascii.decode(message.data.takeWhile((b) => b != 0).toList());
    var result = state.boundUserId == id ? 0 : 1;
    if (key == 1) {
      await _delay(state.confirmationDelay);
      if (_disposed || link.isClosed || state.bindResult == null) return;
      result = state.bindResult!;
      if (result == 0) state.boundUserId = id;
    }
    if (_disposed || link.isClosed) return;
    await link.send(WSMessage(
        WSProtocolAddress(
            cmd: 3,
            version: 0,
            key: key == 3 ? 4 : 2,
            direction: WSWireDirection.deviceToPhone),
        [result]).encode());
  }

  Future<void> _initialize(WSMessage message) async {
    final a = message.address;
    if (a.key == state.failInitializationKey) return;
    if (a.settingOpcode == 0) {
      if (a.key == 2 && message.data.length == 1) {
        state.phoneSystem = message.data[0];
      }
      if (a.key == 1 && message.data.length == 4) {
        state.timeBytes = message.data;
        if (state.emitSettingsNotifications) {
          await _sendSetting(1, 3, message.data);
        }
      }
      return;
    }
    if (a.settingOpcode != 1) return;
    final List<int> data;
    if (a.key == 0x31) {
      data = List.filled(16, 0);
    } else if (a.key == 0x30) {
      data = [
        0,
        1,
        1,
        2,
        3,
        0,
        100,
        1,
        1,
        1,
        0x11,
        0x22,
        0x33,
        0x44,
        0x55,
        0x66,
        12,
        ...ascii.encode('WS2026000001')
      ];
    } else {
      return;
    }
    await link.send(WSMessage(
            WSProtocolAddress(
                cmd: 2,
                version: 0,
                key: a.key,
                settingOpcode: 2,
                direction: WSWireDirection.deviceToPhone),
            data)
        .encode());
  }

  Future<void> _displaySettings(WSMessage message) async {
    final a = message.address;
    if (a.settingOpcode == 0 && message.data.length == 4) {
      state.displayFormat = Uint8List.fromList(message.data);
      if (state.emitSettingsNotifications) {
        await notifyDisplayFormat(state.displayFormat);
      }
    } else if (a.settingOpcode == 1 && message.data.isEmpty) {
      if (state.suppressDisplayReplies) return;
      if (state.notifyBeforeDisplayReply != null) {
        await notifyDisplayFormat(state.notifyBeforeDisplayReply!);
      }
      if (state.displayReplyDelay > Duration.zero) {
        await _delay(state.displayReplyDelay);
      }
      if (_disposed || link.isClosed) return;
      await _sendSetting(
          4, 2, state.displayReplyOverride ?? state.displayFormat);
    }
  }

  Future<void> notifyDisplayFormat(List<int> value) =>
      _sendSetting(4, 3, value);
  Future<void> _sendSetting(int key, int opcode, List<int> data) =>
      link.send(WSMessage(
              WSProtocolAddress(
                  cmd: 2,
                  version: 0,
                  key: key,
                  settingOpcode: opcode,
                  direction: WSWireDirection.deviceToPhone),
              data)
          .encode());

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
