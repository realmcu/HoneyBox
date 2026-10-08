import 'package:permission_handler/permission_handler.dart';

/// Matches FlutterBluePlus scanning with androidUsesFineLocation enabled.
/// permission_handler maps the Bluetooth groups to manifest grants below API 31.
Future<bool> requestAndroidBlePermissions() async {
  final scan = await Permission.bluetoothScan.request();
  final connect = await Permission.bluetoothConnect.request();
  if (!scan.isGranted || !connect.isGranted) return false;
  final location = await Permission.locationWhenInUse.request();
  return location.isGranted;
}
