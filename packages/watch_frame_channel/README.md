# watch_frame_channel

纯 Dart 的当前 L0/L1 帧通道，运行时只依赖 `watch_transport`。负责前 8 字节帧头、
CRC-16/ARC、seq、ACK/ERR ACK、发送队列、重试、分片组包与短期去重。
payload 是不透明字节；L2 command/key、回应匹配、健康模型和数据库由各 SDK 管理。
未来不兼容的 L0/L1 可以另建帧通道实现，不要求扩展本包处理所有协议。

```dart
import 'dart:typed_data';
import 'package:watch_frame_channel/watch_frame_channel.dart';

// connection 是 watch_transport 的连接；先建立订阅，再连接。
final channel = WatchFrameChannel(WatchFramePort.fromConnection(connection));
final subscription = channel.payloads.listen((event) {
  // 交给 SDK 的 L2 decoder。
  print('${event.seq}: ${event.bytes}');
});
try {
  await connection.connect();
  await channel.send(Uint8List.fromList([/* SDK 生成的完整 L2 */]));
} finally {
  await subscription.cancel();
  await channel.close(); // 关闭连接并 dispose；不跨连接复用 channel。
}
```

`WatchFramePort.fromConnection` 只适配字节操作，不重复连接/订阅 GATT，不取得第二份设备租约。
已有 SDK 的 transport 可通过回调式 `WatchFramePort` 适配；必须提供真实、动态的最大写入长度，
并在 `close` 中终止不可继续使用的字节连接。对于连接前未知的写入长度，transport 应先给出
保守的有效值，协商后更新 getter。每条字节连接只安装一个 frame channel。

## 当前 wire profile

| 行为 | `ws` | `jw` |
| --- | --- | --- |
| 接收 flags | `00 / 10 / 30` | `00 / 10 / 30 / 40 / 50 / 70` |
| payload 上限 | 65535，可进一步限制 | 236（总帧 244），配置也须不超过此值 |
| CRC 错误、可信头组包超时 | 回复 ERR ACK | 丢弃，不回复 |
| CRC 后恢复 | 跳过已知长度的坏帧 | 从坏帧内继续寻找有效帧头 |
| noACK 数据 | 拒绝该标志 | 交付、去重，不回 ACK |

CRC reflected polynomial `A001`，init/xorout `0000`；长度、CRC、seq 按大端存放。
ACK 必须 payload 为空且 CRC 为零；未知 flags、超长长度和无效 ACK 不产生 ACK。
`WatchFrame` 是 wire value；`WatchFrameAssembler` 增量验证 profile，缓存最多 header + payload 上限。
其独立使用可传 `timeout: null`；运行中的 channel 始终配置组包超时。

SDK 映射自己的参数；包默认采用 WS 参数：ACK 5 秒、重试 3 次、分片写入 3 秒、
组包间隔 5 秒、去重 64 项/30 秒。现有 JW adapter 使用 ACK 3 秒、重试 2 次、
236 字节上限、去重 128 项/30 秒。JW 现增加 5 秒组包清理，避免旧半帧一直占用接收状态。

## 发送、确认和终止

- `send` 完成表示整帧写入成功并收到有效 ACK，不能据此推断 L2 业务成功。
- 默认最多 64 个在途/排队发送、64 个待写控制帧。发送溢出只拒绝该次提交；
  控制帧溢出终止通道，不能静默丢 ACK。SDK 的业务队列仍由 SDK 自己控制。
- 每次发送只分配一次 seq，重试使用同一份帧。初始值默认 1，65535 后回绕到 0。
- ACK 在首次 write 前登记；数据帧的全部分片不可交错。ACK 控制帧在整帧边界优先发送，
  不等待该数据帧的 L1 ACK，更不等待 SDK 的 L2 回应。
- 已收到的数据帧先回 ACK，再去重；重复数据仍回 ACK，但不重复交付 payload。
  去重同时比较 seq/payload，有容量和时间界限；同 seq 不同 payload 交付并观察为冲突。
- `startSend` 返回 `WatchFrameSend`。JW session 只有匹配到其 L2 回应后，才调用
  `confirmReceived(handle)`，视为请求已收。必须是本通道、当前活动的句柄且代次匹配；
  排队、已结束和其他连接的句柄均不能确认。该 API 仍须等全部分片 write 成功，不能掩盖写失败。
  WS adapter 不使用提前确认。
- `flushWrites` 等待调用时已经登记的分片/控制帧写入，不等待未来发送或 L1 ACK；
  诊断探针在释放前用它保证回应 ACK 已写完。
- 写入失败/超时即终止，不再向可能残留半帧的字节流追加后续帧。收到断开、接收流错误或结束
  也终止；`terminated` 给出首次原因，关闭立即失败所有发送，取消组包计时器及接收订阅。
- `close` 幂等，保留首次原因，调用 port 的清理回调。取消一次在途发送使用关闭通道；
  无法强制取消平台已开始的 Future，transport 负责处理迟到结果。
- `frames` 公开帧/分片/重试/错误及 seq、generation、requestId、traceId；这些标识不加入 wire。
  payload、帧与观测字节都是快照。调试日志只订阅此流，不参与调度。

公共错误用 `WatchFrameException`；`WatchFrameWriteException` 保留原始 cause 与是否为控制帧。
SDK 可以通过 `mapError` 映射成自己的公开错误，业务回应超时不进入本包。

## 验证与独立使用

在此目录运行 `flutter test`。开发依赖使用 `flutter_test` 的工作区解析原因见
[watch_transport](../watch_transport/README.md)；运行时不依赖 Flutter。
已使用独立纯 Dart 工程通过真实 path 依赖进行 pub get/analyze/run，
由两个公共通道在 simulation 的 7 字节写入上限上完成收发。

正确性同时由 CRC 标准检查值 `123456789 → BB3D`、独立固定字节向量、JW 实机抓包及
两套 SDK 既有回归检查，不只比较本包自己的 encoder/decoder。
真机脚本在 `watch_transport_ble/example/integration_test/jw_ble_smoke_test.dart`；
它只读语言和标准电量，额外压到 5 字节写入并丢弃一次真实 ACK 验证同 seq 重传。
