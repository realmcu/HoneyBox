import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Android BLE scan/connect permissions for lab transport pages.
Future<void> ensureBleLabPermissions() async {
  if (!Platform.isAndroid) return;
  final scan = await Permission.bluetoothScan.request();
  final connect = await Permission.bluetoothConnect.request();
  if (scan.isGranted && connect.isGranted) return;
  if (!(await Permission.locationWhenInUse.request()).isGranted) {
    throw StateError('请授予蓝牙/定位权限以扫描设备');
  }
}
