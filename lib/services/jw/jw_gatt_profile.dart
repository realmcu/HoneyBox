abstract final class JwGattProfile {
  static const service = '000001ff-3c17-d293-8e48-14fe2e4da212';
  static const tx = '0000ff02-0000-1000-8000-00805f9b34fb';
  static const rx = '0000ff03-0000-1000-8000-00805f9b34fb';
  static String normalize(String uuid) {
    final text = uuid.toLowerCase();
    return text.length == 4 ? '0000$text-0000-1000-8000-00805f9b34fb' : text;
  }

  static bool matches(String serviceUuid, Set<String> characteristicUuids,
      {required bool txWrite, required bool rxNotify, bool allowJw = false}) {
    final chars = characteristicUuids.map(normalize).toSet();
    return allowJw &&
        normalize(serviceUuid) == service &&
        chars.contains(tx) &&
        chars.contains(rx) &&
        txWrite &&
        rxNotify;
  }
}
