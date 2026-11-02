enum WSWireDirection { phoneToDevice, deviceToPhone }

/// Complete wire identity; setting operations share a key but not an address.
class WSProtocolAddress {
  const WSProtocolAddress(
      {required this.cmd,
      required this.version,
      required this.key,
      required this.direction,
      this.settingOpcode});
  final int cmd, version, key;
  final int? settingOpcode;
  final WSWireDirection direction;

  void validate() {
    RangeError.checkValueInInterval(cmd, 0, 255, 'cmd');
    RangeError.checkValueInInterval(version, 0, 15, 'version');
    RangeError.checkValueInInterval(key, 0, 255, 'key');
    if (cmd == 2) {
      if (settingOpcode == null) {
        throw ArgumentError('settings require an opcode');
      }
      RangeError.checkValueInInterval(settingOpcode!, 0, 255, 'settingOpcode');
    } else if (settingOpcode != null) {
      throw ArgumentError('only settings may contain an opcode');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WSProtocolAddress &&
      cmd == other.cmd &&
      version == other.version &&
      key == other.key &&
      settingOpcode == other.settingOpcode &&
      direction == other.direction;
  @override
  int get hashCode => Object.hash(cmd, version, key, settingOpcode, direction);
  @override
  String toString() =>
      '${cmd.toRadixString(16)}/$version/${key.toRadixString(16)}'
      '/${settingOpcode?.toRadixString(16) ?? "-"}/${direction.name}';
}

/// Public DTO used by raw queries; replies must be device-to-phone.
typedef WSReplyAddress = WSProtocolAddress;
