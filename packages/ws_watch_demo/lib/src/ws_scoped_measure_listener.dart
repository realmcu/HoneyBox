import 'package:flutter/foundation.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_measure_module.dart';

/// Per-detail-page measure hook; WS SDK streaming TBD — API matches JW Demo.
final class WsScopedMeasureListener extends ChangeNotifier {
  WsScopedMeasureListener(this.kind);

  final WSMeasureModuleKind kind;

  void Function()? onHeartRateSpotEndedByDevice;

  String? spotValue;
  String? lastEventLine;
  final _log = <String>[];

  List<String> get log => List.unmodifiable(_log);

  void attach(WSWatchSession session) {}

  void detach() {}

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
