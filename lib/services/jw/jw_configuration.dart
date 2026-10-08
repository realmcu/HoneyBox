import 'dart:typed_data';

enum JwConfigurationDomain {
  hourSystem,
  distanceUnit,
  screenLightTime,
  screenBrightness,
  heartRateAuto,
  bloodOxygenAuto,
  bloodPressureAuto,
  temperatureConfig,
}

enum JwConfigurationContract { v101S200 }

extension JwConfigurationDomainKind on JwConfigurationDomain {
  bool get isScalar => index < 4;
  bool get hasScalarDefault =>
      this == JwConfigurationDomain.screenLightTime ||
      this == JwConfigurationDomain.screenBrightness;
  bool get isMonitor => index >= 4 && index <= 6;
}

class JwConfigurationException implements Exception {
  final JwConfigurationDomain? domain;
  final String stage;
  final Uint8List raw;
  final Object? cause;
  // False proves no configuration SET was submitted; null means unknown.
  final bool? writeSubmitted;
  JwConfigurationException(
      {this.domain,
      required this.stage,
      Uint8List? raw,
      this.cause,
      this.writeSubmitted})
      : raw = Uint8List.fromList(raw ?? []).asUnmodifiableView();
  @override
  String toString() => 'JW configuration ${domain?.name ?? "preflight"} '
      '$stage${cause == null ? "" : ": $cause"}';
}

bool jwConfigurationBytesEqual(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

(int, int) _configurationScalarBounds(JwConfigurationDomain domain) =>
    switch (domain) {
      JwConfigurationDomain.screenLightTime => (3, 30),
      JwConfigurationDomain.screenBrightness => (20, 100),
      _ => (0, 1),
    };

class JwConfigurationValue {
  final JwConfigurationDomain domain;
  final Uint8List raw;
  final Uint8List? companionRaw;
  JwConfigurationValue(this.domain, Uint8List raw, {Uint8List? companionRaw})
      : raw = Uint8List.fromList(raw).asUnmodifiableView(),
        companionRaw = companionRaw == null
            ? null
            : Uint8List.fromList(companionRaw).asUnmodifiableView() {
    final size = domain.isScalar
        ? (domain.hasScalarDefault ? 2 : 1)
        : domain.isMonitor
            ? 2
            : 4;
    if (raw.length != size ||
        (domain == JwConfigurationDomain.bloodPressureAuto
            ? companionRaw?.length != 4
            : companionRaw != null)) {
      _invalid('configuration length or companion');
    }
    if (domain.isScalar) {
      final bounds = _configurationScalarBounds(domain);
      if (raw.any((value) => value < bounds.$1 || value > bounds.$2)) {
        _invalid('configuration range');
      }
    } else if (domain.isMonitor && raw[0] > 1) {
      _invalid('monitor enable enum');
    }
  }
  Never _invalid(String message) => throw JwConfigurationException(
      domain: domain, stage: 'invalid', raw: raw, cause: message);
  int? get scalarValue => domain.isScalar ? raw.first : null;
  int? get scalarDefault => domain.hasScalarDefault ? raw[1] : null;
  bool? get enabled => domain.isMonitor ? raw[0] == 1 : null;
  int? get intervalMinutes => null;
  int get _temperatureBits => ByteData.sublistView(raw).getUint32(0);
  bool? get displayEnabled => domain == JwConfigurationDomain.temperatureConfig
      ? (_temperatureBits & 1) != 0
      : null;
  bool? get compensate => domain == JwConfigurationDomain.temperatureConfig
      ? (_temperatureBits & 2) != 0
      : null;
  bool? get celsius => domain == JwConfigurationDomain.temperatureConfig
      ? (_temperatureBits & 4) == 0
      : null;
  bool? get bloodPressureDisplay =>
      companionRaw == null ? null : (companionRaw![0] & 0x80) != 0;
  bool get writable {
    if (domain == JwConfigurationDomain.temperatureConfig) {
      return (_temperatureBits & 0xfffffff8) == 0;
    }
    if (domain.isMonitor &&
        raw[1] !=
            (domain == JwConfigurationDomain.bloodPressureAuto ? 0 : raw[0])) {
      return false;
    }
    if (companionRaw != null &&
        (ByteData.sublistView(companionRaw!).getUint32(0) & 0x7fffffff) != 0) {
      return false;
    }
    return true;
  }

  bool sameValue(JwConfigurationValue other) =>
      domain == other.domain &&
      jwConfigurationBytesEqual(raw, other.raw) &&
      jwConfigurationBytesEqual(companionRaw, other.companionRaw);
}

class JwConfigurationChange {
  final JwConfigurationDomain domain;
  final int? scalarValue;
  final bool? enabled,
      displayEnabled,
      compensate,
      celsius,
      bloodPressureDisplay;
  const JwConfigurationChange._(this.domain,
      {this.scalarValue,
      this.enabled,
      this.displayEnabled,
      this.compensate,
      this.celsius,
      this.bloodPressureDisplay});
  factory JwConfigurationChange.scalar(
      JwConfigurationDomain domain, int value) {
    if (!domain.isScalar || value < 0 || value > 255) {
      throw JwConfigurationException(
          domain: domain, stage: 'invalid', cause: 'scalar domain/range');
    }
    final bounds = _configurationScalarBounds(domain);
    if (value < bounds.$1 || value > bounds.$2) {
      throw JwConfigurationException(
          domain: domain, stage: 'invalid', cause: 'scalar range');
    }
    return JwConfigurationChange._(domain, scalarValue: value);
  }
  factory JwConfigurationChange.monitor(
      JwConfigurationDomain domain, bool enabled,
      {bool? bloodPressureDisplay}) {
    if (!domain.isMonitor ||
        (bloodPressureDisplay != null &&
            domain != JwConfigurationDomain.bloodPressureAuto)) {
      throw JwConfigurationException(
          domain: domain, stage: 'invalid', cause: 'monitor domain/companion');
    }
    return JwConfigurationChange._(domain,
        enabled: enabled, bloodPressureDisplay: bloodPressureDisplay);
  }
  factory JwConfigurationChange.temperature(
      {bool? displayEnabled, bool? compensate, bool? celsius}) {
    if (displayEnabled == null && compensate == null && celsius == null) {
      throw JwConfigurationException(
          domain: JwConfigurationDomain.temperatureConfig,
          stage: 'invalid',
          cause: 'empty temperature change');
    }
    return JwConfigurationChange._(JwConfigurationDomain.temperatureConfig,
        displayEnabled: displayEnabled,
        compensate: compensate,
        celsius: celsius);
  }
}

class JwConfigurationSnapshot {
  final Map<JwConfigurationDomain, JwConfigurationValue> values;
  JwConfigurationSnapshot(
      Map<JwConfigurationDomain, JwConfigurationValue> values)
      : values = Map.unmodifiable(values) {
    if (values.length != 8 ||
        JwConfigurationDomain.values.any((d) => values[d]?.domain != d)) {
      throw JwConfigurationException(
          stage: 'invalid', cause: 'snapshot requires all eight domains');
    }
  }
}

class JwConfigurationWriteResult {
  final JwConfigurationValue before, requested, observed;
  const JwConfigurationWriteResult(
      {required this.before, required this.requested, required this.observed});
}

class JwConfigurationPreflight {
  final Uint8List powerSaveRaw, healthStatusRaw;
  final int battery;
  JwConfigurationPreflight(
      {required Uint8List powerSaveRaw,
      required Uint8List healthStatusRaw,
      required this.battery})
      : powerSaveRaw = Uint8List.fromList(powerSaveRaw).asUnmodifiableView(),
        healthStatusRaw =
            Uint8List.fromList(healthStatusRaw).asUnmodifiableView() {
    if (powerSaveRaw.length != 4 ||
        healthStatusRaw.length != 8 ||
        battery < 0 ||
        battery > 100) {
      throw JwConfigurationException(
          stage: 'invalid', cause: 'preflight length/battery');
    }
    if (ByteData.sublistView(powerSaveRaw).getUint32(0) > 1 ||
        healthStatusRaw.take(6).any((byte) => byte != 0) ||
        (healthStatusRaw[6] & 0xfc) != 0) {
      throw JwConfigurationException(
          stage: 'invalid', cause: 'unknown preflight bits');
    }
  }
  bool get eligible =>
      powerSaveRaw[3] == 0 &&
      (ByteData.sublistView(healthStatusRaw).getUint64(0) & 0x355) == 0;
}

/// Immutable partial read cache; the complete snapshot still requires eight domains.
class JwConfigurationValues {
  final Map<JwConfigurationDomain, JwConfigurationValue> values;
  JwConfigurationValues(Map<JwConfigurationDomain, JwConfigurationValue> values)
      : values = Map.unmodifiable(values);
}
