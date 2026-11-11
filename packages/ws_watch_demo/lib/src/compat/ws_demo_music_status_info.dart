/// Mirrors Android V2 `WSMusicStatusInfo` (`cmd 0x07` / key `0x19`).
final class WSMusicStatusInfo {
  const WSMusicStatusInfo({
    required this.hasPlayer,
    required this.playing,
    required this.volumePercent,
  });

  final bool hasPlayer;
  final bool playing;

  /// Volume percent, `0`–`63`.
  final int volumePercent;
}
