import 'dart:async';

import 'config.dart';
import 'connection/connection_state.dart';
import 'debug/debug_api.dart';
import 'errors.dart';
import 'logger.dart';
import 'protocol/cmd_02_settings.dart';
import 'session/session.dart';
import 'simulation/simulation_runtime.dart';

/// SDK 入口。每台设备一个实例。
///
/// M2 已提供调试门面与 [openSimulationLab]；正式连接与认证在 M3 接入，见设计文档第 9 节。
class WSWatch {
  WSWatch({this.config = const WSConfig()})
      : logger = config.logger ?? WSDebugPrintLogger(minLevel: config.logLevel);

  final WSDebugController _debug = WSDebugController();

  WSDebugApi get debug => _debug;

  final WSConfig config;
  final WSLogger logger;

  final StreamController<WSConnectionChange> _stateChanges =
      StreamController<WSConnectionChange>.broadcast();
  final WSConnectionState _state = WSConnectionState.disconnected;
  bool _disposed = false;
  Future<void>? _disposing;
  WSSimulationRuntime? _simulationRuntime;

  WSConnectionState get state => _state;

  Stream<WSConnectionChange> get stateChanges => _stateChanges.stream;

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
    if (_simulationRuntime != null) {
      throw StateError('Simulation lab is already open.');
    }
    final runtime =
        await WSSimulationRuntime.open(config: config, mtu: mtu);
    _simulationRuntime = runtime;
    _debug.attach(runtime.session, allowRaw: () => !runtime.session.isClosed);
  }

  /// 关闭模拟实验室并释放传输；[debug] 仍可复用，直至 [dispose]。
  Future<void> closeSimulationLab() async {
    if (_simulationRuntime == null) return;
    await _debug.detach();
    await _simulationRuntime!.dispose();
    _simulationRuntime = null;
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
    await closeSimulationLab();
    await _debug.dispose();
    await _stateChanges.close();
  }
}
