import 'package:flutter/material.dart';

import 'ws_demo_controller.dart';

void openWsControlLab(BuildContext context, WSDemoController controller) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WsControlLabPage(controller: controller),
    ),
  );
}

/// WS SDK control APIs (weather / music) are not wired yet; keep JW Demo nav slot.
class WsControlLabPage extends StatelessWidget {
  const WsControlLabPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('控制联调')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Honey WS SDK 的控制类 API（天气、音乐状态等）尚未开放。\n'
          '本页保留与 JW Demo 一致的入口，便于后续接入。',
        ),
      ),
    );
  }
}
