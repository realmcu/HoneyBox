import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Demo-only persistence for the last successfully connected WS watch (isolated from JW).
@immutable
final class WsDemoLastDevice {
  const WsDemoLastDevice(
      {required this.name, required this.deviceMac, this.isSimulated = false});

  final String name;
  final String deviceMac;
  final bool isSimulated;

  Map<String, Object> toJson() => {
        'name': name,
        'deviceMac': deviceMac,
        'isSimulated': isSimulated,
      };

  static WsDemoLastDevice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final mac = raw['deviceMac'];
    if (name is! String || mac is! String) return null;
    final trimmedMac = mac.trim();
    if (trimmedMac.isEmpty) return null;
    return WsDemoLastDevice(
      name: name.trim().isEmpty ? 'WS 设备' : name.trim(),
      deviceMac: trimmedMac,
      isSimulated: raw["isSimulated"] == true ||
          trimmedMac == "ws-watch-simulator" ||
          trimmedMac == "ws-watch-simulator-2",
    );
  }
}

abstract final class WsDemoLastDeviceStore {
  static const _fileName = 'ws_demo_last_device.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<WsDemoLastDevice?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return WsDemoLastDevice.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(WsDemoLastDevice device) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(device.toJson()));
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
