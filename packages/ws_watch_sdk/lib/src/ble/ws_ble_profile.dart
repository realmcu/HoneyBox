import 'package:watch_transport_ble/watch_transport_ble.dart';

/// Nordic UART (Honey L0 UART profile) per HoneyProtocol architecture.
WatchBleProfile wsBleProfile() => WatchBleProfile(
      service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
      tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
      rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
    );
