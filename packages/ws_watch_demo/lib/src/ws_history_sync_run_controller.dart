import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_log.dart';
import 'ws_history_sync_labels.dart';
import 'ws_history_sync_state.dart';

/// Drives [WSWatchSession.syncHealthData] and mirrors listener callbacks into UI state.
final class WsHistorySyncRunController extends ChangeNotifier
    implements WSHistorySyncListener {
  WsHistorySyncRunState _state = const WsHistorySyncRunState.idle();
  Future<void>? _active;
  bool _wireCompleteLogged = false;
  int _lastProgressLogWire = -1;

  WsHistorySyncRunState get state => _state;

  Future<void> start(WSWatchSession session) {
    if (_active != null) {
      return Future.error(StateError('WS health sync is already active'));
    }
    final startedAt = DateTime.now();
    _wireCompleteLogged = false;
    _lastProgressLogWire = -1;
    _state = WsHistorySyncRunState(
      phase: WsHistorySyncPhase.syncing,
      receivedWire: 0,
      totalWire: 0,
      startedAt: startedAt,
    );
    notifyListeners();
    _log('已发起历史同步，等待设备计划…');
    final run = session.syncHealthData(this, onHistoryFrame: _logRawFrame);
    _active = run;
    return run.whenComplete(() {
      _active = null;
    });
  }

  void reset() {
    if (_active != null) return;
    _state = const WsHistorySyncRunState.idle();
    notifyListeners();
  }

  Future<void> resetDeviceSyncMarkers(WSWatchSession session) async {
    if (_active != null) {
      throw StateError('WS health sync is already active');
    }
    _log('重置同步标记暂未接入 WS SDK（跳过）');
    notifyListeners();
  }

  void _log(String message) => WsDemoLog.sync(message);

  void _logRawFrame(WSHistorySyncFrame frame) {
    final preview = frame.value.isEmpty
        ? '(empty)'
        : _hexPreview(frame.value);
    _log(
      'RX 0x05 key 0x${frame.key.toRadixString(16)} '
      'len ${frame.value.length} $preview',
    );
  }

  static String _hexPreview(Uint8List bytes, {int maxBytes = 40}) {
    final take = bytes.length > maxBytes ? maxBytes : bytes.length;
    final hex = StringBuffer();
    for (var i = 0; i < take; i++) {
      if (i > 0) hex.write(' ');
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    if (bytes.length > maxBytes) hex.write(' …');
    return hex.toString();
  }

  @override
  void onSyncStart(WSHistorySyncPlan plan) {
    _state = _state.copyWith(
      plan: plan,
      totalWire: plan.totalWireRecords,
      receivedWire: 0,
      receivedRowsByCategory: {},
      clearFailure: true,
    );
    _log('同步开始：设备计划共 ${plan.totalWireRecords} 条');
    for (final category in jwDemoHistorySyncCategories) {
      final planned = plan.wireCountsByCategory[category];
      if (planned != null && planned > 0) {
        _log('  · ${jwHistorySyncCategoryLabel(category)}：计划 $planned');
      }
    }
    if (plan.totalWireRecords == 0) {
      _log('  · 设备未声明待传条目（可能无新数据）');
    }
    notifyListeners();
  }

  @override
  void onSyncProgress(int receivedWireRecords, int totalWireRecords) {
    final prev = _state.receivedWire;
    _state = _state.copyWith(
      receivedWire: receivedWireRecords,
      totalWire: totalWireRecords,
    );
    if (receivedWireRecords != prev) {
      final shouldLog = receivedWireRecords == totalWireRecords ||
          _lastProgressLogWire < 0 ||
          receivedWireRecords - _lastProgressLogWire >= 200 ||
          totalWireRecords <= 200;
      if (shouldLog) {
        _lastProgressLogWire = receivedWireRecords;
        _log('传输进度 $receivedWireRecords / $totalWireRecords');
      }
      if (totalWireRecords > 0 &&
          receivedWireRecords >= totalWireRecords &&
          !_wireCompleteLogged) {
        _wireCompleteLogged = true;
        _log('蓝牙传输完成，正在写入本地数据库…');
      }
    }
    notifyListeners();
  }

  @override
  void onSyncFinished() {
    final finishedAt = DateTime.now();
  _state = _state.copyWith(
      phase: WsHistorySyncPhase.success,
      finishedAt: finishedAt,
    );
    _log(
      '同步结束：传输 ${_state.receivedWire}/${_state.totalWire}',
    );
    notifyListeners();
  }

  @override
  void onSyncFailed(WSHistorySyncFailure failure) {
    final finishedAt = DateTime.now();
    _state = _state.copyWith(
      phase: WsHistorySyncPhase.failed,
      failure: failure,
      finishedAt: finishedAt,
    );
    _log('同步失败：${describeWsHistorySyncFailure(failure)}');
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
