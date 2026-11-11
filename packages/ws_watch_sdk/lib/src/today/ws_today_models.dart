/// Home-screen today totals (`0x05` key `0x61`, 23B wire layout).
final class WSTodaySnapshot {
  const WSTodaySnapshot({
    required this.dataTime,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesTenthKcal,
    required this.activeMinutes,
    required this.recentHeartRateBpm,
    required this.recentHeartRateTime,
  });

  final int dataTime;
  final int steps;
  final int distanceMeters;
  final int caloriesTenthKcal;
  final int activeMinutes;
  final int recentHeartRateBpm;
  final int recentHeartRateTime;
}
