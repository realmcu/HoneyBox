/// Public feature domains exposed by the JW SDK.
///
/// This is a stable product vocabulary, not a statement that every connected
/// device supports every capability. A future session reports a
/// [JWFeatureAvailability] for each value after it becomes ready.
enum JWFeature {
  connection,
  deviceInformation,
  settings,
  reminders,
  measurements,
  history,
  notifications,
  controls,
  sport,
  advancedHealth,
}

/// Per-device availability after JW capability discovery.
enum JWFeatureAvailability {
  /// The session has not yet read a trustworthy device capability list.
  unknown,

  /// The connected device or firmware does not expose this capability.
  unsupported,

  /// The connected device exposes this capability.
  supported,
}

/// SDK-facing capability result, deliberately separate from session state.
class JWFeatureSupport {
  const JWFeatureSupport({
    required this.feature,
    required this.availability,
    this.reason,
  });

  final JWFeature feature;
  final JWFeatureAvailability availability;

  /// A user-readable firmware, model, or protocol restriction when known.
  final String? reason;

  bool get isSupported => availability == JWFeatureAvailability.supported;
}
