import 'dart:async';

import 'package:flutter/material.dart';

import 'ws_health_app_theme.dart';

/// 共用：长按 501ms 选中 + 横滑取消，避免在 build 中同步回调。
mixin WsAppChartTouchMixin<T extends StatefulWidget> on State<T> {
  Timer? touchDelay;
  var armed = false;
  var tracking = false;
  Offset? downPos;
  int touchIndex = -1;
  int downIndex = -1;

  void cancelTouchTimer() {
    touchDelay?.cancel();
    touchDelay = null;
  }

  @override
  void dispose() {
    cancelTouchTimer();
    super.dispose();
  }

  void armTouch({
    required Offset local,
    required int index,
    required VoidCallback onArmed,
  }) {
    cancelTouchTimer();
    armed = true;
    tracking = false;
    downPos = local;
    downIndex = index;
    touchDelay = Timer(WsHealthAppTheme.chartTouchDelay, () {
      if (!mounted || !armed) return;
      setState(() {
        tracking = true;
        touchIndex = downIndex;
      });
      onArmed();
    });
  }

  /// 返回 true 表示应取消选中（横向滑动优先）。
  bool shouldCancelForPan(Offset local) {
    final down = downPos;
    if (down == null || tracking) return false;
    final dx = (local.dx - down.dx).abs();
    final dy = (local.dy - down.dy).abs();
    return dx > 12 && dx > dy;
  }

  void clearTouchLocal({required VoidCallback notifyParent}) {
    cancelTouchTimer();
    final had = touchIndex != -1;
    touchIndex = -1;
    armed = false;
    tracking = false;
    if (had && mounted) setState(() {});
    notifyParent();
  }
}

void jwAppNotifySelectionAsync(VoidCallback fn) {
  WidgetsBinding.instance.addPostFrameCallback((_) => fn());
}
