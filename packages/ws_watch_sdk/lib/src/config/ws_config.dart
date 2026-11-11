final class WSLinkConfig {
  const WSLinkConfig({
    this.ackTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.chunkWriteTimeout = const Duration(seconds: 3),
    this.rxAssembleTimeout = const Duration(seconds: 5),
    this.maxPayloadLength = 65535,
  });

  final Duration ackTimeout;
  final int maxRetries;
  final Duration chunkWriteTimeout;
  final Duration rxAssembleTimeout;
  final int maxPayloadLength;
}

final class WSSessionConfig {
  const WSSessionConfig({
    this.replyTimeout = const Duration(seconds: 8),
    this.phoneSystem = 2,
  });

  final Duration replyTimeout;

  /// Honey `0x02` phone system: `1` iOS, `2` Android.
  final int phoneSystem;
}

final class WSConfig {
  const WSConfig({
    this.simulationEnabled = false,
    this.simulationExclusive = false,
    this.link = const WSLinkConfig(),
    this.session = const WSSessionConfig(),
    this.historyDatabasePath,
  });

  /// When true, registers the in-process Honey sim device.
  final bool simulationEnabled;

  /// When true (requires [simulationEnabled]), scan/connect never touch BLE;
  /// only [kWsWatchSimDeviceId] is advertised. For Demo until UART真机就绪.
  final bool simulationExclusive;
  final WSLinkConfig link;
  final WSSessionConfig session;
  final String? historyDatabasePath;
}
