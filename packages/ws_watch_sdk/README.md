# ws_watch_sdk

WS 手表 BLE UART 协议的 Flutter SDK。协议依据 HoneyProtocol，工程约定见
[设计文档](../../docs/ws-watch-sdk-design.md)。

## 当前范围：M4

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
`debug` 在初始化时可观察帧，Raw 仅在 ready 后开放。M4 已通过 `watch.settings` 提供正式设置 API。

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

## M4 设置 API 与安装验收

连接到 `ready` 后使用：

```dart
await watch.settings.setTime(); // 手机本地年月日时分秒；不是绝对 UTC 时间
await watch.settings.setLanguage(WSLanguage.english);
final language = await watch.settings.getLanguage();
final current = await watch.settings.getDisplayFormat();
await watch.settings.setDisplayFormat(current.copyWith(
  hourSystem: WSHourSystem.twelveHour,
  dateFormat: WSDateFormat.dayMonth,
));
await Future.wait([
  watch.settings.setHourSystem(WSHourSystem.twentyFourHour),
  watch.settings.setDistanceUnit(WSDistanceUnit.imperial),
]);
final confirmed = await watch.settings.getDisplayFormat();
```

- `WSWallClock` 严格校验日历与无符号 32 位范围；`fromCalendar(DateTime)` 明确复制年月日时分秒，不换算时区。时间只写和通知，没有读时间接口。
- 语言覆盖规范附表 `00～66`；保留/未知值保留原始编码。时制、日期、距离、体重也用带 `code` 的值对象，`.isKnown` 区分已定义编码。
- 显示格式固定 4B。便利 setter 在 Session 队列中独占整个“读取 → 修改 → 写入”，整体写入和 Raw 也不会插入其中。读取失败不写，不用默认值补齐。
- 与手表端同时修改时仍以重新读取为准；协议没有条件更新版本号。
- `settings.observed` / `settings.changes` 只反映设备读取或通知结果，不把 ACK 当成实际生效；断开清空观测值，dispose 关闭流。
- 非 ready 调用立即失败；请求绑定当前会话，断开/释放后不跨连接继续执行。能力 `unknown` 允许尝试，明确 `unsupported` 抛 `WSUnsupportedException`。

安装后可从 Demo 首页进入 **M4 设置**，连接 Simulator；也可在 M3 ready 后进入 **M4 设置** 复用同一会话。

1. 读写语言，再读取验证；查看语言通知与收发帧。
2. 输入 `2026-10-10 16:52:00`，写入后查看时间通知，4B 为 `6a ca 6d 30`；输入无效日期应报错。
3. 设置日期格式与体重单位，写入完整格式再读取，核对 4B。
4. 修改表单时制，点击“仅改时制”，再读取，确认其他三项保留；距离单位同理。
5. 修改时制与距离表单，点击“并发修改时制与距离”，核对修改结果及日期、体重保留。
6. 断开后设置按钮禁用、观测值清空；重连后可继续读写。

SDK 回归：`flutter test test/m4_models_test.dart test/m4_settings_test.dart`。
Demo 回归：在 `packages/ws_watch_demo` 下运行 `flutter test test/m4_settings_page_test.dart`。

## 连接阶段超时排查

`connecting` 包含打开 SQLite、加载持久化用户 ID 和准备传输；错误文字会指出当前步骤。
本次 Android 现场出现数据库工作 isolate 处于 `PauseStart`，VM 的
`pause_isolates_on_start=true`，主 isolate 正常运行，导致数据库握手一直等待，最终连接超时。
这类情况需在调试器继续执行 Drift 工作 isolate，并取消当前调试会话的新 isolate 启动暂停；
仅重新安装 Debug APK 未必改变当前进程的调试状态。应用重新启动后需检查调试启动配置。

真实默认存储与 Simulator 的平台集成回归（macOS）：

```sh
cd packages/ws_watch_demo/example
flutter test integration_test/simulator_connection_test.dart -d macos
```

该用例使用默认环境、原生 SQLite 和持久化路径，覆盖连接到 ready、设置读写和重连。


### M5：历史数据与本地存储

```dart
await watch.connect(kWsWatchSimDeviceId); // config.simulationEnabled=true
final sync = watch.data.sync(type: WSHistoryType.steps); // 或 heartRate
final subscription = sync.progress.listen((p) {
  print('${p.stage.name}: ${p.committed}/${p.announced}，新增 ${p.inserted}，重复 ${p.duplicates}');
});
final result = await sync.result;
await subscription.cancel();
// 取消时 await sync.cancel()；会断开本场连接并等待已开始的事务。
await watch.disconnect();
final query = WSRecordQuery(
  deviceId: kWsWatchSimDeviceId,
  userId: null, // 可指定用户；留空为该设备所有用户
  from: WSWallClock(year: 2026, month: 10, day: 12),
  to: WSWallClock(year: 2026, month: 10, day: 13), // 不包含
  limit: 100,
  descending: true,
);
final records = await watch.data.steps.query(query);
final logs = await watch.data.syncLogs(deviceId: kWsWatchSimDeviceId);
// 显式调用才删除；同一过滤条件（含排序、limit）也适用于 delete。
// final deleted = await watch.data.steps.delete(query);
```

- M5 仅开放 `steps` / `heartRate` 单类型历史同步；同一 Session 只能一场，同步控制 Raw 请求受互斥保护，设置请求仍可执行。
- `completed` 要求声明数、实收数、结束总数一致，事务提交且 `0x42` ACK 成功；确认写出后 ACK 丢失为 `confirmationUnknown`，不自动重试确认。取消、空闲超时（默认 30 秒）、缓冲溢出（默认 1 MiB，原始 L2 操作数据加 5B 头）、协议/数据库错误返回 `incomplete`，保留已提交记录，不确认。
- 同步结果通过 `result` 表达；未就绪、重复同步、配置参数错误在调用入口报错。`progress` 为广播流，返回 session 后异步启动，立即订阅可收到首事件。
- 默认 SQLite 持久化；首次连接或本地查询时打开。无需连接即可 query/delete/syncLogs；`deviceId` 必填，时间范围 `[from,to)`，limit=0 匹配零条。
- 活动桶不是日累计：步数、距离（米）、热量（0.1 kcal）、均心与 flags 分别保留；无效测量为空。时间为设备墙上时钟，使用 `WSWallClock`，不转换时区。未知模式与原始记录尾部扩展保留。
- 唯一键为设备 + 用户 + 时间；重复记录的最新有效测量覆盖旧值，无效值不覆盖已有有效值。raw/flags/mode 为最新收到值，可能与合并后的测量字段不同。
- schema v1 → v2 自动新增记录/日志表和索引，保留旧设备身份；快照与迁移测试在 `test/drift_schemas/`、`test/m5_storage_test.dart`。
- 确认前保存临时审计日志，确认后更新；若最终日志更新失败，返回 incomplete/storageFailed 并保留已实际取得的 confirmation=acked，设备可能已完成标记。

M5 安装验收：HoneyBox → WS Watch → **M5 历史数据** → 连接 Simulator → 开始单类型同步。默认每种两条数据，日期为 **2026-10-12**。首次新增 2，第二次新增 0 / 重复 2；可切换心率、断开查询、退出重进或重启 App 查询、按用户与时间过滤并删除。已安装过数据时首次也可能显示重复。M3 ready 后也能进入共享连接的 M5 页面；返回只释放本页订阅和未完成同步，连接由 M3 管理。


### M6：公开调试门面

`watch.debug.protocols` 在连接前后均可浏览，只读列表包含完整地址、名称、specRef、状态与原因；M2 独立实验室打开期间保留原有 4 条语言协议。已实现条目为 active，规范示例的其余已知地址标为 unimplemented；未知地址没有伪造业务实现。保留 Command / Key 的全部版本与子地址禁止 Raw 发送。

```dart
final frameSub = watch.debug.frames.listen((frame) {
  print('${frame.direction.name} ${frame.kind.name} generation=${frame.connectionGeneration} '
      'trace=${frame.traceId} request=${frame.requestId} seq=${frame.seq}');
});
final reportSub = watch.debug.reports.listen((report) {
  print('${report.time} generation=${report.connectionGeneration} ${report.kind.name} ${report.address}');
});
await watch.connect(kWsWatchSimDeviceId);
final bytes = await watch.debug.trace('language-read', () => watch.debug.sendRaw(
  WSRawRequest(cmd: 2, version: 0, key: 3, settingOpcode: 1, data: [],
    replyAddress: const WSReplyAddress(cmd: 2, version: 0, key: 3,
      settingOpcode: 2, direction: WSWireDirection.deviceToPhone),
    replyTimeout: const Duration(seconds: 5)),
)); // 操作数据，不含 opcode；如 [1]
await frameSub.cancel();
await reportSub.cancel();
```

Raw 共享 Session 队列与超时规则，仅在 ready（或明确打开的 M2 实验室）可用；历史同步控制互斥继续生效。主动上报不自动带上当前请求的 trace。unimplemented/unknown Raw 默认不自动重试；等待回应超时后必须重新连接，避免迟到回应串单。

协议目录更新：在 SDK 目录执行 `python3 tool/generate_protocol_catalog.py`，然后 `dart format lib/src/protocol/catalog.dart`；检查生成差异并运行 SDK 测试。脚本读取同级 HoneyProtocol 仓库，生成物已提交在源码中，运行 SDK/Demo 无需 HoneyProtocol 或 Python。
