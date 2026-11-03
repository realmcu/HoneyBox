# watch_transport_simulation

纯 Dart 的双向内存 transport，实现 `watch_transport`。注册表初始为空，设备行为由调用方
注入；本包不识别帧头、ACK、seq 或 JW/WS L2，也不包含健康模型与数据库。

```dart
import 'dart:typed_data';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

Future<void> main() async {
  final transport = WatchSimulationTransport();
  final device = WatchSimulationDevice(
    id: 'echo',
    name: 'Echo',
    maxWriteLength: 64,
    attach: (peer) {
      final subscription = peer.received.listen(peer.deliver);
      return WatchSimulationDeviceSession(dispose: subscription.cancel);
    },
  );
  transport.register(device);
  final connection = transport.createConnection(device.target);
  final reply = connection.received.first;
  try {
    await connection.connect();
    await connection.write(Uint8List.fromList([1, 2, 3]));
    print(await reply);
  } finally {
    await connection.dispose();
  }
}
```

## 生命周期与故障

- 注册表是设备占用的作用域，同一设备只允许一个连接，不同设备可并行。
- 每次连接创建全新 pair，先连接 peer，再执行 `attach`，行为就绪后主机才连接成功。
  设备可在 attach 内主动推送；字节在主机订阅前暂存并按序投递。
- 跨重连的设备状态由工厂捕获；定时器、订阅、待发任务由返回的 session 负责释放。
  断开与远端断开均触发清理，迟到 attach 产生的 session 也会被释放。
- 默认连接超时 15 秒，可配置；取消/超时会结束调用者等待，不能强制停止调用方的任意
  Future。工厂和故障脚本仍应自行清理其外部任务；迟到数据不会送入已关闭连接。
- `WatchSimulationConnection.pair` 可直接用于契约测试。两端均需 connect；
  `interceptWrite` 可异步延迟、丢弃、拆分、修改字节，再调用该端 `deliver` 发给对端。
  脚本抛错映射为中立 write 错误，后续写操作仍可执行。
- 输入立即复制，接收数组只读，写操作按调用顺序执行，断开立即结束在途/排队写入的等待。
- 每端默认提供 64 KiB 的无人订阅接收缓冲，溢出报错并断开两端。
  接收流采用 broadcast；应持续消费，不通过暂停订阅做背压（暂停缓冲由 Dart stream 管理）。
  多个观察者不能修改数组，协议消费者仍只应有一个。
- 连接为单次使用；无论成功或失败，调用方最终都需 `dispose()`。

WS 接入位于 `ws_watch_sdk/lib/src/simulation/simulation_transport.dart`。
`SimWatchDevice`、`SimWatchState` 仍在 WS SDK，通过 attach 注入；既有模拟 ID、身份、数据库
与业务 API 保持原样。此阶段没有新增 JW 模拟设备。

## 验证

在仓库根执行 `flutter test packages/watch_transport_simulation/test`。
测试使用 Flutter 开发依赖的原因见 [watch_transport](../watch_transport/README.md)；本包
运行时只依赖 Dart 和 `watch_transport`，可由独立纯 Dart 工程直接引用。
