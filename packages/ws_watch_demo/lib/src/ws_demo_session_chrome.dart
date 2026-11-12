import 'package:flutter/material.dart';

import 'ws_demo_controller.dart';

/// 全局 **忙碌** 指示（`sessionBusy`），不拦截 SDK 错误；错误由各页面的 try/catch 处理。
class WsDemoSessionChrome extends StatelessWidget {
  const WsDemoSessionChrome({
    super.key,
    required this.controller,
    required this.child,
  });

  final WSDemoController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: controller.sessionBusy,
          builder: (context, busy, _) => busy > 0
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
