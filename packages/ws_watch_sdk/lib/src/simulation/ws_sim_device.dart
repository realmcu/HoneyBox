import 'dart:async';
import 'dart:typed_data';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../honey/honey_bind.dart';
import '../honey/honey_control.dart';
import '../honey/honey_data.dart';
import '../honey/honey_device.dart';
import '../honey/honey_l2.dart';
import '../honey/honey_measure.dart';
import '../honey/honey_settings.dart';
import '../honey/honey_today.dart';
import 'ws_sim_constants.dart';
import 'ws_sim_fixtures.dart';
import 'ws_sim_state.dart';

WatchSimulationDevice wsSimWatchDevice({
  required WsSimWatchState state,
  String id = kWsWatchSimDeviceId,
  String name = 'WS Watch Simulator',
  int maxWriteLength = 244,
}) {
  return WatchSimulationDevice(
    id: id,
    name: name,
    maxWriteLength: maxWriteLength,
    attach: (peer) => _attach(peer, state),
  );
}

WatchSimulationDeviceSession _attach(
  WatchSimulationConnection peer,
  WsSimWatchState state,
) {
  final channel = WatchFrameChannel(
    WatchFramePort.fromConnection(peer),
    profile: WatchFrameProfile.ws,
    config: const WatchFrameConfig(
      ackTimeout: Duration(seconds: 5),
      maxRetries: 2,
      maxPayloadLength: 65535,
    ),
  );
  final subscription = channel.payloads.listen((payload) {
    try {
      final messages = HoneyL2Message.decodeAll(payload.bytes);
      for (final message in messages) {
        switch (message.command) {
          case HoneyBindCommand.command:
            _handleBind(channel, state, message);
          case HoneySettingsCommand.command:
            _handleSettings(channel, state, message);
          case HoneyDataCommand.command:
            unawaited(_handleData(channel, state, message));
          case HoneyMeasureCommand.command:
            _handleMeasure(channel, state, message);
          case HoneyControlCommand.command:
            _handleControl(channel, state, message);
        }
      }
    } on FormatException {
      // Malformed L2 — no fabricated reply.
    }
  });
  return WatchSimulationDeviceSession(dispose: () async {
    await subscription.cancel();
    await channel.close(StateError('sim device detached'));
  });
}

void _handleBind(
  WatchFrameChannel channel,
  WsSimWatchState state,
  HoneyL2Message message,
) {
  switch (message.key) {
    case HoneyBindCommand.keyLoginRequest:
      final user = HoneyBindCommand.decodeUserIdWire(message.value);
      final result = state.boundUserId == user ? 0 : 1;
      unawaited(channel.send(_bindReply(HoneyBindCommand.keyLoginReply, result)));
    case HoneyBindCommand.keyBindRequest:
      final user = HoneyBindCommand.decodeUserIdWire(message.value);
      state.boundUserId = user;
      unawaited(channel.send(_bindReply(HoneyBindCommand.keyBindReply, 0)));
    case HoneyBindCommand.keyUnbind:
      state.boundUserId = null;
  }
}

void _handleSettings(
  WatchFrameChannel channel,
  WsSimWatchState state,
  HoneyL2Message message,
) {
  if (message.value.isEmpty) return;
  final opcode = message.value[0];
  switch (message.key) {
    case HoneySettingsCommand.keyPhoneSystem:
      if (opcode == HoneySettingsCommand.opcodeSet && message.value.length >= 2) {
        state.phoneSystem = message.value[1];
      }
    case HoneySettingsCommand.keyLanguage:
      if (opcode == HoneySettingsCommand.opcodeSet && message.value.length >= 2) {
        state.language = message.value[1];
      } else if (opcode == HoneySettingsCommand.opcodeRead) {
        unawaited(channel.send(HoneyL2Message(
          command: HoneySettingsCommand.command,
          version: HoneySettingsCommand.version,
          key: HoneySettingsCommand.keyLanguage,
          value: Uint8List.fromList([
            HoneySettingsCommand.opcodeReadReply,
            state.language,
          ]),
        ).encode()));
      }
    case HoneySettingsCommand.keyTime:
      break;
    case HoneyDeviceCommand.keyDeviceInfo:
      if (opcode == HoneySettingsCommand.opcodeRead) {
        unawaited(channel.send(_deviceInfoReply()));
      }
    case HoneyDeviceCommand.keyCapabilities:
      if (opcode == HoneySettingsCommand.opcodeRead) {
        unawaited(channel.send(_capabilitiesReply()));
      }
  }
}

void _handleMeasure(
  WatchFrameChannel channel,
  WsSimWatchState state,
  HoneyL2Message message,
) {
  switch (message.key) {
    case HoneyMeasureCommand.keyStartHeartRate:
      final result = state.heartRateSpotActive ? 0x01 : 0x00;
      if (result == 0x00) state.heartRateSpotActive = true;
      unawaited(channel.send(_measureMessage(
        HoneyMeasureCommand.keyStartHeartRateReply,
        Uint8List.fromList([result]),
      )));
    case HoneyMeasureCommand.keyStopHeartRate:
      state.heartRateSpotActive = false;
  }
}

void _handleControl(
  WatchFrameChannel channel,
  WsSimWatchState state,
  HoneyL2Message message,
) {
  if (message.key == HoneyControlCommand.keyBatteryQuery) {
    unawaited(channel.send(_controlMessage(
      HoneyControlCommand.keyBatteryReply,
      Uint8List.fromList([state.batteryPercent, state.batteryCharging]),
    )));
  }
}

Future<void> _handleData(
  WatchFrameChannel channel,
  WsSimWatchState state,
  HoneyL2Message message,
) async {
  if (message.version != HoneyDataCommand.version) return;
  if (message.key == HoneyDataCommand.keySyncConfirm) return;

  if (message.key == HoneyTodayCommand.keyQuery) {
    await channel.send(_dataMessage(
      HoneyTodayCommand.keyTodayPayload,
      WsSimFixtures.reanchorToToday(state.todayPayload),
    ));
    return;
  }

  if (state.historyBusy &&
      message.key <= HoneyDataCommand.keySyncSport &&
      message.value.isEmpty) {
    await channel.send(_dataMessage(
      HoneyDataCommand.keySyncEnd,
      Uint8List.fromList([0x02, 0, 0, 0, 0]),
    ));
    return;
  }

  final isSyncRequest =
      message.key <= HoneyDataCommand.keySyncSport && message.value.isEmpty;
  if (!isSyncRequest) return;

  state.historyBusy = true;
  try {
    if (message.key == HoneyDataCommand.keySyncAll) {
      await _pushFullSnapshot(channel);
    } else {
      await _pushSingleType(channel, message.key);
    }
  } finally {
    state.historyBusy = false;
  }
}

Future<void> _pushFullSnapshot(WatchFrameChannel channel) async {
  await channel.send(_dataMessage(
    HoneyDataCommand.keySyncStart,
    WsSimFixtures.syncStartMulti(),
  ));
  final pairs = <(int, Uint8List)>[
    (HoneyDataCommand.keyDataActivity, WsSimFixtures.bytes(WsSimFixtures.dataActivity)),
    (HoneyDataCommand.keyDataSleep, WsSimFixtures.bytes(WsSimFixtures.dataSleep)),
    (HoneyDataCommand.keyDataHeartRate, WsSimFixtures.bytes(WsSimFixtures.dataHeartRate)),
    (HoneyDataCommand.keyDataBloodPressure, WsSimFixtures.bytes(WsSimFixtures.dataBloodPressure)),
    (HoneyDataCommand.keyDataBloodOxygen, WsSimFixtures.bytes(WsSimFixtures.dataBloodOxygen)),
    (HoneyDataCommand.keyDataHrv, WsSimFixtures.bytes(WsSimFixtures.dataHrv)),
    (HoneyDataCommand.keyDataPressure, WsSimFixtures.bytes(WsSimFixtures.dataPressure)),
    (HoneyDataCommand.keyDataTemperature, WsSimFixtures.bytes(WsSimFixtures.dataTemperature)),
    (HoneyDataCommand.keyDataBloodGlucose, WsSimFixtures.bytes(WsSimFixtures.dataBloodGlucose)),
    (HoneyDataCommand.keyDataSport, WsSimFixtures.bytes(WsSimFixtures.dataSport)),
  ];
  for (final p in pairs) {
    await channel.send(_dataMessage(p.$1, p.$2));
  }
  final total = WsSimFixtures.totalWireRecords;
  await channel.send(_dataMessage(
    HoneyDataCommand.keySyncEnd,
    Uint8List.fromList([0x00, 0, 0, 0, total]),
  ));
}

Future<void> _pushSingleType(WatchFrameChannel channel, int syncKey) async {
  const count = 2;
  await channel.send(_dataMessage(
    HoneyDataCommand.keySyncStart,
    Uint8List.fromList([syncKey, 0, count]),
  ));
  final dataKey = syncKey + 0x20;
  final value = switch (syncKey) {
    HoneyDataCommand.keySyncActivity => WsSimFixtures.bytes(WsSimFixtures.dataActivity),
    HoneyDataCommand.keySyncSleep => WsSimFixtures.bytes(WsSimFixtures.dataSleep),
    HoneyDataCommand.keySyncHeartRate => WsSimFixtures.bytes(WsSimFixtures.dataHeartRate),
    HoneyDataCommand.keySyncBloodPressure =>
      WsSimFixtures.bytes(WsSimFixtures.dataBloodPressure),
    HoneyDataCommand.keySyncBloodOxygen =>
      WsSimFixtures.bytes(WsSimFixtures.dataBloodOxygen),
    HoneyDataCommand.keySyncHrv => WsSimFixtures.bytes(WsSimFixtures.dataHrv),
    HoneyDataCommand.keySyncPressure => WsSimFixtures.bytes(WsSimFixtures.dataPressure),
    HoneyDataCommand.keySyncTemperature =>
      WsSimFixtures.bytes(WsSimFixtures.dataTemperature),
    HoneyDataCommand.keySyncBloodGlucose =>
      WsSimFixtures.bytes(WsSimFixtures.dataBloodGlucose),
    HoneyDataCommand.keySyncSport => WsSimFixtures.bytes(WsSimFixtures.dataSport),
    _ => Uint8List(0),
  };
  if (value.isNotEmpty) {
    await channel.send(_dataMessage(dataKey, value));
  }
  await channel.send(_dataMessage(
    HoneyDataCommand.keySyncEnd,
    Uint8List.fromList([0x00, 0, 0, 0, count]),
  ));
}

Uint8List _bindReply(int key, int resultByte) => HoneyL2Message(
      command: HoneyBindCommand.command,
      version: HoneyBindCommand.version,
      key: key,
      value: Uint8List.fromList([resultByte]),
    ).encode();

Uint8List _dataMessage(int key, Uint8List value) => HoneyL2Message(
      command: HoneyDataCommand.command,
      version: HoneyDataCommand.version,
      key: key,
      value: value,
    ).encode();

Uint8List _measureMessage(int key, Uint8List value) => HoneyL2Message(
      command: HoneyMeasureCommand.command,
      version: HoneyMeasureCommand.version,
      key: key,
      value: value,
    ).encode();

Uint8List _controlMessage(int key, Uint8List value) => HoneyL2Message(
      command: HoneyControlCommand.command,
      version: HoneyControlCommand.version,
      key: key,
      value: value,
    ).encode();

/// Minimal device-info read reply from HoneyProtocol `0x02` `0x30` example.
Uint8List _deviceInfoReply() {
  final serial = 'WS2026000001';
  final mac = Uint8List.fromList([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
  final body = <int>[
    HoneySettingsCommand.opcodeReadReply,
    0x00,
    0x01,
    0x01,
    0x02,
    0x03,
    0x00,
    0x64,
    0x01,
    0x01,
    0x01,
    ...mac,
    serial.length,
    ...serial.codeUnits,
  ];
  return HoneyL2Message(
    command: HoneyDeviceCommand.command,
    version: HoneyDeviceCommand.version,
    key: HoneyDeviceCommand.keyDeviceInfo,
    value: Uint8List.fromList(body),
  ).encode();
}

Uint8List _capabilitiesReply() => HoneyL2Message(
      command: HoneyDeviceCommand.command,
      version: HoneyDeviceCommand.version,
      key: HoneyDeviceCommand.keyCapabilities,
      value: Uint8List.fromList([
        HoneySettingsCommand.opcodeReadReply,
        ...List<int>.filled(HoneyDeviceCommand.capabilitiesBlobLength, 0),
      ]),
    ).encode();
