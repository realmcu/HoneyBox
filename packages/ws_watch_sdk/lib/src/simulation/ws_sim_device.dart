import 'dart:async';
import 'dart:typed_data';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../wire/ws_bind_command.dart';
import '../wire/ws_control_command.dart';
import '../wire/ws_data_command.dart';
import '../wire/ws_device_command.dart';
import '../wire/ws_l2_message.dart';
import '../wire/ws_health_monitor_codec.dart';
import '../wire/ws_measure_command.dart';
import '../wire/ws_settings_command.dart';
import '../wire/ws_today_codec.dart';
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
      final messages = WSL2Message.decodeAll(payload.bytes);
      for (final message in messages) {
        switch (message.command) {
          case WSBindCommand.command:
            _handleBind(channel, state, message);
          case WSSettingsCommand.command:
            _handleSettings(channel, state, message);
          case WSDataCommand.command:
            _ignoreDetached(_handleData(channel, state, message));
          case WSMeasureCommand.command:
            _handleMeasure(channel, state, message);
          case WSControlCommand.command:
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
  WSL2Message message,
) {
  switch (message.key) {
    case WSBindCommand.keyLoginRequest:
      final user = WSBindCommand.decodeUserIdWire(message.value);
      final result = state.boundUserId == user ? 0 : 1;
      _ignoreDetached(
          channel.send(_bindReply(WSBindCommand.keyLoginReply, result)));
    case WSBindCommand.keyBindRequest:
      final user = WSBindCommand.decodeUserIdWire(message.value);
      state.boundUserId = user;
      _ignoreDetached(channel.send(_bindReply(WSBindCommand.keyBindReply, 0)));
    case WSBindCommand.keyUnbind:
      state.boundUserId = null;
  }
}

void _handleSettings(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message,
) {
  if (message.value.isEmpty) return;
  final opcode = message.value[0];
  switch (message.key) {
    case WSSettingsCommand.keyPhoneSystem:
      if (opcode == WSSettingsCommand.opcodeSet && message.value.length >= 2) {
        state.phoneSystem = message.value[1];
      }
    case WSSettingsCommand.keyLanguage:
      if (opcode == WSSettingsCommand.opcodeSet && message.value.length >= 2) {
        state.language = message.value[1];
      } else if (opcode == WSSettingsCommand.opcodeRead) {
        _ignoreDetached(_sendSettingsRead(
            channel, message.key, Uint8List.fromList([state.language])));
      }
    case WSSettingsCommand.keyTime:
      break;
    case WSHealthMonitorCodec.keyHeartRateAuto:
    case WSHealthMonitorCodec.keyBloodPressureAuto:
    case WSHealthMonitorCodec.keyBloodSugarAuto:
    case WSHealthMonitorCodec.keySpO2Auto:
    case WSHealthMonitorCodec.keyPressureAuto:
    case WSHealthMonitorCodec.keyTemperatureAuto:
    case WSHealthMonitorCodec.keyHeatStressAuto:
      _handleAutoMonitorSetting(channel, state, message);
    case WSHealthMonitorCodec.keyHeartRateAlarm:
      _handleAlarmSetting(
        channel,
        state,
        message,
        getBody: () => state.heartRateAlarmBody,
        setBody: (body) => state.heartRateAlarmBody = body,
      );
    case WSHealthMonitorCodec.keySpO2Alarm:
      _handleAlarmSetting(
        channel,
        state,
        message,
        getBody: () => state.spo2AlarmBody,
        setBody: (body) => state.spo2AlarmBody = body,
      );
    case WSHealthMonitorCodec.keyTemperatureUnit:
      if (opcode == WSSettingsCommand.opcodeSet && message.value.length >= 2) {
        state.temperatureUnitCelsius = message.value[1] == 0x00;
      } else if (opcode == WSSettingsCommand.opcodeRead) {
        _ignoreDetached(_sendSettingsRead(
          channel,
          message.key,
          Uint8List.fromList([state.temperatureUnitCelsius ? 0x00 : 0x01]),
        ));
      }
    case WSDeviceCommand.keyDeviceInfo:
      if (opcode == WSSettingsCommand.opcodeRead) {
        _ignoreDetached(channel.send(_deviceInfoReply()));
      }
    case WSDeviceCommand.keyCapabilities:
      if (opcode == WSSettingsCommand.opcodeRead) {
        _ignoreDetached(channel.send(_capabilitiesReply()));
      }
  }
}

void _handleAutoMonitorSetting(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message,
) {
  final opcode = message.value[0];
  final key = message.key;
  if (opcode == WSSettingsCommand.opcodeSet &&
      message.value.length >= 1 + WSHealthMonitorCodec.autoMonitorBodyLength) {
    state.autoMonitorBodies[key] = Uint8List.fromList(
      message.value.sublist(1, 1 + WSHealthMonitorCodec.autoMonitorBodyLength),
    );
  } else if (opcode == WSSettingsCommand.opcodeRead) {
    final body = state.autoMonitorBodies[key]!;
    _ignoreDetached(_sendSettingsRead(channel, key, body));
  }
}

void _handleAlarmSetting(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message, {
  required Uint8List Function() getBody,
  required void Function(Uint8List body) setBody,
}) {
  final opcode = message.value[0];
  if (opcode == WSSettingsCommand.opcodeSet &&
      message.value.length >= 1 + WSHealthMonitorCodec.alarmBodyLength) {
    setBody(Uint8List.fromList(
      message.value.sublist(1, 1 + WSHealthMonitorCodec.alarmBodyLength),
    ));
  } else if (opcode == WSSettingsCommand.opcodeRead) {
    _ignoreDetached(_sendSettingsRead(channel, message.key, getBody()));
  }
}

Future<void> _sendSettingsRead(
  WatchFrameChannel channel,
  int key,
  Uint8List body,
) async {
  await channel.send(WSL2Message(
    command: WSSettingsCommand.command,
    version: WSSettingsCommand.version,
    key: key,
    value: Uint8List.fromList([WSSettingsCommand.opcodeReadReply, ...body]),
  ).encode());
}

void _handleMeasure(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message,
) {
  if (message.key == WSMeasureCommand.keyQueryStatus) {
    _ignoreDetached(channel.send(_spotStatusReply(state)));
    return;
  }

  final lane = WSSpotMeasureLanes.laneForKey(message.key);
  if (lane == null) return;

  if (message.key == lane.start) {
    final busy = state.spotBusy && state.activeSpotLane != lane;
    final result =
        busy ? WSMeasureCommand.resultBusy : WSMeasureCommand.resultStarted;
    if (!busy) {
      state.activeSpotLane = lane;
      state.spotStartedAtUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _ignoreDetached(_runSpotSimulation(channel, state, lane));
    }
    _ignoreDetached(channel.send(_measureMessage(
      lane.startReply,
      Uint8List.fromList([result]),
    )));
    return;
  }

  if (message.key == lane.stop) {
    if (state.activeSpotLane == lane) {
      state.activeSpotLane = null;
      _ignoreDetached(channel.send(_measureMessage(
        lane.result,
        Uint8List.fromList([WSMeasureCommand.resultBusy]),
      )));
    }
  }
}

Future<void> _runSpotSimulation(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSSpotMeasureLane lane,
) async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (state.activeSpotLane != lane) return;
    await channel
        .send(_measureMessage(lane.realtime, _spotRealtimePayload(lane, i)));
  }
  if (state.activeSpotLane != lane) return;
  await channel
      .send(_measureMessage(lane.result, _spotResultPayload(lane, state)));
  state.activeSpotLane = null;
}

Uint8List _spotRealtimePayload(WSSpotMeasureLane lane, int tick) {
  return switch (lane) {
    WSSpotMeasureLanes.heartRate => Uint8List.fromList([0x48 + tick]),
    WSSpotMeasureLanes.bloodPressure => Uint8List.fromList([0x4B + tick]),
    WSSpotMeasureLanes.bloodOxygen => Uint8List.fromList([0x62 + tick]),
    WSSpotMeasureLanes.hrv => Uint8List.fromList([0x00, 0x2D + tick]),
    WSSpotMeasureLanes.pressure => Uint8List.fromList([0x23 + tick]),
    WSSpotMeasureLanes.temperature => Uint8List.fromList([0x0E, 0x44]),
    WSSpotMeasureLanes.bloodGlucose => Uint8List.fromList([0x00, 0x48]),
    _ => Uint8List.fromList([tick & 0xFF]),
  };
}

Uint8List _spotResultPayload(WSSpotMeasureLane lane, WsSimWatchState state) {
  final now = state.spotStartedAtUnix + 3;
  final ts = ByteData(4)..setUint32(0, now);
  final stamp = ts.buffer.asUint8List();
  return switch (lane) {
    WSSpotMeasureLanes.heartRate => Uint8List.fromList([0x00, ...stamp, 0x48]),
    WSSpotMeasureLanes.bloodPressure =>
      Uint8List.fromList([0x00, ...stamp, 0x78, 0x50]),
    WSSpotMeasureLanes.bloodOxygen =>
      Uint8List.fromList([0x00, ...stamp, 0x62, 0x63, 0x60]),
    WSSpotMeasureLanes.hrv => Uint8List.fromList([0x00, ...stamp, 0x00, 0x34]),
    WSSpotMeasureLanes.pressure => Uint8List.fromList([0x00, ...stamp, 0x3E]),
    WSSpotMeasureLanes.temperature =>
      Uint8List.fromList([0x00, ...stamp, 0x0E, 0x44, 0x0C, 0xEE, 0x00, 0x03]),
    WSSpotMeasureLanes.bloodGlucose =>
      Uint8List.fromList([0x00, ...stamp, 0x00, 0x48]),
    _ => Uint8List.fromList([0x00]),
  };
}

Uint8List _spotStatusReply(WsSimWatchState state) {
  final lane = state.activeSpotLane;
  if (lane == null) {
    return _measureMessage(
      WSMeasureCommand.keyStatusReply,
      Uint8List(7),
    );
  }
  final data = ByteData(7);
  data.setUint8(0, 0x01);
  data.setUint8(1, lane.dataTypeCode);
  data.setUint8(2, 0x00);
  data.setUint32(3, state.spotStartedAtUnix);
  return _measureMessage(
      WSMeasureCommand.keyStatusReply, data.buffer.asUint8List());
}

void _handleControl(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message,
) {
  if (message.key == WSControlCommand.keyBatteryQuery) {
    _ignoreDetached(channel.send(_controlMessage(
      WSControlCommand.keyBatteryReply,
      Uint8List.fromList([state.batteryPercent, state.batteryCharging]),
    )));
  }
}

Future<void> _handleData(
  WatchFrameChannel channel,
  WsSimWatchState state,
  WSL2Message message,
) async {
  if (message.version != WSDataCommand.version) return;
  if (message.key == WSDataCommand.keySyncConfirm) return;

  if (message.key == WSTodayCodec.keyQuery) {
    await channel.send(_dataMessage(
      WSTodayCodec.keyTodayPayload,
      WsSimFixtures.buildTodayPayload(),
    ));
    return;
  }

  if (state.historyBusy &&
      message.key <= WSDataCommand.keySyncSport &&
      message.value.isEmpty) {
    await channel.send(_dataMessage(
      WSDataCommand.keySyncEnd,
      Uint8List.fromList([0x02, 0, 0, 0, 0]),
    ));
    return;
  }

  final isSyncRequest =
      message.key <= WSDataCommand.keySyncSport && message.value.isEmpty;
  if (!isSyncRequest) return;

  state.historyBusy = true;
  try {
    if (message.key == WSDataCommand.keySyncAll) {
      await _pushFullSnapshot(channel, state);
    } else {
      await _pushSingleType(channel, state, message.key);
    }
  } finally {
    state.historyBusy = false;
  }
}

Future<void> _pushFullSnapshot(
    WatchFrameChannel channel, WsSimWatchState state) async {
  final now = state.historyTimestamp;
  await channel.send(_dataMessage(
    WSDataCommand.keySyncStart,
    WsSimFixtures.syncStartMulti(),
  ));
  final pairs = <(int, Uint8List)>[
    (
      WSDataCommand.keyDataActivity,
      WsSimFixtures.liveBytes(WsSimFixtures.dataActivity, now: now),
    ),
    if (WsSimFixtures.includeSleepInFullSync)
      (
        WSDataCommand.keyDataSleep,
        WsSimFixtures.liveBytes(WsSimFixtures.dataSleep, now: now),
      ),
    (
      WSDataCommand.keyDataHeartRate,
      WsSimFixtures.liveBytes(state.heartRateDataFrame, now: now),
    ),
    (
      WSDataCommand.keyDataBloodPressure,
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodPressure, now: now),
    ),
    (
      WSDataCommand.keyDataBloodOxygen,
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodOxygen, now: now),
    ),
    (
      WSDataCommand.keyDataHrv,
      WsSimFixtures.liveBytes(WsSimFixtures.dataHrv, now: now),
    ),
    (
      WSDataCommand.keyDataPressure,
      WsSimFixtures.liveBytes(WsSimFixtures.dataPressure, now: now),
    ),
    (
      WSDataCommand.keyDataTemperature,
      WsSimFixtures.liveBytes(WsSimFixtures.dataTemperature, now: now),
    ),
    (
      WSDataCommand.keyDataBloodGlucose,
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodGlucose, now: now),
    ),
    (
      WSDataCommand.keyDataSport,
      WsSimFixtures.liveBytes(WsSimFixtures.dataSport, now: now),
    ),
  ];
  for (final p in pairs) {
    await channel.send(_dataMessage(p.$1, p.$2));
  }
  final total = WsSimFixtures.totalWireRecords;
  await channel.send(_dataMessage(
    WSDataCommand.keySyncEnd,
    Uint8List.fromList([0x00, 0, 0, 0, total]),
  ));
}

Future<void> _pushSingleType(
    WatchFrameChannel channel, WsSimWatchState state, int syncKey) async {
  final now = state.historyTimestamp;
  const count = 2;
  await channel.send(_dataMessage(
    WSDataCommand.keySyncStart,
    Uint8List.fromList([syncKey, 0, count]),
  ));
  final dataKey = syncKey + 0x20;
  final value = switch (syncKey) {
    WSDataCommand.keySyncActivity =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataActivity, now: now),
    WSDataCommand.keySyncSleep =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataSleep, now: now),
    WSDataCommand.keySyncHeartRate =>
      WsSimFixtures.liveBytes(state.heartRateDataFrame, now: now),
    WSDataCommand.keySyncBloodPressure =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodPressure, now: now),
    WSDataCommand.keySyncBloodOxygen =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodOxygen, now: now),
    WSDataCommand.keySyncHrv =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataHrv, now: now),
    WSDataCommand.keySyncPressure =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataPressure, now: now),
    WSDataCommand.keySyncTemperature =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataTemperature, now: now),
    WSDataCommand.keySyncBloodGlucose =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataBloodGlucose, now: now),
    WSDataCommand.keySyncSport =>
      WsSimFixtures.liveBytes(WsSimFixtures.dataSport, now: now),
    _ => Uint8List(0),
  };
  if (value.isNotEmpty) {
    await channel.send(_dataMessage(dataKey, value));
  }
  await channel.send(_dataMessage(
    WSDataCommand.keySyncEnd,
    Uint8List.fromList([0x00, 0, 0, 0, count]),
  ));
}

Uint8List _bindReply(int key, int resultByte) => WSL2Message(
      command: WSBindCommand.command,
      version: WSBindCommand.version,
      key: key,
      value: Uint8List.fromList([resultByte]),
    ).encode();

Uint8List _dataMessage(int key, Uint8List value) => WSL2Message(
      command: WSDataCommand.command,
      version: WSDataCommand.version,
      key: key,
      value: value,
    ).encode();

Uint8List _measureMessage(int key, Uint8List value) => WSL2Message(
      command: WSMeasureCommand.command,
      version: WSMeasureCommand.version,
      key: key,
      value: value,
    ).encode();

Uint8List _controlMessage(int key, Uint8List value) => WSL2Message(
      command: WSControlCommand.command,
      version: WSControlCommand.version,
      key: key,
      value: value,
    ).encode();

/// Minimal device-info read reply from WS protocol `0x02` `0x30` example.
Uint8List _deviceInfoReply() {
  final serial = 'WS2026000001';
  final body = <int>[
    WSSettingsCommand.opcodeReadReply,
    0x00,
    0x01,
    ...List<int>.filled(13, 0),
    serial.length,
    ...serial.codeUnits,
  ];
  return WSL2Message(
    command: WSDeviceCommand.command,
    version: WSDeviceCommand.version,
    key: WSDeviceCommand.keyDeviceInfo,
    value: Uint8List.fromList(body),
  ).encode();
}

Uint8List _capabilitiesReply() => WSL2Message(
      command: WSDeviceCommand.command,
      version: WSDeviceCommand.version,
      key: WSDeviceCommand.keyCapabilities,
      value: Uint8List.fromList([
        WSSettingsCommand.opcodeReadReply,
        ...List<int>.filled(8, 0xFF),
        ...List<int>.filled(8, 0),
      ]),
    ).encode();

// Replies may still be queued when a simulated peer is detached.
void _ignoreDetached(Future<void> work) {
  work.ignore();
}
