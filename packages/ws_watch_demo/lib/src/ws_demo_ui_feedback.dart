import 'package:flutter/material.dart';

import 'ws_demo_controller.dart';

/// Demo 惯例：在**触发调用的页面**里 catch，用 SnackBar 提示（与 SDK `throw` 一致）。
void wsDemoShowErrorSnackBar(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(describeWSDemoError(error)),
    ),
  );
}

Future<void> wsDemoRunWithSnackBar(
  BuildContext context,
  Future<void> Function() operation,
) async {
  try {
    await operation();
  } catch (error) {
    wsDemoShowErrorSnackBar(context, error);
  }
}
