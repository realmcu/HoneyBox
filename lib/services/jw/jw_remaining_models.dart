import 'dart:typed_data';
import 'jw_configuration.dart';

Uint8List _immutable(List<int> bytes) =>
    Uint8List.fromList(bytes).asUnmodifiableView();
Never _invalid(List<int> raw, String cause) => throw JwConfigurationException(
    stage: 'invalid', raw: Uint8List.fromList(raw), cause: cause);

class JwAlarmRecord {
  final Uint8List raw;
  JwAlarmRecord(List<int> value) : raw = _immutable(value) {
    if (raw.length != 5) _invalid(raw, 'alarm record length');
    if (hour > 23 || minute > 59) _invalid(raw, 'alarm time');
  }
  int get packed => raw.fold(0, (a, b) => (a << 8) | b);
  int get year => 2000 + ((packed >> 34) & 63);
  int get month => (packed >> 30) & 15;
  int get day => (packed >> 25) & 31;
  int get hour => (packed >> 20) & 31;
  int get minute => (packed >> 14) & 63;
  int get id => (packed >> 11) & 7;
  int get repeatDays => packed & 127;
}

class JwAlarmTable {
  final Uint8List raw;
  late final List<JwAlarmRecord> records;
  JwAlarmTable(List<int> bytes) : raw = _immutable(bytes) {
    if (raw.length % 5 != 0 || raw.length > 100) {
      _invalid(raw, 'alarm table length/max20');
    }
    records = List.unmodifiable([
      for (var i = 0; i < raw.length; i += 5)
        JwAlarmRecord(raw.sublist(i, i + 5))
    ]);
  }
  Uint8List get normalizedRaw {
    final bytes = raw.toList();
    for (var i = 0; i < bytes.length; i += 5) {
      if ((bytes[i + 4] & 127) == 0) {
        bytes[i + 3] &= 0xf8;
        bytes[i + 4] = 0x80;
      }
    }
    return _immutable(bytes);
  }

  bool get roundTrippable {
    final normalized = normalizedRaw;
    return [for (var i = 0; i < raw.length; i++) raw[i] == normalized[i]]
        .every((x) => x);
  }
}

class JwSpO2PermissionReport {
  final Uint8List raw;
  JwSpO2PermissionReport(List<int> bytes) : raw = _immutable(bytes) {
    if (raw.length != 1 || (raw[0] != 2 && raw[0] != 3)) {
      _invalid(raw, 'SpO2 query enum2/3');
    }
  }
  bool get availableReported => raw.single == 3;
}

class JwSupportedSportTypes {
  final Uint8List raw;
  late final int mask;
  late final List<int> ukTypes;
  JwSupportedSportTypes(List<int> bytes) : raw = _immutable(bytes) {
    if (raw.length != 4 || (raw[0] & 0xf0) != 0) {
      _invalid(raw, 'sport mask length/unknown bits');
    }
    mask = ByteData.sublistView(raw).getUint32(0);
    ukTypes = List.unmodifiable([
      for (var i = 0; i < 28; i++)
        if ((mask & (1 << i)) != 0) i
    ]);
  }
}

class JwSportStatus {
  final Uint8List raw;
  JwSportStatus(List<int> bytes) : raw = _immutable(bytes) {
    if (raw.length != 3 ||
        raw[0] > 4 ||
        raw[1] > 2 ||
        (raw[1] == 0 ? raw[2] != 255 : (raw[2] < 1 || raw[2] > 27))) {
      _invalid(raw, 'sport result/state/type');
    }
  }
  int get result => raw[0];
  int get state => raw[1];
  int get sportType => raw[2];
  bool get operationAccepted => result <= 1;
}

class JwSubmission {
  final int command, key;
  final Uint8List raw;
  final Uint8List? responseRaw;
  final bool acknowledged;
  JwSubmission(this.command, this.key, List<int> value,
      {List<int>? response, this.acknowledged = true})
      : raw = _immutable(value),
        responseRaw = response == null ? null : _immutable(response);
}

class JwVerifiedChange<T> {
  final T before, requested, observed;
  final JwSubmission submission;
  const JwVerifiedChange(
      {required this.before,
      required this.requested,
      required this.observed,
      required this.submission});
}

class JwUserInfoSubmission {
  final List<JwSubmission> submissions;
  JwUserInfoSubmission(List<JwSubmission> values)
      : submissions = List.unmodifiable(values);
}

class JwCompoundSubmissionException implements Exception {
  final List<JwSubmission> acknowledged;
  final Object cause;
  JwCompoundSubmissionException(List<JwSubmission> values, this.cause)
      : acknowledged = List.unmodifiable(values);
  @override
  String toString() =>
      'Partial user-info submission (${acknowledged.length} ACKs): $cause';
}

/// S200 TUYA interpretation. Reading itself temporarily mutates runtime on_off.
class JwLongSitSettings {
  final Uint8List raw;
  JwLongSitSettings(List<int> value) : raw = _immutable(value) {
    if (raw.length != 8 || raw[1] > 1 || (raw[1] == 1 && !hasValidSchedule)) {
      _invalid(raw, 'S200 long-sit switch/minutes/hours');
    }
  }
  // Dormant bytes may come from older step-limit layouts. Preserve them only
  // while disabled; never enable a schedule whose time fields are invalid.
  bool get hasValidSchedule =>
      raw.length == 8 &&
      raw[2] <= 59 &&
      raw[3] <= 59 &&
      raw[5] <= 23 &&
      raw[6] <= 23;
  bool get enabled => raw[1] == 1;
  int get startMinute => raw[2];
  int get endMinute => raw[3];
  int get intervalMinutes => raw[4];
  int get startHour => raw[5];
  int get endHour => raw[6];
  JwLongSitSettings withEnabled(bool enabled) =>
      JwLongSitSettings(raw.toList()..[1] = enabled ? 1 : 0);
}
