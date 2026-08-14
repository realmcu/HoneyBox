import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ebadge_protocol.dart';

/// eBadge 协议的 BLE 传输层 —— 独立于 [BleManager] 的 L1/L2 协议栈。
///
/// **为什么不复用 BleManager 的命令通道**:eBadge 跑在自己的 GATT 服务
/// (`f48affc0` / c1 写 / c2 通知)上,而 BleManager 的 `sendCommand` 绑死在
/// FFC1 + L1Engine(CRC + ACK + seq 分片)。把 eBadge 裸帧塞进 L1 会被套上一
/// 层它不认识的头。所以这里自己找特征、自己写、自己收。
///
/// 实现上刻意**不碰 BleManager 一行代码**:`BluetoothDevice` 在
/// flutter_blue_plus 2.x 里是按 remoteId 索引全局缓存的轻量值对象,用同一个
/// deviceId 重新构造出来的实例共享同一条已建立的连接和已发现的服务表。
/// BleManager 自己在 `connect()` 里也正是这样构造设备的。
class EBadgeLink {
  EBadgeLink({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxWrite; // f48affc1 —— app 写
  BluetoothCharacteristic? _txNotify; // f48affc2 —— app 收
  StreamSubscription<List<int>>? _notifySub;

  int _mtu = 23;
  bool _disposed = false;

  /// 已发现并订阅成功。
  bool get ready => _rxWrite != null && _txNotify != null;

  int get mtu => _mtu;

  /// 单次 ATT 写的净荷上限。
  int get writeChunkSize {
    final c = _mtu - 3;
    return c < 1 ? 1 : c;
  }

  // ── 日志 ────────────────────────────────────────────────────────────

  /// 有界日志。调试页直接渲染这个列表 —— 存在 link 里而不是 Widget state,
  /// 页面重建 / 键盘弹出都不会把历史抖掉。
  final List<EBadgeLogEntry> _log = [];

  /// 上限 500 条。协议调试的信息密度很高,不设上限跑一次传图就能顶到几万条。
  static const int _logLimit = 500;

  List<EBadgeLogEntry> get log => List.unmodifiable(_log);

  final _logController = StreamController<void>.broadcast();

  /// 日志有新增时触发(不带内容,读 [log])。
  Stream<void> get onLogChanged => _logController.stream;

  /// 解析出的完整帧。调试页用来更新「设备信息」区(电量 / 存储 / AP)。
  final _frameController = StreamController<EBadgeFrame>.broadcast();
  Stream<EBadgeFrame> get frames => _frameController.stream;

  void _emit(EBadgeLogEntry e) {
    if (_disposed) return;
    _log.add(e);
    if (_log.length > _logLimit) {
      _log.removeRange(0, _log.length - _logLimit);
    }
    if (!_logController.isClosed) _logController.add(null);
  }

  void logInfo(String text, {String? detail}) =>
      _emit(EBadgeLogEntry.info(text, detail: detail));

  void logError(String text, {String? detail}) =>
      _emit(EBadgeLogEntry.error(text, detail: detail));

  void clearLog() {
    _log.clear();
    if (!_logController.isClosed) _logController.add(null);
  }

  // ── 接收缓冲 ────────────────────────────────────────────────────────

  /// 跨 notify 的拼包缓冲。一帧可能被 ATT 切成多个 notify,也可能一个 notify
  /// 里挤了多帧 —— 两种都要处理,所以维护一个流式缓冲而不是逐包解析。
  final List<int> _rxBuf = [];

  // ── 连接 ────────────────────────────────────────────────────────────

  /// 找到 eBadge 服务并订阅通知。返回是否就绪。
  ///
  /// 前提是 [deviceId] 对应的设备已由 BleManager 连上。
  Future<bool> attach() async {
    if (_disposed) return false;
    if (ready) return true;

    if (deviceId.isEmpty) {
      logError('设备未连接', detail: 'deviceId 为空');
      return false;
    }

    try {
      _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

      var services = _device!.servicesList;
      if (services.isEmpty) {
        // BleManager 连接时已 discoverServices,缓存通常非空;为空说明本进程
        // 还没发现过(例如热重载后),补一次。
        logInfo('服务表为空,重新发现服务…');
        await _device!.discoverServices();
        services = _device!.servicesList;
      }

      for (final s in services) {
        final su = s.uuid.toString().toLowerCase();
        if (su != EBadgeGatt.service && !su.contains('f48affc0')) continue;
        for (final c in s.characteristics) {
          final cu = c.uuid.toString().toLowerCase();
          if (cu.contains('f48affc1') &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _rxWrite = c;
          }
          if (cu.contains('f48affc2') &&
              (c.properties.notify || c.properties.indicate)) {
            _txNotify = c;
          }
        }
      }

      if (!ready) {
        final have = <String>[
          if (_rxWrite != null) 'f48affc1',
          if (_txNotify != null) 'f48affc2',
        ];
        logError(
          '未找到 eBadge 服务特征',
          detail: '需要 ${EBadgeGatt.service} 下的 f48affc1(write)+ '
              'f48affc2(notify);当前只找到 '
              '${have.isEmpty ? "无" : have.join(" + ")}。'
              '共 ${services.length} 个服务,详见 logcat 里的 GATT table。',
        );
        return false;
      }

      // MTU:BleManager 只在 FFC1/FFC2 齐全时才 requestMtu,而 eBadge 设备很
      // 可能没有那对特征(走了 GATT-only 降级路径),所以这里自己要一次。
      // 已协商过再请求在部分 Android 上会抛,失败就用当前值。
      try {
        _mtu = await _device!.requestMtu(512);
      } catch (_) {
        _mtu = _device!.mtuNow;
      }

      await _txNotify!.setNotifyValue(true);
      _notifySub = _txNotify!.onValueReceived.listen(
        _onNotify,
        onError: (Object e) => logError('通知流异常', detail: '$e'),
      );

      logInfo('eBadge 通道就绪',
          detail: 'MTU=$_mtu(单写 $writeChunkSize B) '
              'service=${EBadgeGatt.service}');
      return true;
    } catch (e) {
      logError('挂载 eBadge 服务失败', detail: '$e');
      return false;
    }
  }

  void _onNotify(List<int> data) {
    if (_disposed || data.isEmpty) return;
    final chunk = Uint8List.fromList(data);
    _rxBuf.addAll(chunk);

    // 先把这次收到的原始字节记下来 —— 即使后面解析失败,原始数据也在日志里,
    // 这是协议调试最要紧的一条。
    _emit(EBadgeLogEntry.recvRaw(chunk));

    _drain();
  }

  void _drain() {
    while (_rxBuf.isNotEmpty) {
      final buf = Uint8List.fromList(_rxBuf);
      final r = EBadgeCodec.decode(buf);

      if (r.isOk) {
        _rxBuf.removeRange(0, r.consumed);
        final f = r.frame!;
        _emit(EBadgeLogEntry.recvFrame(f));
        if (!_frameController.isClosed) _frameController.add(f);
        continue;
      }

      switch (r.error!) {
        case EBadgeParseError.incomplete:
          // 等下一个 notify 补齐。
          return;
        case EBadgeParseError.badVersion:
        case EBadgeParseError.badMarker:
          _emit(EBadgeLogEntry.error(
            '帧同步失败,丢弃 1 字节',
            detail: '首字节 0x${buf[0].toRadixString(16).padLeft(2, '0')}'
                '(期望 ver=0x01,第 3 字节 0x80);'
                '缓冲 ${_rxBuf.length}B',
          ));
          _rxBuf.removeRange(0, r.consumed);
        case EBadgeParseError.tlvOverflow:
          _emit(EBadgeLogEntry.error(
            'TLV 长度越界,丢弃整帧',
            detail: EBadgeCodec.hex(
              Uint8List.sublistView(buf, 0, r.consumed),
              max: 64,
            ),
          ));
          _rxBuf.removeRange(0, r.consumed);
      }
    }
  }

  // ── 发送 ────────────────────────────────────────────────────────────

  /// 写一整帧。超过单写上限时按 [writeChunkSize] 切分连续写入 —— eBadge 没有
  /// L1 分片层,设备端靠帧头的 params_len 自己攒够长度。
  ///
  /// [label] 是给日志用的人类可读说明,例如「SET_TIME 2026-08-13 20:15:30」。
  Future<bool> send(Uint8List frame, String label) async {
    if (_disposed) return false;
    if (!ready) {
      logError('发送失败:通道未就绪', detail: label);
      return false;
    }

    _emit(EBadgeLogEntry.sendFrame(label, frame));

    try {
      await _writeAll(frame);
      return true;
    } catch (e) {
      logError('写入失败', detail: '$label — $e');
      return false;
    }
  }

  /// 写裸字节(不作帧解释),供 SEND_FILE 的正文段使用。
  Future<bool> sendRaw(Uint8List bytes, String label) async {
    if (_disposed) return false;
    if (!ready) {
      logError('发送失败:通道未就绪', detail: label);
      return false;
    }
    _emit(EBadgeLogEntry.sendRaw(label, bytes));
    try {
      await _writeAll(bytes);
      return true;
    } catch (e) {
      logError('写入失败', detail: '$label — $e');
      return false;
    }
  }

  Future<void> _writeAll(Uint8List bytes) async {
    final char = _rxWrite!;
    // withoutResponse 只在特征支持时用,否则退回带响应写(有流控,更稳)。
    final noRsp = char.properties.writeWithoutResponse;
    final size = writeChunkSize;
    for (var o = 0; o < bytes.length; o += size) {
      final end = (o + size < bytes.length) ? o + size : bytes.length;
      await char.write(
        Uint8List.sublistView(bytes, o, end),
        withoutResponse: noRsp,
      );
    }
  }

  // ── 释放 ────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _disposed = true;
    await _notifySub?.cancel();
    _notifySub = null;
    // 不主动 setNotifyValue(false):设备可能已断开,那次写会抛;而且连接断开
    // 时 CCC 本就失效,没必要为清理去冒异常。
    _rxWrite = null;
    _txNotify = null;
    _device = null;
    _rxBuf.clear();
    if (!_logController.isClosed) await _logController.close();
    if (!_frameController.isClosed) await _frameController.close();
    debugPrint('EBadgeLink: disposed ($deviceName)');
  }
}

// ---------------------------------------------------------------------------
// 日志条目
// ---------------------------------------------------------------------------

enum EBadgeLogKind { send, recv, info, error }

/// 日志区一行。既保留人类可读摘要([title] / [detail]),也保留原始十六进制
/// ([hex])—— 协议调试两者都不可少。
class EBadgeLogEntry {
  EBadgeLogEntry._({
    required this.kind,
    required this.title,
    required this.at,
    this.detail,
    this.hex,
    this.violations = const [],
  });

  final EBadgeLogKind kind;
  final String title;
  final String? detail;
  final String? hex;
  final DateTime at;

  /// 协议违规项(来自 [eBadgeValidate])。非空时调试页把整行标红 —— 收发方向
  /// 的配色让位于「这帧有问题」,因为后者更该被看见。
  final List<EBadgeViolation> violations;

  /// 结构合法但内容违反协议。区别于 [EBadgeLogKind.error]:那是传输/解析层面
  /// 的失败,这是帧本身解得出来、但不符合规范。
  bool get hasViolation => violations.isNotEmpty;

  factory EBadgeLogEntry.info(String text, {String? detail}) =>
      EBadgeLogEntry._(
        kind: EBadgeLogKind.info,
        title: text,
        detail: detail,
        at: DateTime.now(),
      );

  factory EBadgeLogEntry.error(String text, {String? detail}) =>
      EBadgeLogEntry._(
        kind: EBadgeLogKind.error,
        title: text,
        detail: detail,
        at: DateTime.now(),
      );

  /// 发出的帧同样过一遍校验 —— 本机组包错了要在自己这边就看见,别等设备回
  /// RESULT=FAILED 再猜。解不出来(理论上不该发生)就不校验,只记原始字节。
  factory EBadgeLogEntry.sendFrame(String label, Uint8List frame) {
    final cmd = frame.length > 1 ? frame[1] : 0;
    final decoded = EBadgeCodec.decode(frame);
    return EBadgeLogEntry._(
      kind: EBadgeLogKind.send,
      title: '0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')} '
          '${EBadgeCmd.name(cmd)} → $label',
      detail: '${frame.length}B',
      hex: EBadgeCodec.hex(frame, max: 96),
      at: DateTime.now(),
      violations: decoded.isOk
          ? eBadgeValidate(decoded.frame!)
          : const <EBadgeViolation>[],
    );
  }

  factory EBadgeLogEntry.sendRaw(String label, Uint8List bytes) =>
      EBadgeLogEntry._(
        kind: EBadgeLogKind.send,
        title: label,
        detail: '${bytes.length}B 裸数据',
        hex: EBadgeCodec.hex(bytes, max: 96),
        at: DateTime.now(),
      );

  factory EBadgeLogEntry.recvRaw(Uint8List bytes) => EBadgeLogEntry._(
        kind: EBadgeLogKind.recv,
        title: 'notify ${bytes.length}B',
        hex: EBadgeCodec.hex(bytes, max: 96),
        at: DateTime.now(),
      );

  factory EBadgeLogEntry.recvFrame(EBadgeFrame f) => EBadgeLogEntry._(
        kind: EBadgeLogKind.recv,
        title: '0x${f.cmd.toRadixString(16).toUpperCase().padLeft(2, '0')} '
            '${f.cmdName}',
        detail: eBadgeDescribe(f),
        hex: EBadgeCodec.hex(f.raw, max: 96),
        at: DateTime.now(),
        violations: eBadgeValidate(f),
      );

  String get timeText {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// 导出为一行纯文本,供「复制全部日志」使用。
  String toPlainText() {
    final arrow = switch (kind) {
      EBadgeLogKind.send => '→',
      EBadgeLogKind.recv => '←',
      EBadgeLogKind.info => 'ⓘ',
      EBadgeLogKind.error => '✗',
    };
    // 违规帧在导出文本里也要一眼可见 —— 复制出去贴给固件的人看不到界面颜色。
    final flag = hasViolation ? ' [!协议违规]' : '';
    final sb = StringBuffer('$timeText $arrow $title$flag');
    if (detail != null && detail!.isNotEmpty) sb.write('  | $detail');
    if (hex != null) sb.write('\n           $hex');
    for (final v in violations) {
      sb.write('\n           ! ${v.hint}');
    }
    return sb.toString();
  }
}
