import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ota/ota_session.dart';

/// Outcome of the last Watch OTA run, kept until the Watch home page shows it.
///
/// A SnackBar is not enough here: reconnecting after the upgrade remounts the
/// Watch home page, whose automatic bind posts its own SnackBar and would
/// replace the upgrade result before the tester can read it.
class WatchOtaResult {
  final OtaOutcome outcome;
  final String detail;
  final bool reconnected;

  const WatchOtaResult({
    required this.outcome,
    required this.detail,
    required this.reconnected,
  });

  bool get success => outcome == OtaOutcome.verified;

  String get message =>
      watchOtaResultMessage(outcome, detail, reconnected: reconnected);
}

String watchOtaResultMessage(
  OtaOutcome outcome,
  String message, {
  required bool reconnected,
}) {
  final base = switch (outcome) {
    OtaOutcome.verified => 'Watch 固件升级成功',
    OtaOutcome.failed => 'Watch 固件升级失败：$message',
    OtaOutcome.cancelled => '已取消升级',
    OtaOutcome.pendingVerification => '固件已写入，版本待核验：$message',
    OtaOutcome.recoveryRequired => '升级中断，设备状态未知：$message',
  };
  return reconnected ? base : '$base（设备未自动重连，请重新扫描连接）';
}

final watchOtaResultProvider = StateProvider<WatchOtaResult?>((ref) => null);
