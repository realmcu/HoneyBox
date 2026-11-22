import 'dart:typed_data';

import '../notification/ws_notification_models.dart';
import 'ws_binary.dart';
import 'ws_l2_message.dart';

/// Full command `0x04` notification codec.
abstract final class WSNotificationCommand {
  static const int command = 0x04;
  static const int version = 0;

  static const int keyIncomingCall = 0x01;
  static const int keyCallState = 0x02;
  static const int keyCallAction = 0x03;
  static const int keyMessage = 0x10;
  static const int keyDeleteMessage = 0x11;
  static const int keyClearMessages = 0x12;
  static const int keyMusicState = 0x20;
  static const int keyMusicControl = 0x21;
  static const int keyMusicStateRequest = 0x22;
  static const int keyFindWatch = 0x30;
  static const int keyFindWatchEnded = 0x31;
  static const int keyFindPhone = 0x32;
  static const int keyFindPhoneEnded = 0x33;
  static const int keyCameraState = 0x40;
  static const int keyCameraShutter = 0x41;
  static const int keyBatteryQuery = 0x50;
  static const int keyBattery = 0x51;

  static WSL2Message _message(int key, List<int> value) => WSL2Message(
        command: command,
        version: version,
        key: key,
        value: Uint8List.fromList(value),
      );

  static WSL2Message incomingCall(WSIncomingCall call) {
    final number = WSBinary.utf8Bytes(call.number, maxBytes: 255);
    final name = WSBinary.utf8Bytes(call.name, maxBytes: 255);
    return _message(
        keyIncomingCall, [number.length, ...number, name.length, ...name]);
  }

  static WSL2Message callState(int state) {
    WSBinary.requireRange(state, 0, 2, 'state');
    return _message(keyCallState, [state]);
  }

  static WSL2Message appNotification(WSAppNotification item) {
    WSBinary.requireRange(item.applicationType, 0, 0x7e, 'applicationType');
    final title = WSBinary.utf8Bytes(item.title, maxBytes: 255);
    final content = WSBinary.utf8Bytes(item.content, maxBytes: 65535);
    return _message(keyMessage, [
      ...WSBinary.u32(item.id),
      item.applicationType,
      ...WSBinary.u32(item.wallTimeSeconds),
      title.length,
      ...title,
      ...WSBinary.u16(content.length),
      ...content,
    ]);
  }

  static WSL2Message deleteMessage(int id) =>
      _message(keyDeleteMessage, WSBinary.u32(id));

  static WSL2Message clearMessages() => _message(keyClearMessages, const []);

  static WSL2Message musicState(WSMusicState state) {
    WSBinary.requireRange(state.playbackState, 0, 2, 'playbackState');
    WSBinary.requireRange(state.volumePercent, 0, 100, 'volumePercent');
    final song = WSBinary.utf8Bytes(state.song, maxBytes: 255);
    final artist = WSBinary.utf8Bytes(state.artist, maxBytes: 255);
    return _message(keyMusicState, [
      state.playbackState,
      state.volumePercent,
      song.length,
      ...song,
      artist.length,
      ...artist,
    ]);
  }

  static WSL2Message findWatch(bool start) =>
      _message(keyFindWatch, [start ? 1 : 0]);

  static WSL2Message findPhoneEnded(int reason) {
    WSBinary.requireRange(reason, 0, 1, 'reason');
    return _message(keyFindPhoneEnded, [reason]);
  }

  static WSL2Message cameraState(bool open) =>
      _message(keyCameraState, [open ? 1 : 0]);

  static WSL2Message batteryQuery() => _message(keyBatteryQuery, const []);

  static WSBatteryStatus decodeBattery(Uint8List value) {
    WSBinary.requireLength(value, 2, 'battery');
    WSBinary.requireRange(value[0], 0, 100, 'percent');
    WSBinary.requireRange(value[1], 0, 2, 'chargingState');
    return WSBatteryStatus(percent: value[0], chargingState: value[1]);
  }

  static WSNotificationEvent? decodeEvent(WSL2Message message) {
    if (message.command != command || message.version != version) return null;
    final value = message.value;
    return switch (message.key) {
      keyCallAction when value.isNotEmpty => WSCallActionEvent(value[0]),
      keyMusicControl when value.isNotEmpty => WSMusicControlEvent(value[0]),
      keyMusicStateRequest => const WSMusicStateRequestedEvent(),
      keyFindWatchEnded when value.isNotEmpty =>
        WSFindWatchEndedEvent(value[0]),
      keyFindPhone when value.isNotEmpty => WSFindPhoneEvent(value[0] == 1),
      keyCameraShutter => const WSCameraShutterEvent(),
      keyBattery => WSBatteryEvent(decodeBattery(value)),
      _ => null,
    };
  }
}
