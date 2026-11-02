import 'package:flutter/foundation.dart';

enum WSLogLevel { debug, info, warning, error }

abstract interface class WSLogger {
  void log(
    WSLogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

class WSDebugPrintLogger implements WSLogger {
  const WSDebugPrintLogger({this.minLevel = WSLogLevel.info});

  final WSLogLevel minLevel;

  @override
  void log(
    WSLogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final buffer = StringBuffer('[WS][${level.name}][$tag] $message');
    if (error != null) buffer.write(' error=$error');
    debugPrint(buffer.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
