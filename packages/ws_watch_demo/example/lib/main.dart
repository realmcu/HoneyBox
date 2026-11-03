import 'package:flutter/material.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  runApp(const WSWatchDemoApp(config: WSConfig(simulationEnabled: true)));
}
