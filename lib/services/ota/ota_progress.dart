class OtaProgressTracker {
  double _progress = 0;
  double update(
      {int? imageIndex,
      int? imageCount,
      num? currentPercent,
      num? overallProgress}) {
    final count = imageCount != null && imageCount > 0 ? imageCount : 1;
    final index = (imageIndex ?? 0).clamp(0, count - 1).toInt();
    final value = overallProgress ?? currentPercent;
    if (value == null || !value.isFinite) return _progress;
    final fraction = (value.toDouble() / 100).clamp(0.0, 1.0).toDouble();
    final next =
        overallProgress != null ? fraction : (index + fraction) / count;
    if (next > _progress) _progress = next;
    return _progress;
  }
}

/// Average DFU transfer speed over the current transfer phase.
///
/// The firmware package size includes package headers, so this is an
/// operational estimate rather than a wire-byte measurement.
double? otaTransferSpeedKBps({
  required int? firmwareBytes,
  required double? progress,
  required Duration elapsed,
}) {
  if (firmwareBytes == null ||
      firmwareBytes <= 0 ||
      progress == null ||
      !progress.isFinite ||
      progress <= 0 ||
      elapsed < const Duration(milliseconds: 500)) {
    return null;
  }
  final transferred = firmwareBytes * progress.clamp(0.0, 1.0);
  return transferred / elapsed.inMilliseconds * 1000 / 1024;
}

String formatOtaSpeed(double? kbPerSecond) {
  if (kbPerSecond == null || !kbPerSecond.isFinite || kbPerSecond <= 0) {
    return '—';
  }
  if (kbPerSecond < 1024) return '${kbPerSecond.toStringAsFixed(1)} KB/s';
  return '${(kbPerSecond / 1024).toStringAsFixed(2)} MB/s';
}

String formatOtaDuration(Duration duration) {
  final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}
