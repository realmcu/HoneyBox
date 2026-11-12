final class WSLinkConfig {
  const WSLinkConfig({
    /// Per-attempt wait for an L1 success ACK after the full frame is written.
    this.ackTimeout = const Duration(seconds: 5),
    /// Extra L1 resends with the same seq after timeout or ERR ACK.
    this.maxRetries = 3,
    this.chunkWriteTimeout = const Duration(seconds: 3),
    this.rxAssembleTimeout = const Duration(seconds: 5),
    this.maxPayloadLength = 65535,
  });

  final Duration ackTimeout;
  final int maxRetries;

  /// Upper bound for one `WSLink.request` / `send` at L1 only:
  /// `ackTimeout * (maxRetries + 1)` before [WSErrorCode.ackTimeout].
  Duration get l1WorstCase => ackTimeout * (maxRetries + 1);
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

  /// WS `0x02` phone system: `1` iOS, `2` Android.
  final int phoneSystem;
}

/// Which physical or in-process transport [WSWatch] uses for its lifetime.
///
/// Chosen when constructing [WSWatch] (typically via [WSWatch.initialize]).
/// Scan/connect APIs stay the same; the active profile decides whether the
/// scanner talks to BLE, an in-process simulator, or (future) UART.
enum WSTransportMode {
  /// In-process Honey protocol simulator only.
  simulation,

  /// Platform BLE scanner + NUS GATT ([wsBleProfile]).
  ble,

  // Future: serial / UART profile on desktop or embedded harness.
}

final class WSConfig {
  const WSConfig({
    this.simulationEnabled = false,
    this.simulationExclusive = false,
    this.link = const WSLinkConfig(),
    this.session = const WSSessionConfig(),
    this.historyDatabasePath,
  });

  /// In-process simulator only (no BLE scan).
  const WSConfig.simulation()
      : simulationEnabled = true,
        simulationExclusive = true,
        link = const WSLinkConfig(),
        session = const WSSessionConfig(),
        historyDatabasePath = null;

  /// BLE NUS transport only (no simulator registration).
  const WSConfig.ble()
      : simulationEnabled = false,
        simulationExclusive = false,
        link = const WSLinkConfig(),
        session = const WSSessionConfig(),
        historyDatabasePath = null;

  /// When true, registers the in-process WS sim device.
  final bool simulationEnabled;

  /// When true (requires [simulationEnabled]), [WSWatch.startScan] does not use
  /// the platform BLE scanner; only the in-process simulator is listed.
  final bool simulationExclusive;
  final WSLinkConfig link;
  final WSSessionConfig session;
  final String? historyDatabasePath;

  /// Resolved transport for this config. Unsupported flag combinations throw.
  WSTransportMode get transportMode {
    if (simulationEnabled && simulationExclusive) {
      return WSTransportMode.simulation;
    }
    if (!simulationEnabled && !simulationExclusive) {
      return WSTransportMode.ble;
    }
    throw StateError(
      'Use WSConfig.simulation(), WSConfig.ble(), or WSConfig.forTransportMode(); '
      'mixed simulation flags are not supported.',
    );
  }

  /// Builds the supported init-time profiles ([WSTransportMode]).
  static WSConfig forTransportMode(WSTransportMode mode) => switch (mode) {
        WSTransportMode.simulation => const WSConfig.simulation(),
        WSTransportMode.ble => const WSConfig.ble(),
      };

  /// Whether [WSWatch.startScan] may invoke the platform BLE scanner.
  bool get usesBleScan => !simulationExclusive;
}
