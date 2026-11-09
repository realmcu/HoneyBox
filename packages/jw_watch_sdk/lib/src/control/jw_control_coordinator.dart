import 'dart:async';

import 'package:meta/meta.dart';

import '../connection/jw_link.dart';
import '../connection/jw_protocol.dart';
import '../debug/jw_debug_log.dart';
import 'jw_control_listener.dart';
import 'jw_control_protocol.dart';

/// Routes unsolicited `cmd 0x07` payloads to [JWControlListener]s.
final class JWControlCoordinator {
  JWControlCoordinator({required JWLink link}) : _link = link;

  @visibleForTesting
  JWControlCoordinator.testing() : _link = null;

  final JWLink? _link;
  final _listeners = <JWControlListener>{};
  StreamSubscription<JWProtocolMessage>? _events;

  bool get hasListeners => _listeners.isNotEmpty;

  @visibleForTesting
  void handleMessage(JWProtocolMessage message) => _onMessage(message);

  void addListener(JWControlListener listener) {
    _listeners.add(listener);
    _syncSubscription();
  }

  void removeListener(JWControlListener listener) {
    _listeners.remove(listener);
    _syncSubscription();
  }

  void dispose() {
    unawaited(_events?.cancel());
    _events = null;
    _listeners.clear();
  }

  void _syncSubscription() {
    if (_listeners.isEmpty) {
      unawaited(_events?.cancel());
      _events = null;
      return;
    }
    if (_events != null) {
      return;
    }
    final link = _link;
    if (link == null) {
      return;
    }
    _events = link.events.listen(_onMessage);
  }

  void _onMessage(JWProtocolMessage message) {
    if (message.command != JWControlProtocol.command) {
      return;
    }
    if (_listeners.isEmpty) {
      return;
    }
    switch (message.key) {
      case JWControlProtocol.photoRsp:
        JWWatchDebugLog.apiOut('JWControlListener.onTakePhoto', 'key=0x01');
        _dispatch((listener) => listener.onTakePhoto());
      case JWControlProtocol.findPhoneRsp:
        JWWatchDebugLog.apiOut(
            'JWControlListener.onFindPhone', 'legacy key=0x02 enable=true');
        _dispatch((listener) => listener.onFindPhone(enable: true));
      case JWControlProtocol.findPhoneRsp2:
        if (message.value.isEmpty) {
          return;
        }
        final enable = message.value.single == 0x01;
        JWWatchDebugLog.apiOut(
          'JWControlListener.onFindPhone',
          'key=0x1c enable=$enable',
        );
        _dispatch((listener) => listener.onFindPhone(enable: enable));
      case JWControlProtocol.musicControl:
        if (message.value.isEmpty) {
          return;
        }
        final control = message.value.single;
        if (control < 0 || control > 6) {
          return;
        }
        JWWatchDebugLog.apiOut(
            'JWControlListener.onMusicControl', 'control=$control');
        _dispatch((listener) => listener.onMusicControl(control));
      default:
        break;
    }
  }

  void _dispatch(void Function(JWControlListener listener) notify) {
    for (final listener in _listeners) {
      notify(listener);
    }
  }
}
