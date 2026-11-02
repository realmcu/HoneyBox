# ws_watch_sdk

WS 手表 BLE UART 协议的 Flutter SDK。协议依据 HoneyProtocol，工程约定见
[设计文档](../../docs/ws-watch-sdk-design.md)。

## 当前范围：M3

已实现内部字节传输接口、内存双向模拟传输、L1 帧与 CRC-16/ARC、分片组包、
ACK/ERR ACK 与重传、接收去重、L2 TLV 与设置操作码、完整地址注册表、串行 Session、
回包分流、超时隔离，以及公开的 `WSDebugApi`、Raw 请求和帧/协议描述 DTO。

最小模拟设备实现语言读取、设置和主动通知，用于验证整个收发流程。语言暂以原始编码
作为内部协议值，业务模型及稳定的 settings API 在后续里程碑提供。

M3 已提供 `WSWatch.scanner()`、`connect / disconnect / unbind`，完成登录、可选绑定确认、
手机系统/对时/能力/设备信息初始化，全部完成并入库后进入 `ready`。
`deviceInfo`、`capabilities` 在就绪后可读；未定义的功能位始终返回 `unknown`。
默认用户 ID 在首次认证前写入 SQLite，同设备重连复用；显式 ID 为 1～32 字节非 NUL ASCII。
默认数据库为应用支持目录的 `ws_watch.db`，可通过 `databasePath` 指定，同路径共享数据库引用。
主动断开、解绑、释放会取消重连；`autoReconnect: true` 时非主动断开按 2/4/8/16/32/60 秒重连。

```dart
final config = WSConfig(simulationEnabled: true);
final scanner = WSWatch.scanner(config: config);
await scanner.start(includeRealDevices: false);
final watch = WSWatch(config: config);
await watch.connect(scanner.devices.single.deviceId);
print(watch.deviceInfo?.firmwareVersion);
await watch.unbind();
await watch.dispose();
await scanner.dispose();
```

扫描可选真实 BLE 广播，由宿主申请平台权限；M3 正式连接仅支持显式开启的 Simulator。
真实 BLE UART 连接和手表验收属于 M7。Simulator 模拟 300ms 后自动确认绑定，绑定状态
保留在当前进程；退出应用后模拟设备重置，但 SQLite 默认 ID 保留。
桌面模拟默认使用 Android 手机系统值；桌面真机系统编码须另行约定，可配置 `phoneSystem`。
`debug` 在初始化时可观察帧，Raw 仅在 ready 后开放。设置业务 API 在 M4 提供。

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

## 安装验收 M3

在 HoneyBox 的 WS Watch Demo 首页进入 **M3 扫描与连接**：

1. 保持真实蓝牙扫描关闭，点击“扫描设备”，出现 `WS Watch Simulator`。
2. 用户 ID 留空，点击模拟设备，观察登录 → awaitingConfirm → initializing → ready。
3. 检查固件 `1.2.3+100`、MAC `11:22:33:44:55:66`、序列号 `WS2026000001` 和 128 bit 能力原文。
4. 点击“断开 / 取消连接”，再连接；当前进程再次登录应跳过绑定确认，用户 ID 不变。
5. 点击“解绑”应断开，再连接会重新绑定。等待确认时也可点击取消，再连接验证清理。
6. 关闭重开应用，再次连接检查默认 ID 不变（模拟器重新绑定是预期行为）。

无需蓝牙权限即可完成上述流程。M2 模拟实验室继续独立保留。
自动回归：`flutter test test/m3_connection_test.dart test/m3_storage_test.dart`。
