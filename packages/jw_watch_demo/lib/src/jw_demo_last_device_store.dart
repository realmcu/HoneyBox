import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Demo-only persistence for the last successfully connected JW watch.
@immutable
final class JwDemoLastDevice {
  const JwDemoLastDevice(
      {required this.name, required this.deviceMac, this.isSimulated = false});

  final String name;
  final String deviceMac;
  final bool isSimulated;

  Map<String, Object> toJson() => {
        'name': name,
        'deviceMac': deviceMac,
        'isSimulated': isSimulated,
      };

  static JwDemoLastDevice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final mac = raw['deviceMac'];
    if (name is! String || mac is! String) return null;
    final trimmedMac = mac.trim();
    if (trimmedMac.isEmpty) return null;
    return JwDemoLastDevice(
      name: name.trim().isEmpty ? 'JW 设备' : name.trim(),
      deviceMac: trimmedMac,
      isSimulated: raw['isSimulated'] == true,
    );
  }
}

abstract final class JwDemoLastDeviceStore {
  static const _fileName = 'jw_demo_last_device.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<JwDemoLastDevice?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return JwDemoLastDevice.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(JwDemoLastDevice device) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(device.toJson()));
  }
}
