enum WSConnectionState {
  /// 未连接。
  disconnected,

  /// 建立 BLE 连接。
  connecting,

  /// 发现服务、订阅 FF03。
  discovering,

  /// 登录 / 绑定。
  authenticating,

  /// 等待用户在手表上确认绑定（3.07）。
  awaitingConfirm,

  /// 设置手机系统、对时、读功能列表、读设备信息。
  initializing,

  /// 就绪，业务接口可用。
  ready,

  /// 主动断开中。
  disconnecting,
}

class WSConnectionChange {
  const WSConnectionChange({
    required this.previous,
    required this.current,
    required this.at,
    this.reason,
  });

  final WSConnectionState previous;
  final WSConnectionState current;
  final DateTime at;
  final String? reason;

  @override
  String toString() => 'WSConnectionChange(${previous.name} -> ${current.name}'
      '${reason == null ? '' : ', $reason'})';
}
