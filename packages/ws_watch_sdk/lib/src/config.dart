import 'logger.dart';

/// 链路层参数，默认值见设计文档 5.2 节。
class WSLinkConfig {
  const WSLinkConfig({
    this.ackTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.chunkWriteTimeout = const Duration(seconds: 3),
    this.replyTimeout = const Duration(seconds: 5),
    this.rxAssembleTimeout = const Duration(seconds: 5),
    this.queueCapacity = 64,
  });

  /// 帧全部写出后等待 ACK 的时间。
  final Duration ackTimeout;

  /// ACK 超时或收到 ERR ACK 后整帧重发的次数，重发使用相同 seq。
  final int maxRetries;

  /// 单个分片写入的超时。
  final Duration chunkWriteTimeout;

  /// 查询类请求收到 ACK 后等待回包的时间，可按协议条目覆盖。
  final Duration replyTimeout;

  /// 一帧跨多个通知时，两个通知之间的最长间隔。
  final Duration rxAssembleTimeout;

  /// 发送队列上限，超过后新请求直接失败。
  final int queueCapacity;
}

/// 连接流程各阶段的超时，默认值见设计文档 7.3 节。
class WSConnectTimeouts {
  const WSConnectTimeouts({
    this.connecting = const Duration(seconds: 15),
    this.discovering = const Duration(seconds: 10),
    this.awaitingConfirm = const Duration(seconds: 60),
  });

  final Duration connecting;
  final Duration discovering;

  /// 等待用户在手表上确认绑定（3.07）。
  final Duration awaitingConfirm;
}

class WSConfig {
  const WSConfig({
    this.link = const WSLinkConfig(),
    this.connectTimeouts = const WSConnectTimeouts(),
    this.autoReconnect = false,
    this.databasePath,
    this.logger,
    this.logLevel = WSLogLevel.info,
  });

  final WSLinkConfig link;
  final WSConnectTimeouts connectTimeouts;

  /// 非主动断开时按 2、4、8 秒……最长 60 秒退避重连。
  final bool autoReconnect;

  /// 为空时使用应用支持目录下的 `ws_watch.db`。
  final String? databasePath;

  /// 为空时输出到 `debugPrint`。
  final WSLogger? logger;
  final WSLogLevel logLevel;
}
