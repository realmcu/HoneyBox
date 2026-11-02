# ws_watch_sdk

WS 手表 BLE UART 协议的 Flutter SDK。协议依据 HoneyProtocol，工程约定见
[设计文档](../../docs/ws-watch-sdk-design.md)。

## 当前范围：M2

已实现内部字节传输接口、内存双向模拟传输、L1 帧与 CRC-16/ARC、分片组包、
ACK/ERR ACK 与重传、接收去重、L2 TLV 与设置操作码、完整地址注册表、串行 Session、
回包分流、超时隔离，以及公开的 `WSDebugApi`、Raw 请求和帧/协议描述 DTO。

最小模拟设备实现语言读取、设置和主动通知，用于验证整个收发流程。语言暂以原始编码
作为内部协议值，业务模型及稳定的 settings API 在后续里程碑提供。

`WSWatch.debug` 已可获取，但普通 `WSWatch` 尚无已准备的会话，发送 Raw 会明确失败。
正式扫描、connect、登录、绑定、ready 状态与调试会话挂接属于 M3；真机 BLE 实现属于 M7。
不会把“传输已准备”伪装成“设备已登录并就绪”。

## 分层

```text
features → session → link → transport
              ↓                 ↑
           protocol        BLE / simulation
```

- `session` 维护业务队列及完整回应地址，设置通知不能完成读取查询。
- `link` 只处理 L1。完整帧写入不可交错，ACK 可在帧边界优先发送，不等待业务查询结束。
- 分片写入失败或超时关闭连接；ACK 超时/ERR ACK 按配置同 seq 重试。
- Query 的 ACK 或回应超时后关闭会话，队列失败，不跨连接重放请求。
- Raw、typed 调用共用队列；未知/未实现地址默认不重试，废弃/保留范围拒绝发送。
- 帧含本地 generation、requestId、traceId。它们是观测标识，不是线上请求 ID。

`WSLinkConfig.replyTimeout/queueCapacity` 已迁移至 `WSConfig.session`；模拟传输默认关闭，
由 `WSConfig(simulationEnabled: true)` 显式启用。配置非法在创建内部连接前失败。

## 验证

在本目录执行：

```sh
flutter test
flutter analyze
```

**安装 App 验收 M2（可选）**：在 Demo 首页进入 **M2 模拟实验室**，打开实验室后设置/读取语言并查看帧日志。需要
`WSConfig(simulationEnabled: true)`（实验室页已内置）。这不是 M3 正式连接，也不会进入 `ready`。

只运行 M2 模拟器验收：

```sh
flutter test test/session/session_test.dart test/sim/simulator_test.dart
```

`test/session/session_test.dart` 通过内部 `WSPreparedSimulation.open` 建立准备好的测试会话，
验证 typed/Raw 查询、通知及调试流；`test/sim/scenarios.dart` 在模拟设备字节出口注入
丢 ACK、ERR ACK 和断链，`replyDelay` 验证迟到回应。
此 harness 位于 `src/` 且不从 SDK 入口导出，不是接入方的正式连接 API。

固定向量位于 `test/vectors/honey_protocol.json`，标记规范来源，覆盖设置、绑定和
Version 1 同步报文格式。L1 使用独立固定帧与 CRC 标准校验值；不单靠模拟器与 SDK
互相收发来判断编解码正确性。

真机验收还需核实固件缓冲上限、重传去重、ACK 时序及断链清理旧任务；当前模拟测试
不证明 Android/iOS/Windows BLE 平台兼容性。
