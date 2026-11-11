import 'package:flutter/material.dart';

import 'ws_demo_controller.dart';

mixin WsDemoAsyncMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;
  Object? error;
  String? resultMessage;
  bool _deferredRebuildPending = false;

  void requestDeferredRebuild() {
    if (!mounted || _deferredRebuildPending) return;
    _deferredRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredRebuildPending = false;
      if (mounted) setState(() {});
    });
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    error = null;
    resultMessage = null;
    requestDeferredRebuild();
    try {
      await operation();
    } catch (e) {
      error = e;
      busy = false;
      requestDeferredRebuild();
      return;
    }
    busy = false;
    requestDeferredRebuild();
  }

  List<Widget> buildAsyncFeedback(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (resultMessage != null) ...[
        const SizedBox(height: 12),
        Text(resultMessage!, style: theme.textTheme.bodyMedium),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          describeWSDemoError(error!),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
    ];
  }
}
