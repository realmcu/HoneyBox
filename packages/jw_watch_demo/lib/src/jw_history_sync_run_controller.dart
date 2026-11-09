import 'package:flutter/foundation.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_log.dart';
import 'jw_history_sync_labels.dart';
import 'jw_history_sync_state.dart';

/// Drives [JWWatchSession.syncHealthData] and mirrors listener callbacks into UI state.
final class JwHistorySyncRunController extends ChangeNotifier
    implements JWHistorySyncListener {
  JwHistorySyncRunState _state = const JwHistorySyncRunState.idle();
  Future<void>? _active;
  bool _wireCompleteLogged = false;
  int _lastProgressLogWire = -1;

  JwHistorySyncRunState get state => _state;

  Future<void> start(JWWatchSession session) {
    if (_active != null) {
      return Future.error(StateError('JW health sync is already active'));
    }
    final startedAt = DateTime.now();
    _wireCompleteLogged = false;
    _lastProgressLogWire = -1;
    _state = JwHistorySyncRunState(
      phase: JwHistorySyncPhase.syncing,
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

  void _logRawFrame(JWHistorySyncFrame frame) {
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

  void reset() {
    if (_active != null) return;
    _state = const JwHistorySyncRunState.idle();
    notifyListeners();
  }

  Future<void> resetDeviceSyncMarkers(JWWatchSession session) async {
    if (_active != null) {
      throw StateError('JW health sync is already active');
    }
    _log('正在重置设备同步标记…');
    notifyListeners();
    await session.resetHistorySyncMarkers();
    _log('已发送重置同步标记');
    notifyListeners();
  }

  void _log(String message) => JwDemoLog.sync(message);

  @override
  void onSyncStart(JWHistorySyncPlan plan) {
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
    final parsed = jwDemoParsedRowTotal(_state.receivedRowsByCategory);
    final tempParsed = jwDemoTemperatureParsedCount(_state.receivedRowsByCategory);
    _state = _state.copyWith(
      phase: JwHistorySyncPhase.success,
      finishedAt: finishedAt,
    );
    final endLog = tempParsed > 0
        ? '同步结束：传输 ${_state.receivedWire}/${_state.totalWire}，'
            '解析 $parsed 条（另附带体温 $tempParsed 条）'
        : '同步结束：传输 ${_state.receivedWire}/${_state.totalWire}，'
            '解析 $parsed 条健康记录';
    _log(endLog);
    notifyListeners();
  }

  @override
  void onSyncFailed(JWHistorySyncFailure failure) {
    final finishedAt = DateTime.now();
    _state = _state.copyWith(
      phase: JwHistorySyncPhase.failed,
      failure: failure,
      finishedAt: finishedAt,
    );
    _log('同步失败：${describeJwHistorySyncFailure(failure)}');
    notifyListeners();
  }

  @override
  void onActivityReceived(List<JWActivity> batch) =>
      _count(JWHistorySyncCategory.activity, batch.length);

  @override
  void onSleepReceived(List<JWSleep> batch) =>
      _count(JWHistorySyncCategory.sleep, batch.length);

  @override
  void onHeartRateReceived(List<JWHeartRate> batch) =>
      _count(JWHistorySyncCategory.heartRate, batch.length);

  @override
  void onTemperatureReceived(List<JWTemperature> batch) =>
      _count(JWHistorySyncCategory.temperature, batch.length);

  @override
  void onBloodPressureReceived(List<JWBloodPressure> batch) =>
      _count(JWHistorySyncCategory.bloodPressure, batch.length);

  @override
  void onBloodOxygenReceived(List<JWBloodOxygen> batch) =>
      _count(JWHistorySyncCategory.bloodOxygen, batch.length);

  @override
  void onHrvReceived(List<JWHrv> batch) =>
      _count(JWHistorySyncCategory.hrv, batch.length);

  @override
  void onPressureReceived(List<JWPressure> batch) =>
      _count(JWHistorySyncCategory.pressure, batch.length);

  @override
  void onSportReceived(List<JWSport> batch) =>
      _count(JWHistorySyncCategory.sport, batch.length);

  void _count(JWHistorySyncCategory category, int added) {
    if (added <= 0) return;
    if (!jwHistorySyncCategoryVisibleInDemo(category)) return;
    final rows = Map<JWHistorySyncCategory, int>.from(
        _state.receivedRowsByCategory);
    final next = (rows[category] ?? 0) + added;
    rows[category] = next;
    _state = _state.copyWith(receivedRowsByCategory: rows);
    if (next <= 50 || next % 200 == 0) {
      _log('收到 ${jwHistorySyncCategoryLabel(category)} $added 条（累计 $next）');
    }
    notifyListeners();
  }
}
