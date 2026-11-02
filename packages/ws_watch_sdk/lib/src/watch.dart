import 'dart:async';

import 'config.dart';
import 'connection/connection_state.dart';
import 'logger.dart';

/// SDK 入口。每台设备一个实例。
///
/// 连接、业务模块和链路在后续里程碑中接入，见设计文档第 9 节。
class WSWatch {
  WSWatch({this.config = const WSConfig()})
      : logger = config.logger ?? WSDebugPrintLogger(minLevel: config.logLevel);

  final WSConfig config;
  final WSLogger logger;

  final StreamController<WSConnectionChange> _stateChanges =
      StreamController<WSConnectionChange>.broadcast();
  final WSConnectionState _state = WSConnectionState.disconnected;
  bool _disposed = false;

  WSConnectionState get state => _state;

  Stream<WSConnectionChange> get stateChanges => _stateChanges.stream;

  bool get isDisposed => _disposed;

  /// 释放资源。之后不能再使用该实例。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateChanges.close();
  }
}
