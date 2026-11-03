import 'dart:async';
import 'package:watch_transport/watch_transport.dart';
import 'connection.dart';

typedef WatchSimulationDeviceFactory = FutureOr<WatchSimulationDeviceSession>
    Function(WatchSimulationConnection peer);

/// Owns only the device behavior for one connection (timers, subscriptions, etc).
final class WatchSimulationDeviceSession {
  WatchSimulationDeviceSession({required Future<void> Function() dispose})
      : _release = dispose;
  final Future<void> Function() _release;
  Future<void>? _closing;
  Future<void> dispose() => _closing ??= Future.sync(_release);
}

final class WatchSimulationDevice {
  WatchSimulationDevice({
    required this.id,
    required this.name,
    required this.attach,
    this.maxWriteLength = 244,
    this.connectTimeout = const Duration(seconds: 15),
  }) {
    WatchDeviceTarget(transportId: 'simulation', deviceId: id);
    WatchWriteLimits(maxWriteLength: maxWriteLength);
    if (connectTimeout <= Duration.zero) {
      throw ArgumentError.value(connectTimeout, 'connectTimeout');
    }
  }
  final String id, name;
  final int maxWriteLength;
  final Duration connectTimeout;
  final WatchSimulationDeviceFactory attach;
  WatchDeviceTarget get target =>
      WatchDeviceTarget(transportId: 'simulation', deviceId: id);
}

/// A registry is also the ownership scope for its virtual devices.
/// Capture persistent device state in attach; every connect creates fresh peers.
final class WatchSimulationTransport implements WatchTransport {
  final _devices = <String, WatchSimulationDevice>{};
  final _owners = <String, WatchSimulationConnection>{};

  List<WatchSimulationDevice> get devices => List.unmodifiable(_devices.values);

  void register(WatchSimulationDevice device) {
    if (_devices.containsKey(device.id)) {
      throw ArgumentError('Duplicate simulated device');
    }
    _devices[device.id] = device;
  }

  @override
  WatchSimulationConnection createConnection(WatchDeviceTarget target) {
    if (target.transportId != 'simulation') {
      throw const WatchTransportException(
          WatchTransportErrorCode.unsupported, 'Expected simulation target');
    }
    final device = _devices[target.deviceId];
    if (device == null) {
      throw const WatchTransportException(
          WatchTransportErrorCode.deviceNotFound, 'Unknown simulated device');
    }
    final (host, peer) = WatchSimulationConnection.pair(
        target: target,
        maxWriteLength: device.maxWriteLength,
        connectTimeout: device.connectTimeout);
    WatchSimulationDeviceSession? session;
    host.onConnect = () async {
      if (_owners.containsKey(device.id)) {
        throw const WatchTransportException(
            WatchTransportErrorCode.busy, 'Simulated device already in use');
      }
      _owners[device.id] = host;
      await peer.connect();
      if (host.state != WatchTransportState.connecting) return;
      final attached = await device.attach(peer);
      if (host.state != WatchTransportState.connecting) {
        await attached.dispose();
        return;
      }
      session = attached;
    };
    host.onDisconnect = () async {
      try {
        await session?.dispose();
      } finally {
        try {
          await peer.dispose();
        } finally {
          if (identical(_owners[device.id], host)) _owners.remove(device.id);
        }
      }
    };
    return host;
  }
}
