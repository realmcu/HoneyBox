import 'dart:convert';
import 'dart:typed_data';

class WSDeviceInfo {
  WSDeviceInfo.fromBytes(List<int> bytes)
      : raw = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.length < 17 || bytes[16] > 32 || bytes.length < 17 + bytes[16]) {
      throw const FormatException('invalid device information length');
    }
    serialNumber = ascii.decode(bytes.sublist(17, 17 + bytes[16]));
  }
  final Uint8List raw;
  late final String serialNumber;
  int get model => (raw[0] << 8) | raw[1];
  String get firmwareVersion =>
      '${raw[2]}.${raw[3]}.${raw[4]}+${(raw[5] << 8) | raw[6]}';
  int get protocolVersion => raw[7];
  int get hardwareVersion => raw[8];
  int get chipType => raw[9];
  String get btMac => raw
      .sublist(10, 16)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
