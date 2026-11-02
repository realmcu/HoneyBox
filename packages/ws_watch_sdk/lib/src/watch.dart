import 'dart:async';

import 'config.dart';
import 'features/settings.dart';
import 'features/data.dart';
import 'model/feature.dart';
import 'connection/connection_state.dart';
import 'connection/connection_machine.dart';
import 'connection/environment.dart';
import 'scanner.dart';
import 'model/device_info.dart';
import 'capability/capabilities.dart';
import 'debug/debug_api.dart';
import 'errors.dart';
import 'logger.dart';
import 'protocol/cmd_02_settings.dart';
import 'session/session.dart';
import 'simulation/simulation_runtime.dart';

/// SDK 入口。每台设备一个实例。
///
/// 提供 M3 扫描、认证与初始化、M4 [settings] 及 M5 [data]；[openSimulationLab] 保留为独立的 M2 实验入口。
class WSWatch {
  WSWatch({this.config = const WSConfig()})
      : logger = config.logger ?? WSDebugPrintLogger(minLevel: config.logLevel);

  final WSDebugController _debug = WSDebugController();
  final WSConnectionEnvironment _environment = WSConnectionEnvironment.current;
  late final WSConnectionMachine _machine =
      WSConnectionMachine(config, _debug, _environment);
  late final WSSettingsController _settings = WSSettingsController(
      requireSession: () {
        if (_disposed) throw const WSDisposedException();
        return _machine.requireReadySession();
      },
      support: (feature) =>
          capabilities?.supportOf(feature) ?? WSFeatureSupport.unknown,
      now: _environment.now,
      states: stateChanges);
  WSSettings get settings => _settings;

  late final WSDataController _data = WSDataController(
      connection: () {
        if (_disposed) throw const WSDisposedException();
        return WSDataConnection(
            _machine.requireReadySession(), deviceId!, userId!);
      },
      openStore: () {
        if (_disposed) throw const WSDisposedException();
        return _machine.historyStore();
      },
      disconnect: _machine.disconnectSession,
      support: (feature) =>
          capabilities?.supportOf(feature) ?? WSFeatureSupport.unknown,
      config: config.sync,
      now: _environment.now,
      logger: logger);
  WSData get data => _data;

  static WSScanner scanner({WSConfig config = const WSConfig()}) =>
      WSScanner(config: config);
  WSDeviceInfo? get deviceInfo => _machine.deviceInfo;
  WSCapabilities? get capabilities => _machine.capabilities;
  String? get userId => _machine.userId;
  String? get deviceId => _machine.deviceId;
  Future<void> connect(String deviceId, {String? userId}) async {
    if (_disposed) throw const WSDisposedException();
    if (_simulationRuntime != null || _openingLab || _closingLab != null) {
      throw StateError('close the M2 laboratory before connecting');
    }
    await _machine.connect(deviceId, userId: userId);
  }

  Future<void> disconnect() => _machine.disconnect();
  Future<void> unbind() => _machine.unbind();

  WSDebugApi get debug => _debug;

  final WSConfig config;
  final WSLogger logger;

  bool _disposed = false;
  Future<void>? _disposing;
  WSSimulationRuntime? _simulationRuntime;
  bool _openingLab = false;
  int _labEpoch = 0;
  Future<void>? _closingLab;

  WSConnectionState get state => _machine.state;

  Stream<WSConnectionChange> get stateChanges => _machine.changes;

  bool get isDisposed => _disposed;

  /// 内存模拟实验室是否已打开（非 M3 connect，不会进入 [WSConnectionState.ready]）。
  bool get isSimulationLabOpen => _simulationRuntime != null;

  /// 打开 M2 模拟实验室：Link + Session + 最小 SimWatch，并挂接 [debug]。
  ///
  /// 需要 [WSConfig.simulationEnabled] 为 true。不是正式蓝牙连接。
  Future<void> openSimulationLab({int mtu = 247}) async {
    if (_disposed) throw const WSDisposedException();
    if (!config.simulationEnabled) {
      throw StateError(
        'Set WSConfig.simulationEnabled to true before opening the simulation lab.',
      );
    }
    if (_simulationRuntime != null ||
        _openingLab ||
        _closingLab != null ||
        state != WSConnectionState.disconnected) {
      throw StateError('Simulation lab is already open.');
    }
    _openingLab = true;
    final epoch = ++_labEpoch;
    try {
      final runtime = await WSSimulationRuntime.open(config: config, mtu: mtu);
      if (_disposed || epoch != _labEpoch) {
        await runtime.dispose();
        throw const WSDisposedException();
      }
      _simulationRuntime = runtime;
      _debug.attach(runtime.session, allowRaw: () => !runtime.session.isClosed);
    } finally {
      _openingLab = false;
    }
  }

  /// 关闭模拟实验室并释放传输；[debug] 仍可复用，直至 [dispose]。
  Future<void> closeSimulationLab() => _closingLab ??=
      _closeSimulationLab().whenComplete(() => _closingLab = null);

  Future<void> _closeSimulationLab() async {
    _labEpoch++;
    final runtime = _simulationRuntime;
    if (runtime == null) return;
    _simulationRuntime = null;
    await _debug.detach();
    await runtime.dispose();
  }

  /// 实验室：设置语言编码（0x02 Key 0x03 操作码 0x00）。
  Future<void> labSetLanguage(int code) async {
    final session = _requireLabSession();
    await session.send(WSSettingsProtocol.setLanguage, code);
  }

  /// 实验室：读取当前语言编码。
  Future<int> labGetLanguage() async {
    final session = _requireLabSession();
    return session.query(WSSettingsProtocol.getLanguage, null);
  }

  WSSession _requireLabSession() {
    if (_disposed) throw const WSDisposedException();
    final runtime = _simulationRuntime;
    if (runtime == null || runtime.session.isClosed) {
      throw const WSSessionInvalidatedException(
        'Open the simulation lab before calling lab APIs.',
      );
    }
    return runtime.session;
  }

  /// 释放资源。之后不能再使用该实例。
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final disconnected = _machine.disconnect();
    await _data.dispose();
    await disconnected;
    await _machine.dispose();
    await _settings.dispose();
    await closeSimulationLab();
    await _debug.dispose();
  }
}
