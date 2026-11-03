import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

String debugHex(Iterable<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

String formatDeviceReportValue(Object? value) {
  if (value == null) return '-';
  if (value is Uint8List) return debugHex(value);
  return value.toString();
}

String formatDeviceReportError(Object? error) {
  if (error == null) return '-';
  return error.toString();
}

int parseHexByte(String text, {int max = 255}) {
  final cleaned = text.trim().replaceFirst(RegExp(r'^0[xX]'), '');
  if (!RegExp(r'^[0-9a-fA-F]{1,2}$').hasMatch(cleaned)) {
    throw const FormatException('地址必须为 1～2 位十六进制');
  }
  final value = int.parse(cleaned, radix: 16);
  if (value > max) throw FormatException('地址超出范围 0～${max.toRadixString(16)}');
  return value;
}

List<int> parseDebugHex(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(cleaned)) {
    throw const FormatException('操作数据必须为完整 hex 字节，可用空格或换行分隔');
  }
  if (cleaned.length > 65530 * 2) throw const FormatException('操作数据过长');
  return [
    for (var i = 0; i < cleaned.length; i += 2)
      int.parse(cleaned.substring(i, i + 2), radix: 16)
  ];
}

class DemoActionResult {
  const DemoActionResult(this.traceId, this.label, this.startedAt, this.elapsed,
      this.value, this.error);
  final String traceId, label;
  final DateTime startedAt;
  final Duration elapsed;
  final Object? value, error;
}

/// Demo-only bounded capture. It listens before connecting, survives tool routes,
/// and uses only the public SDK observation API.
class DemoDebugCapture extends ChangeNotifier {
  DemoDebugCapture(this.watch,
      {this.maxFrames = 400,
      this.maxReports = 200,
      this.maxBytes = 512 * 1024}) {
    if (maxFrames < 1 || maxReports < 1 || maxBytes < 1) {
      throw ArgumentError('positive capture limits required');
    }
    _framesSub = watch.debug.frames.listen(addFrame);
    _reportsSub = watch.debug.reports.listen(addReport);
  }
  final WSWatch watch;
  final int maxFrames, maxReports, maxBytes;
  final _frames = Queue<WSFrameEvent>(), _reports = Queue<WSDeviceReport>();
  final _actions = Queue<DemoActionResult>();
  late final StreamSubscription<WSFrameEvent> _framesSub;
  late final StreamSubscription<WSDeviceReport> _reportsSub;
  int _bytes = 0, droppedFrames = 0, droppedReports = 0, skipped = 0;
  bool paused = false, _closed = false;
  int get retainedBytes => _bytes;
  List<WSFrameEvent> get frames => List.unmodifiable(_frames.toList().reversed);
  List<WSDeviceReport> get reports =>
      List.unmodifiable(_reports.toList().reversed);
  List<DemoActionResult> get actions =>
      List.unmodifiable(_actions.toList().reversed);
  void addFrame(WSFrameEvent frame) {
    if (_closed) return;
    if (paused) {
      skipped++;
      return;
    }
    final size = frame.raw.length + 256;
    if (size > maxBytes) {
      droppedFrames++;
      notifyListeners();
      return;
    }
    while (_frames.length >= maxFrames) {
      _evictFrame();
    }
    _makeRoom(size);
    _frames.add(frame);
    _bytes += size;
    notifyListeners();
  }

  void addReport(WSDeviceReport report) {
    if (_closed) return;
    if (paused) {
      skipped++;
      return;
    }
    final size = report.data.length + 256;
    if (size > maxBytes) {
      droppedReports++;
      notifyListeners();
      return;
    }
    while (_reports.length >= maxReports) {
      _evictReport();
    }
    _makeRoom(size);
    _reports.add(report);
    _bytes += size;
    notifyListeners();
  }

  void _evictFrame() {
    _bytes -= _frames.removeFirst().raw.length + 256;
    droppedFrames++;
  }

  void _evictReport() {
    _bytes -= _reports.removeFirst().data.length + 256;
    droppedReports++;
  }

  void _makeRoom(int size) {
    while (_bytes + size > maxBytes) {
      if (_reports.isEmpty ||
          _frames.isNotEmpty &&
              !_frames.first.time.isAfter(_reports.first.time)) {
        _evictFrame();
      } else {
        _evictReport();
      }
    }
  }

  void setPaused(bool value) {
    paused = value;
    notifyListeners();
  }

  void clear() {
    _frames.clear();
    _reports.clear();
    _actions.clear();
    _bytes = 0;
    droppedFrames = 0;
    droppedReports = 0;
    skipped = 0;
    notifyListeners();
  }

  static int _serial = 0;
  Future<T> run<T>(String label, Future<T> Function() action) async {
    final trace = 'demo-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';
    final at = DateTime.now(), timer = Stopwatch()..start();
    Object? value, error;
    try {
      final result = await watch.debug.trace(trace, action);
      value = result;
      return result;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      timer.stop();
      if (!_closed) {
        // Large query results belong to their feature page, not this log cache.
        final summary = value?.toString();
        _actions.add(DemoActionResult(
            trace,
            label,
            at,
            timer.elapsed,
            summary?.substring(0, summary.length.clamp(0, 2048)),
            error == null ? null : _short('${error.runtimeType}: $error')));
        while (_actions.length > 20) {
          _actions.removeFirst();
        }
        notifyListeners();
      }
    }
  }

  static String _short(String value) =>
      value.substring(0, value.length.clamp(0, 2048));
  String exportText({Iterable<WSFrameEvent>? selectedFrames}) {
    final snapshot = selectedFrames?.toList() ?? frames;
    final out = StringBuffer(
        'WS Watch Demo diagnostics v1\nExported: ${DateTime.now().toIso8601String()}\nSDK: $wsWatchSdkVersion\nFrames: ${snapshot.length}; reports: ${_reports.length}; retained bytes: $_bytes\nEvicted frames: $droppedFrames; reports: $droppedReports; paused skipped: $skipped\nRaw bytes may contain user/device data.\n\nACTIONS\n');
    for (final a in actions) {
      out.writeln(
          '${a.startedAt.toIso8601String()} ${a.label} trace=${a.traceId} elapsed=${a.elapsed.inMicroseconds}us value=${a.value} error=${a.error}');
    }
    out.writeln('\nFRAMES (newest first)');
    for (final f in snapshot) {
      out.writeln(formatFrame(f));
    }
    out.writeln(
        '\nUNMATCHED REPORTS (not automatically attributed to actions)');
    for (final r in reports) {
      out.writeln(
          '${r.time.toIso8601String()} generation=${r.connectionGeneration} ${r.kind.name} ${r.address ?? "malformed address"} value=${formatDeviceReportValue(r.value)} error=${formatDeviceReportError(r.error)}\n${debugHex(r.data)}');
    }
    return out.toString();
  }

  static String formatFrame(WSFrameEvent f) =>
      '${f.time.toIso8601String()} generation=${f.connectionGeneration} ${f.direction.name} ${f.kind.name} seq=${f.seq ?? "-"} trace=${f.traceId ?? "-"} request=${f.requestId ?? "-"}\n${f.keys.map((k) => '${k.address} ${k.name ?? "unknown"} ${k.status?.name ?? "unknown"}').join(' | ')}\n${debugHex(f.raw)}';
  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    unawaited(_framesSub.cancel());
    unawaited(_reportsSub.cancel());
    super.dispose();
  }
}
