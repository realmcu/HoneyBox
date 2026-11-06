/// Android V2 `BleProtocol.SportKey` names for debug log annotations (cmd `0x05`).
abstract final class JWSportKeyLabels {
  static const _byKey = <int, String>{
    0x0d: 'SPORTS_HRP_SINGLE_REQ',
    0x0e: 'SPORTS_HRP_CONTINUE_SET',
    0x0f: 'SPORTS_HRP_DATA_RSP',
    0x10: 'SPORTS_HRP_DEVICE_CANCEL_READ_HRP',
    0x11: 'SPORTS_HRP_CONTINUE_PARAMS_GET',
    0x12: 'SPORTS_HRP_CONTINUE_PARAMS_RSP',
    0x13: 'SPORTS_BP_DATA_RSP',
    0x14: 'SPORTS_BP_SINGLE_REQ',
    0x15: 'SPORTS_BP_CANCEL_READ',
    0x28: 'HR_DATA_RSP',
    0x2c: 'SPO2_DATA_RSP',
    0x2d: 'SPO2_SETTING',
    0x40: 'SYNC_START',
  };

  static String annotate(int command, int key) {
    if (command != 5) {
      return 'cmd=0x${_hex(command)} key=0x${_hex(key)}';
    }
    final name = _byKey[key];
    if (name == null) {
      return 'cmd=0x05(SPORT) key=0x${_hex(key)}';
    }
    return 'cmd=0x05(SPORT) key=0x${_hex(key)}($name)';
  }

  static String _hex(int b) => (b & 0xff).toRadixString(16).padLeft(2, '0').toUpperCase();
}
