import 'package:flutter/material.dart';

import 'ws_demo_controller.dart';

/// Remote camera control is not in WS SDK yet; placeholder matches JW nav.
class WsTakePhotoPage extends StatelessWidget {
  const WsTakePhotoPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('遥控拍照')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text('WS SDK 暂未开放遥控拍照与控制监听 API。'),
      ),
    );
  }
}
