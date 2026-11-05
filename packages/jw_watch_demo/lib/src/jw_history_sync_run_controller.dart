import 'package:flutter/foundation.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_history_sync_labels.dart';
import 'jw_history_sync_state.dart';

/// Drives [JWWatchSession.syncHealthData] and mirrors listener callbacks into UI state.
final class JwHistorySyncRunController extends ChangeNotifier
    implements JWHistorySyncListener {
  JwHistorySyncRunState _state = const JwHistorySyncRunState.idle();
  Future<void>? _active;

  JwHistorySyncRunState get state => _state;

  Future<void> start(JWWatchSession session) {
    if (_active != null) {
      return Future.error(StateError('JW health sync is already active'));
    }
    final startedAt = DateTime.now();
    _state = JwHistorySyncRunState(
      phase: JwHistorySyncPhase.syncing,
      receivedWire: 0,
      totalWire: 0,
      startedAt: startedAt,
      eventLog: [
        _ts(startedAt),
        '已发起同步，等待设备返回计划…',
      ],
    );
    notifyListeners();
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
    final payload = await session.resetHistorySyncMarkers();
    if (payload.isEmpty) {
      _log('设备已应答，可再次发起同步');
    } else {
      _log(
        '设备已应答（${payload.length} 字节） '
        '${JwHistorySyncRunController._hexPreview(payload)}',
      );
    }
    notifyListeners();
  }

  void _log(String message) {
    final entries = List<String>.from(_state.eventLog)
      ..add('${_ts(DateTime.now())} $message');
    while (entries.length > JwHistorySyncRunState.maxEventLogEntries) {
      entries.removeAt(0);
    }
    _state = _state.copyWith(eventLog: entries);
  }

  static String _ts(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '[$h:$m:$s]';
  }

  @override
  void onSyncStart(JWHistorySyncPlan plan) {
    _state = _state.copyWith(
      plan: plan,
      totalWire: plan.totalWireRecords,
      receivedWire: 0,
      receivedRowsByCategory: {},
      roundRecords: {},
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
      _log('传输进度 $receivedWireRecords / $totalWireRecords');
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
      _append(JWHistorySyncCategory.activity, batch);

  @override
  void onSleepReceived(List<JWSleep> batch) =>
      _append(JWHistorySyncCategory.sleep, batch);

  @override
  void onHeartRateReceived(List<JWHeartRate> batch) =>
      _append(JWHistorySyncCategory.heartRate, batch);

  @override
  void onTemperatureReceived(List<JWTemperature> batch) =>
      _appendTemperature(batch);

  @override
  void onBloodPressureReceived(List<JWBloodPressure> batch) =>
      _append(JWHistorySyncCategory.bloodPressure, batch);

  @override
  void onBloodOxygenReceived(List<JWBloodOxygen> batch) =>
      _append(JWHistorySyncCategory.bloodOxygen, batch);

  @override
  void onHrvReceived(List<JWHrv> batch) =>
      _append(JWHistorySyncCategory.hrv, batch);

  @override
  void onPressureReceived(List<JWPressure> batch) =>
      _append(JWHistorySyncCategory.pressure, batch);

  @override
  void onSportReceived(List<JWSport> batch) =>
      _append(JWHistorySyncCategory.sport, batch);

  void _append(JWHistorySyncCategory category, List<Object> batch) {
    if (batch.isEmpty) return;
    if (!jwHistorySyncCategoryVisibleInDemo(category)) return;
    final rows = Map<JWHistorySyncCategory, int>.from(
        _state.receivedRowsByCategory);
    final next = (rows[category] ?? 0) + batch.length;
    rows[category] = next;
    final records = Map<JWHistorySyncCategory, List<Object>>.from(
        _state.roundRecords);
    final bucket = List<Object>.from(records[category] ?? const []);
    for (final item in batch) {
      if (bucket.length >= JwHistorySyncRunState.maxSamplesPerCategory) break;
      bucket.add(item);
    }
    records[category] = bucket;
    _state = _state.copyWith(
      receivedRowsByCategory: rows,
      roundRecords: records,
    );
    _log(
      '收到 ${jwHistorySyncCategoryLabel(category)} ${batch.length} 条（累计 $next）',
    );
    notifyListeners();
  }

  /// Temperature rows are decoded from heart-rate wire payloads; they do not
  /// add to wire progress or the primary parsed-row total.
  void _appendTemperature(List<JWTemperature> batch) {
    if (batch.isEmpty) return;
    final rows = Map<JWHistorySyncCategory, int>.from(
        _state.receivedRowsByCategory);
    final next = (rows[JWHistorySyncCategory.temperature] ?? 0) + batch.length;
    rows[JWHistorySyncCategory.temperature] = next;
    final records = Map<JWHistorySyncCategory, List<Object>>.from(
        _state.roundRecords);
    final bucket = List<Object>.from(
        records[JWHistorySyncCategory.temperature] ?? const []);
    for (final item in batch) {
      if (bucket.length >= JwHistorySyncRunState.maxSamplesPerCategory) break;
      bucket.add(item);
    }
    records[JWHistorySyncCategory.temperature] = bucket;
    _state = _state.copyWith(
      receivedRowsByCategory: rows,
      roundRecords: records,
    );
    _log('心率数据附带体温 ${batch.length} 条（累计 $next）');
    notifyListeners();
  }
}
