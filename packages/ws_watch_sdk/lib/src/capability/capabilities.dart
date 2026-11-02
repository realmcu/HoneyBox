import 'dart:typed_data';
import '../model/feature.dart';

class WSCapabilities {
  WSCapabilities.fromBytes(List<int> bytes)
      : raw = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.length != 16) {
      throw const FormatException('capabilities require 16 bytes');
    }
  }
  final Uint8List raw;
  WSFeatureSupport supportOf(WSFeature feature) => WSFeatureSupport.unknown;
}
