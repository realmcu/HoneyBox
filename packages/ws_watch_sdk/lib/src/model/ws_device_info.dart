final class WSDeviceInfo {
  const WSDeviceInfo({
    required this.deviceMac,
    this.name,
    this.modelId,
    this.serialNumber,
  });

  final String deviceMac;
  final String? name;

  /// Protocol `0x02` / key `0x30` model field when read from the watch.
  final int? modelId;

  /// Serial from the device-info reply when the firmware provides it.
  final String? serialNumber;
}
