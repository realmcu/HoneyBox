import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'demo_home.dart';

/// 独立运行使用：`runApp(const WSWatchDemoApp())`。
class WSWatchDemoApp extends StatelessWidget {
  const WSWatchDemoApp({super.key, this.config = const WSConfig()});

  final WSConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WS Watch Demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        useMaterial3: true,
      ),
      home: WSWatchDemoHome(config: config),
    );
  }
}
