# watch_transport

纯 Dart 的设备连接与字节传输契约。运行时不依赖 Flutter、BLE、帧协议、JW/WS 或数据库。

- `WatchTransport` 按 `WatchDeviceTarget(transportId, deviceId)` 创建连接。
- `WatchTransportConnection` 提供状态、接收/断开事件、单次写入限制及连接生命周期。
- 先订阅，再 `connect()`；同一对象只连接一次，重连时创建新对象。
- `write()` 发送不透明字节，完成不代表 ACK 或业务回应；发送方复制输入，接收数据不可修改。
- 每条连接由一个协议消费者连续消费接收流；状态与断开事件可另行观察。
- `disconnect()` / `dispose()` 幂等；断开结束待执行操作，最终调用 `dispose()` 释放流资源。

实现按实际平台报告 `WatchWriteLimits`，不把 BLE 的 MTU 或业务设备身份放入公共契约。
连接错误使用 `WatchTransportException`；JW/WS 在自己的 adapter 中映射公开错误。

实现示例见 [watch_transport_simulation](../watch_transport_simulation/README.md)。

## 验证

在本仓库执行 `flutter test packages/watch_transport/test`。
当前 workspace 的 Flutter 固定 `test_api` 与代码生成工具的 analyzer 版本无法同时匹配
`package:test`，所以测试使用 `flutter_test` 开发依赖；运行时仍为纯 Dart，外部 Dart 工程
只依赖本包时不会引入 Flutter。没有用 dependency override 强制更换测试工具版本。
