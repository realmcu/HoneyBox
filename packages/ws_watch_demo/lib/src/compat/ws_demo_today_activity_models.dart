/// Device-reported today activity totals (HL §5.0C), not from local DB.
/// Demo alias matching JW Demo UI.
final class WSTodayActivitySummary {
  const WSTodayActivitySummary({
    required this.steps,
    required this.caloriesCal,
    required this.distanceMeters,
    this.slotOffset = 0,
    this.recentSteps = 0,
    this.recentCaloriesCal = 0,
    this.recentDistanceMeters = 0,
  });

  /// Day cumulative steps from the watch.
  final int steps;

  /// Day cumulative energy in **calories** (卡), same units as HL §5.0C.
  final int caloriesCal;

  /// Day cumulative distance in **meters**.
  final int distanceMeters;

  /// Sync slot offset reported by firmware (`0–95` when valid).
  final int slotOffset;

  /// Current 15-minute window (when present in the payload).
  final int recentSteps;
  final int recentCaloriesCal;
  final int recentDistanceMeters;

  /// Kilocalories for UI, aligned with Uk `caloryCount / 1000f`.
  double get caloriesKcal => caloriesCal / 1000;

  /// Kilometers for UI, aligned with Uk `distanceCount / 1000f`.
  double get distanceKm => distanceMeters / 1000;
}
