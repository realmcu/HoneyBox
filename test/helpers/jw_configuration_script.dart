import 'dart:async';
import 'dart:typed_data';
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_configuration.dart';
import 'fake_jw_transport.dart';
import 'jw_fixture.dart';

class JwConfigurationScript {
  static const keys = <JwConfigurationDomain, (int, int, int, int)>{
    JwConfigurationDomain.hourSystem: (2, 0x41, 0x42, 0x43),
    JwConfigurationDomain.distanceUnit: (2, 0x44, 0x45, 0x46),
    JwConfigurationDomain.screenLightTime: (2, 0x4a, 0x4b, 0x4c),
    JwConfigurationDomain.screenBrightness: (2, 0x53, 0x54, 0x55),
    JwConfigurationDomain.heartRateAuto: (5, 0x0e, 0x11, 0x12),
    JwConfigurationDomain.bloodOxygenAuto: (5, 0x33, 0x34, 0x35),
    JwConfigurationDomain.bloodPressureAuto: (5, 0x3d, 0x3e, 0x3f),
    JwConfigurationDomain.temperatureConfig: (5, 0x22, 0x23, 0x24),
  };
  final values = <JwConfigurationDomain, Uint8List>{
    JwConfigurationDomain.hourSystem: jwHex('00'),
    JwConfigurationDomain.distanceUnit: jwHex('00'),
    JwConfigurationDomain.screenLightTime: jwHex('0a05'),
    JwConfigurationDomain.screenBrightness: jwHex('3c1e'),
    JwConfigurationDomain.heartRateAuto: jwHex('0000'),
    JwConfigurationDomain.bloodOxygenAuto: jwHex('0000'),
    JwConfigurationDomain.bloodPressureAuto: jwHex('0000'),
    JwConfigurationDomain.temperatureConfig: jwHex('00000001'),
  };
  Uint8List bpDisplay = Uint8List(4),
      powerSave = Uint8List(4),
      health = Uint8List(8);
  bool ignoreWrites = false;
  int? dropKey;
  Duration replyDelay = Duration.zero;
  void Function(JwMessage)? onRequest;
  final requests = <JwMessage>[];
  JwConfigurationScript(FakeJwTransport t) {
    final ordinary = t.onWrite!;
    t.onWrite = (bytes) {
      final frame = JwFrameDecoder().add(bytes).single;
      if (frame.ack) return;
      final m = JwCodec.decodeL2(frame.payload), f = m.fields.single;
      final match = keys.entries
          .where((e) =>
              e.value.$1 == m.command &&
              (e.value.$2 == f.key || e.value.$3 == f.key))
          .firstOrNull;
      if (match == null &&
          !(m.command == 5 && [0x25, 0x26, 0x2a, 0x3a].contains(f.key))) {
        ordinary(bytes);
        return;
      }
      requests.add(m);
      onRequest?.call(m);
      t.emitAck(frame.seq);
      if (f.key == dropKey) return;
      void reply(int key, Uint8List value) {
        final captured = Uint8List.fromList(value);
        if (replyDelay == Duration.zero) {
          t.emitMessage(m.command, key, captured);
        } else {
          Timer(replyDelay, () {
            if (!t.rx.isClosed) t.emitMessage(m.command, key, captured);
          });
        }
      }

      if (match != null) {
        final d = match.key, k = match.value;
        if (f.key == k.$2) {
          if (!ignoreWrites) {
            values[d] = d.isMonitor
                ? Uint8List.fromList([
                    f.value[0],
                    d == JwConfigurationDomain.bloodPressureAuto
                        ? 0
                        : f.value[0]
                  ])
                : d.hasScalarDefault
                    ? Uint8List.fromList([f.value[0], values[d]![1]])
                    : Uint8List.fromList(f.value);
            if (d == JwConfigurationDomain.bloodPressureAuto) {
              bpDisplay = jwHex(f.value[0] == 1 ? '80000000' : '00000000');
            }
          }
          if (d == JwConfigurationDomain.bloodPressureAuto) {
            reply(0x3f, values[d]!);
          }
        } else {
          reply(k.$4, values[d]!);
        }
      } else if (f.key == 0x26) {
        reply(0x27, bpDisplay);
      } else if (f.key == 0x25) {
        if (!ignoreWrites) bpDisplay = Uint8List.fromList(f.value);
      } else if (f.key == 0x2a) {
        reply(0x2b, powerSave);
      } else if (f.key == 0x3a) {
        reply(0x3b, health);
      }
    };
  }
  List<JwMessage> get sets => requests
      .where((m) =>
          keys.values
              .any((k) => k.$1 == m.command && k.$2 == m.fields.single.key) ||
          (m.command == 5 && m.fields.single.key == 0x25))
      .toList();
}
