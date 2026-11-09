import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:watch_frame_channel/watch_frame_channel.dart';

import '../connection/jw_protocol.dart';
import '../history/jw_history_models.dart';
import 'jw_sport_key_labels.dart';

/// JW SDK protocol logging. Filter logcat / Xcode with tag [logName].
abstract final class JWWatchDebugLog {
  static bool enabled = !_release;

  static const bool _release =
      bool.fromEnvironment('dart.vm.product', defaultValue: false);

  static const String logName = 'JWWatchSDK';

  static void apiIn(String symbol, [String? detail]) {
    if (!enabled) return;
    final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
    _log('API→ $symbol$suffix');
  }

  static void apiOut(String symbol, [String? detail]) {
    if (!enabled) return;
    final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
    _log('API← $symbol$suffix');
  }

  static void _log(String message) {
    developer.log('${_timestamp()} $message', name: logName);
  }

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static void wireFrame(WatchFrameEvent event, {int? awaitingAckSeq}) {
    if (!enabled) return;

    if (event.direction == WatchFrameDirection.tx &&
        (event.kind == WatchFrameKind.data ||
            event.kind == WatchFrameKind.retry)) {
      return;
    }

    if (event.kind == WatchFrameKind.chunk) {
      if (event.direction != WatchFrameDirection.tx) return;
      final raw = Uint8List.fromList(event.raw);
      if (raw.isEmpty || raw[0] != 0xab) {
        _log('WIRE tx seq=${event.seq ?? '?'} len=${raw.length} ${_hex(raw)}');
        return;
      }
      if (_isAckFrame(raw)) return;
      _logCompleteFrame(
        direction: 'tx',
        raw: raw,
        awaitingAckSeq: awaitingAckSeq,
      );
      return;
    }

    if (event.raw.isEmpty) return;
    final raw = Uint8List.fromList(event.raw);
    if (raw[0] != 0xab || raw.length < 8) {
      _log('WIRE ${event.direction.name} seq=${event.seq ?? '?'} ${_hex(raw)}');
      return;
    }

    _logCompleteFrame(
      direction: event.direction.name,
      raw: raw,
      awaitingAckSeq: awaitingAckSeq,
    );
  }

  static void _logCompleteFrame({
    required String direction,
    required Uint8List raw,
    int? awaitingAckSeq,
  }) {
    final flags = raw[1];
    final payloadLen = (raw[2] << 8) | raw[3];
    final seq = (raw[6] << 8) | raw[7];
    final isAck = (flags & 0x10) != 0;
    final buf = StringBuffer('WIRE $direction seq=$seq');

    if (isAck) {
      buf.write(' ack=${(flags & 0x20) != 0 ? 0 : 1}');
      if (awaitingAckSeq != null &&
          direction == 'rx' &&
          awaitingAckSeq == seq) {
        buf.write(' matchesOutboundTx=$seq');
      }
    } else if (direction == 'rx') {
      buf.write(' ack=${(flags & 0x40) != 0 ? 0 : 1}');
      if (payloadLen > 0 && raw.length >= 8 + payloadLen) {
        final l2 = raw.sublist(8, 8 + payloadLen);
        if (l2.length >= 3) {
          buf.write(' ${JWSportKeyLabels.annotate(l2[0], l2[2])}');
        }
      }
    } else if (payloadLen > 0 && raw.length >= 8 + payloadLen) {
      final l2 = raw.sublist(8, 8 + payloadLen);
      if (l2.length >= 3) {
        buf.write(' ${JWSportKeyLabels.annotate(l2[0], l2[2])}');
      }
    }

    buf.write(' ${_hex(raw)}');
    _log(buf.toString());
  }

  static bool _isAckFrame(Uint8List raw) {
    if (raw.length < 8 || raw[0] != 0xab) return false;
    return (raw[1] & 0x10) != 0 && ((raw[2] << 8) | raw[3]) == 0;
  }

  static void l2DecodeFailed(Uint8List l2Bytes, Object error, {int? l1Seq}) {
    if (!enabled) return;
    _log(
      'WIRE decode FAILED l1Seq=${l1Seq ?? '?'} l2=${_hex(l2Bytes)} error=$error',
    );
  }

  static void l2MatchedBusinessReply({
    required JWProtocolRequest request,
    required JWProtocolMessage reply,
    int? outboundSeq,
  }) {
    if (!enabled) return;
    _log(
      'API← JWLink.request matched outboundSeq=${outboundSeq ?? '?'} '
      'sent=${describeRequest(request)} '
      'reply=${describeMessage(reply)}',
    );
  }

  static String describeRequest(JWProtocolRequest request) {
    final value = request.value ?? Uint8List(0);
    final rk = request.responseKey;
    final keyPart = request.command == 5
        ? JWSportKeyLabels.annotate(request.command, request.key)
        : 'cmd=0x${_hexByte(request.command)} key=0x${_hexByte(request.key)}';
    return '$keyPart responseKey=${rk != null ? '0x${_hexByte(rk)}' : 'none'} '
        'value(${value.length})${_valuePreview(value)}';
  }

  static String describeMessage(JWProtocolMessage message) {
    if (message.command == 5) {
      return '${JWSportKeyLabels.annotate(message.command, message.key)} '
          'value(${message.value.length})${_valuePreview(message.value)}';
    }
    return 'cmd=0x${_hexByte(message.command)} key=0x${_hexByte(message.key)} '
        'value(${message.value.length})${_valuePreview(message.value)}';
  }

  static String formatHeartRates(List<JWHeartRate> batch) {
    if (batch.isEmpty) return '(empty)';
    return batch
        .map((h) =>
            'JWHeartRate(bpm=${h.heartRate}, time=${h.time.toIso8601String()})')
        .join(', ');
  }

  static String formatBloodPressures(List<JWBloodPressure> batch) {
    if (batch.isEmpty) return '(empty)';
    return batch
        .map((b) =>
            'JWBloodPressure(${b.systolic}/${b.diastolic}, time=${b.time.toIso8601String()})')
        .join(', ');
  }

  static String formatBloodOxygen(List<JWBloodOxygen> batch) {
    if (batch.isEmpty) return '(empty)';
    return batch
        .map((o) => 'JWBloodOxygen(${o.value}%, time=${o.time.toIso8601String()})')
        .join(', ');
  }

  static String formatTemperatures(List<JWTemperature> batch) {
    if (batch.isEmpty) return '(empty)';
    return batch
        .map((t) =>
            'JWTemperature(skin=${t.skinTemperature}, time=${t.time.toIso8601String()})')
        .join(', ');
  }

  static String formatBloodGlucose(List<JWBloodGlucose> batch) {
    if (batch.isEmpty) return '(empty)';
    return batch
        .map((g) =>
            'JWBloodGlucose(value=${g.value}, time=${g.time.toIso8601String()})')
        .join(', ');
  }

  static String hexBytes(Uint8List bytes) => _hex(bytes);

  static String _valuePreview(Uint8List value) {
    if (value.isEmpty) return ' (empty)';
    return ' ${_hex(value)}';
  }

  static String _hex(Uint8List bytes) {
    if (bytes.isEmpty) return '(empty)';
    final sb = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i > 0) sb.write(' ');
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }

  static String _hexByte(int b) =>
      (b & 0xff).toRadixString(16).padLeft(2, '0').toUpperCase();
}
