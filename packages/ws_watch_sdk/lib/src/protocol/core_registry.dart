import 'dart:typed_data';
import '../model/device_info.dart';
import '../model/wall_clock.dart';
import 'cmd_02_settings.dart';
import 'cmd_03_bind.dart';
import 'cmd_05_history.dart';
import 'protocol.dart';
import 'registry.dart';

abstract final class WSInitializationProtocol {
  static final setSystemEntry =
      WSSettingsProtocol.entry(2, 0, 'setPhoneSystem');
  static final setTimeEntry = WSSettingsProtocol.timeEntry;
  static final system = WSCommand<int>(
      request: setSystemEntry,
      encodeData: (v) {
        if (v != 1 && v != 2) {
          throw ArgumentError('phoneSystem must be iOS=1 or Android=2');
        }
        return Uint8List.fromList([v]);
      });
  static final time = WSCommand<DateTime>(
      request: setTimeEntry,
      encodeData: (time) {
        return WSWallClock.fromCalendar(time).encode();
      });
  static final infoRequest = WSSettingsProtocol.entry(0x30, 1, 'getDeviceInfo');
  static final infoReply = WSSettingsProtocol.entry(0x30, 2, 'deviceInfoReply');
  static final infoNotify =
      WSSettingsProtocol.entry(0x30, 3, 'deviceInfoNotification');
  static final capabilityRequest =
      WSSettingsProtocol.entry(0x31, 1, 'getCapabilities');
  static final capabilityReply =
      WSSettingsProtocol.entry(0x31, 2, 'capabilitiesReply');
  static final capabilityNotify =
      WSSettingsProtocol.entry(0x31, 3, 'capabilitiesNotification');
  static final info = WSQuery<void, WSDeviceInfo>(
      request: infoRequest,
      reply: infoReply,
      encodeData: (_) => Uint8List(0),
      decodeData: WSDeviceInfo.fromBytes);
  static Uint8List decodeCapabilities(Uint8List bytes) {
    if (bytes.length != 16) {
      throw const FormatException('capabilities require 16 bytes');
    }
    return bytes;
  }

  static final capabilities = WSQuery<void, Uint8List>(
      request: capabilityRequest,
      reply: capabilityReply,
      encodeData: (_) => Uint8List(0),
      decodeData: decodeCapabilities);
  static WSProtocolRegistry registry() {
    final language = WSSettingsProtocol.registry();
    return WSProtocolRegistry([
      ...language.entries,
      ...WSSettingsProtocol.m4Entries,
      ...WSBindProtocol.entries,
      ...WSHistoryProtocol.entries,
      setSystemEntry,
      setTimeEntry,
      infoRequest,
      infoReply,
      infoNotify,
      capabilityRequest,
      capabilityReply,
      capabilityNotify
    ], reports: [
      ...WSSettingsProtocol.m4Reports,
      ...WSHistoryProtocol.reports,
      WSReport<int>(
          entry: WSSettingsProtocol.languageNotify,
          decodeData: WSSettingsProtocol.decodeLanguage),
      WSReport<WSDeviceInfo>(
          entry: infoNotify, decodeData: WSDeviceInfo.fromBytes),
      WSReport<Uint8List>(
          entry: capabilityNotify, decodeData: decodeCapabilities),
    ]);
  }
}
