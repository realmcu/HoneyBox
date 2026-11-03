/// Frame-channel timing and bounds. SDKs map their own product defaults.
class WatchFrameConfig {
  const WatchFrameConfig({
    this.ackTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.chunkWriteTimeout = const Duration(seconds: 3),
    this.rxAssembleTimeout = const Duration(seconds: 5),
    this.maxPayloadLength = 65535,
    this.deduplicationCapacity = 64,
    this.deduplicationWindow = const Duration(seconds: 30),
    this.sendQueueCapacity = 64,
    this.controlQueueCapacity = 64,
    this.initialSequence = 1,
  });

  /// 帧全部写出后等待 ACK 的时间。
  final Duration ackTimeout;

  /// ACK 超时或收到 ERR ACK 后整帧重发的次数，重发使用相同 seq。
  final int maxRetries;

  /// 单个分片写入的超时。
  final Duration chunkWriteTimeout;

  /// 一帧跨多个通知时，两个通知之间的最长间隔。
  final Duration rxAssembleTimeout;

  final int maxPayloadLength;
  final int deduplicationCapacity;
  final Duration deduplicationWindow;

  /// Active plus queued sends; overflow rejects only the new send.
  final int sendQueueCapacity;

  /// Waiting control frames; overflow terminates the byte stream.
  final int controlQueueCapacity;

  /// Allocated once per send; wraps from 65535 to zero.
  final int initialSequence;

  void validate() {
    if (ackTimeout <= Duration.zero ||
        chunkWriteTimeout <= Duration.zero ||
        rxAssembleTimeout <= Duration.zero ||
        deduplicationWindow <= Duration.zero ||
        maxRetries < 0 ||
        sendQueueCapacity <= 0 ||
        controlQueueCapacity <= 0 ||
        initialSequence < 0 ||
        initialSequence > 65535 ||
        maxPayloadLength < 0 ||
        maxPayloadLength > 65535 ||
        deduplicationCapacity <= 0) {
      throw ArgumentError('invalid link configuration');
    }
  }
}
