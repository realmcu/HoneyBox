import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'app_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.init(); // runtime-accurate version for the update check/footer
  runApp(const ProviderScope(child: HoneyBoxApp()));
}
