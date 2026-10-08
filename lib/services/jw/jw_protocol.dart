import 'dart:typed_data';
import 'jw_codec.dart';
import 'jw_models.dart';
import 'jw_configuration.dart';

class JwRequest {
  final int command;
  final int key;
  final Uint8List value;
  final int? responseKey;
  final int? responseCommand;
  final int? ackRetryLimit;
  final bool readOnly;
  final bool singleFieldReply;
  JwRequest(
      {required this.command,
      required this.key,
      Uint8List? value,
      this.responseKey,
      this.responseCommand,
      this.ackRetryLimit,
      this.singleFieldReply = false,
      required this.readOnly})
      : value = Uint8List.fromList(value ?? []).asUnmodifiableView();
}

abstract final class JwCommands {
  static JwRequest functionList() =>
      JwRequest(command: 2, key: 0x36, responseKey: 0x37, readOnly: true);
  static JwRequest factorySwitch() =>
      JwRequest(command: 6, key: 0x3d, responseKey: 0x3e, readOnly: true);
  static JwRequest language({bool singleFieldReply = false}) => JwRequest(
      command: 2,
      key: 0x4f,
      responseKey: 0x50,
      readOnly: true,
      singleFieldReply: singleFieldReply);
  static JwRequest _read(int command, int key, int response) => JwRequest(
      command: command,
      key: key,
      responseKey: response,
      readOnly: true,
      singleFieldReply: true);
  static JwRequest healthStatus() => _read(5, 0x3a, 0x3b);
  static JwRequest turnOverWrist() => _read(2, 0x2b, 0x2c);
  static JwRequest disturb() => _read(2, 0x48, 0x49);
  static JwRequest heatStressReminder() => _read(2, 0x87, 0x88);
  static JwRequest heartRateReminderDiagnostic() => _read(2, 0x76, 0x77);
  static JwRequest _identifier(int key, int responseKey, Uint8List id) {
    if (id.length != 32) {
      throw ArgumentError('JW identifier must contain 32 bytes');
    }
    return JwRequest(
        command: 3,
        key: key,
        value: id,
        responseKey: responseKey,
        readOnly: false);
  }

  static JwRequest login(Uint8List id) => _identifier(3, 4, id);
  static JwRequest bind(Uint8List id) => _identifier(1, 2, id);
  static JwRequest time(DateTime t) => JwRequest(
      command: 2, key: 1, value: JwProtocol.timeBytes(t), readOnly: false);
  static JwRequest setLanguage(int language) {
    RangeError.checkValueInInterval(language, 0, 2);
    return JwRequest(
        command: 2,
        key: 0x4e,
        value: Uint8List.fromList([language]),
        readOnly: false);
  }

  static JwRequest heartRateStreaming(bool enabled) => JwRequest(
      command: 5,
      key: 0x19,
      value: Uint8List.fromList([enabled ? 1 : 0]),
      responseKey: 0x1a,
      readOnly: false);
}

abstract final class JwProtocol {
  static Uint8List readResponse(
      JwMessage message, int command, int key, int size, String name) {
    final raw =
        message.fields.isEmpty ? Uint8List(0) : message.fields.first.value;
    if (message.command != command ||
        message.fields.length != 1 ||
        message.fields.single.key != key ||
        raw.length != size) {
      throw JwConfigurationException(
          stage: 'invalid', raw: raw, cause: '$name command/key/length');
    }
    return raw;
  }

  static int language(JwMessage message) {
    final raw = readResponse(message, 2, 0x50, 1, 'language');
    if (raw[0] > 2) {
      throw JwConfigurationException(
          stage: 'invalid', raw: raw, cause: 'language enum');
    }
    return raw[0];
  }

  static int battery(Uint8List? value) {
    if (value?.length != 1 || value!.single > 100) {
      throw JwConfigurationException(
          stage: 'invalid', raw: value, cause: 'battery unavailable/range');
    }
    return value.single;
  }

  static JwHealthStatus healthStatus(JwMessage message) =>
      JwHealthStatus(readResponse(message, 5, 0x3b, 8, 'health status'));
  static JwTurnOverWristStatus turnOverWrist(JwMessage message) =>
      JwTurnOverWristStatus(readResponse(message, 2, 0x2c, 1, 'wrist'));
  static JwDisturbStatus disturb(JwMessage message) =>
      JwDisturbStatus(readResponse(message, 2, 0x49, 3, 'DND'));
  static JwHeatStressReminderStatus heatStressReminder(JwMessage message) =>
      JwHeatStressReminderStatus(
          readResponse(message, 2, 0x88, 3, 'heat window'));
  static JwHeartRateReminderDiagnostic heartRateReminderDiagnostic(
          JwMessage message) =>
      JwHeartRateReminderDiagnostic(
          readResponse(message, 2, 0x77, 2, 'high HR diagnostic'));

  static Uint8List timeBytes(DateTime t) {
    if (t.year < 2000 || t.year > 2063) throw RangeError('JW year');
    final y = t.year - 2000;
    return Uint8List.fromList([
      (y << 2) | (t.month >> 2),
      ((t.month & 3) << 6) | (t.day << 1) | (t.hour >> 4),
      ((t.hour & 15) << 4) | (t.minute >> 2),
      ((t.minute & 3) << 6) | t.second
    ]);
  }

  static List<JwHeartRateSample> heartRates(JwMessage message) {
    if (message.command != 5) return [];
    final samples = <JwHeartRateSample>[];
    for (final f in message.fields) {
      if (f.key != 0x0f && f.key != 0x28) continue;
      final bytes = f.value;
      final size = f.key == 0x28 ? 8 : 4;
      if (bytes.length < 4) throw const FormatException('JW heart header');
      final data = ByteData.sublistView(bytes);
      final dateWord = data.getUint16(0);
      final count = data.getUint16(2);
      if (bytes.length != 4 + count * size) {
        throw const FormatException('JW heart count');
      }
      final year = 2000 + ((dateWord >> 9) & 63);
      final month = (dateWord >> 5) & 15;
      final day = dateWord & 31;
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        throw const FormatException('JW heart date');
      }
      for (var i = 0; i < count; i++) {
        final offset = 4 + i * size;
        // Both layouts end with minute:u16, second:u8, HR:u8 in big endian.
        final minute = data.getUint16(offset + size - 4);
        final second = bytes[offset + size - 2];
        final bpm = bytes[offset + size - 1];
        if (minute >= 1440 || second >= 60) {
          throw const FormatException('JW heart time');
        }
        if (bpm == 0) continue;
        samples.add(JwHeartRateSample(
            bpm: bpm,
            date: date,
            minute: minute,
            second: second,
            receivedAt: DateTime.now(),
            raw: bytes.sublist(offset, offset + size)));
      }
    }
    return samples;
  }
}

abstract final class JwConfigurationCodec {
  static const _keys = <JwConfigurationDomain, (int, int, int, int)>{
    JwConfigurationDomain.hourSystem: (2, 0x41, 0x42, 0x43),
    JwConfigurationDomain.distanceUnit: (2, 0x44, 0x45, 0x46),
    JwConfigurationDomain.screenLightTime: (2, 0x4a, 0x4b, 0x4c),
    JwConfigurationDomain.screenBrightness: (2, 0x53, 0x54, 0x55),
    JwConfigurationDomain.heartRateAuto: (5, 0x0e, 0x11, 0x12),
    JwConfigurationDomain.bloodOxygenAuto: (5, 0x33, 0x34, 0x35),
    JwConfigurationDomain.bloodPressureAuto: (5, 0x3d, 0x3e, 0x3f),
    JwConfigurationDomain.temperatureConfig: (5, 0x22, 0x23, 0x24),
  };
  static JwRequest readRequest(JwConfigurationDomain domain) {
    final k = _keys[domain]!;
    return JwRequest(
        command: k.$1, key: k.$3, responseKey: k.$4, readOnly: true);
  }

  static JwConfigurationValue parse(
      JwConfigurationDomain domain, JwMessage message,
      {JwMessage? companion}) {
    final k = _keys[domain]!;
    Uint8List field(JwMessage m, int command, int key) {
      if (m.command != command ||
          m.fields.length != 1 ||
          m.fields.single.key != key) {
        throw JwConfigurationException(
            domain: domain,
            stage: 'invalid',
            cause: 'configuration command/key/count');
      }
      return m.fields.single.value;
    }

    final raw = field(message, k.$1, k.$4);
    if (domain == JwConfigurationDomain.bloodPressureAuto) {
      if (companion == null) {
        throw JwConfigurationException(
            domain: domain,
            stage: 'invalid',
            raw: raw,
            cause: 'BP companion missing');
      }
      return JwConfigurationValue(domain, raw,
          companionRaw: field(companion, 5, 0x27));
    }
    if (companion != null) {
      throw JwConfigurationException(
          domain: domain,
          stage: 'invalid',
          raw: raw,
          cause: 'unexpected companion');
    }
    return JwConfigurationValue(domain, raw);
  }

  static void _writable(JwConfigurationValue value) {
    if (!value.writable) {
      throw JwConfigurationException(
          domain: value.domain,
          stage: 'unsupported',
          raw: value.raw,
          cause: 'noncanonical or reserved configuration bits');
    }
  }

  static JwConfigurationValue target(
      JwConfigurationValue before, JwConfigurationChange change) {
    _writable(before);
    if (before.domain != change.domain) {
      throw JwConfigurationException(
          domain: change.domain,
          stage: 'invalid',
          cause: 'change domain differs from baseline');
    }
    final domain = before.domain;
    if (domain.isScalar) {
      return JwConfigurationValue(
          domain,
          Uint8List.fromList([
            change.scalarValue!,
            if (domain.hasScalarDefault) before.raw[1]
          ]));
    }
    if (domain.isMonitor) {
      final e = change.enabled! ? 1 : 0;
      var companion = before.companionRaw;
      if (change.bloodPressureDisplay != null) {
        companion = Uint8List.fromList(
            [change.bloodPressureDisplay! ? 0x80 : 0, 0, 0, 0]);
      }
      return JwConfigurationValue(
          domain,
          Uint8List.fromList(
              [e, domain == JwConfigurationDomain.bloodPressureAuto ? 0 : e]),
          companionRaw: companion);
    }
    var bits = ByteData.sublistView(before.raw).getUint32(0);
    for (final pair in [
      (1, change.displayEnabled),
      (2, change.compensate),
      (4, change.celsius == null ? null : !change.celsius!)
    ]) {
      if (pair.$2 != null) {
        bits = pair.$2! ? (bits | pair.$1) : (bits & ~pair.$1);
      }
    }
    final data = ByteData(4)..setUint32(0, bits);
    return JwConfigurationValue(domain, data.buffer.asUint8List());
  }

  static JwRequest writeRequest(JwConfigurationValue target) {
    _writable(target);
    final k = _keys[target.domain]!;
    var raw = target.raw;
    if (target.domain.hasScalarDefault) {
      raw = Uint8List.fromList([target.raw[0]]);
    }
    if (target.domain.isMonitor) {
      raw = Uint8List.fromList([
        target.raw[0],
        target.domain == JwConfigurationDomain.bloodOxygenAuto &&
                target.raw[0] == 0
            ? 0
            : 1
      ]);
    }
    return JwRequest(
        command: k.$1,
        key: k.$2,
        value: raw,
        responseKey: target.domain == JwConfigurationDomain.bloodPressureAuto
            ? 0x3f
            : null,
        readOnly: false);
  }

  static JwRequest? companionReadRequest(JwConfigurationDomain domain) =>
      domain == JwConfigurationDomain.bloodPressureAuto
          ? JwRequest(command: 5, key: 0x26, responseKey: 0x27, readOnly: true)
          : null;
  static JwRequest? companionWriteRequest(JwConfigurationValue value) {
    _writable(value);
    return value.domain == JwConfigurationDomain.bloodPressureAuto
        ? JwRequest(
            command: 5, key: 0x25, value: value.companionRaw!, readOnly: false)
        : null;
  }
}
