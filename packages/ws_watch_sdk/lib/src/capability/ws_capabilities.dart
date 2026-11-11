import 'dart:typed_data';

import '../honey/honey_device.dart';

enum WSFeature {
  heartRate,
  bloodPressure,
  bloodOxygen,
  sleep,
  sport,
}

enum WSFeatureSupport { supported, unsupported, unknown }

/// 16-byte capability bitmap stub (HoneyProtocol `0x02` key `0x31`).
final class WSCapabilities {
  WSCapabilities(Uint8List raw)
      : raw = Uint8List.fromList(
          raw.length == HoneyDeviceCommand.capabilitiesBlobLength
              ? raw
              : throw ArgumentError(
                  'capabilities raw must be '
                  '${HoneyDeviceCommand.capabilitiesBlobLength} bytes',
                ),
        );

  final Uint8List raw;

  static WSCapabilities parse(Uint8List blob) => WSCapabilities(blob);

  WSFeatureSupport supportOf(WSFeature feature) {
    // Bit assignments are still TBD in HoneyProtocol; keep unknown.
    return WSFeatureSupport.unknown;
  }
}
