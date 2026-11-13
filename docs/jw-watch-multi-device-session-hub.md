# JW Watch：多设备 Session Hub 与 Demo

状态：已实现（2026-11-12）。本阶段先落地 JW 老协议，使用现有真机验证；WS Hub 后续对齐。JW/WS 继续共用 `watch_frame_channel` 与 BLE transport，各自保留帧 profile、L2 协议和业务 API。

## 所有权与生命周期

- 一个 App / Isolate 共享一个 `JWWatch`，由 Watch 管理扫描、Session 与历史库。不同设备各有独立连接、协议队列、认证身份、测量监听与同步流程。
- `openSession(deviceId)` 只创建/获取，不自动连接。有效生命周期内，同一规范化设备 ID 始终返回同一对象。BLE 注册表 key 使用 trim + lowercase；模拟设备 ID trim 后按注册值精确匹配。连接 target 和历史 scope 保留首次打开时的扫描 ID 拼写，以兼容已有数据库；重连应继续使用扫描结果或保存的原始 ID。
- `sessionOf(deviceId)` 仅返回仍可使用的 Session；关闭中、已销毁或终态返回 null。
- `createSession` 保留同步兼容入口，改为同样托管和去重。若旧实例尚待清理，同步入口返回 `unavailable`；使用 `await openSession` 等待清理。
- Session 是一次性连接生命周期。连接失败、真实掉线或直接 `session.dispose()` 成功后，Hub 自动释放并移除。重连通过 `openSession` 获取新实例；旧引用不能恢复连接。
- `closeSession` 合并同设备的并发关闭，等待连接、协议资源与历史写入释放。新一代只能在旧一代清理完成后创建。关闭失败保留 entry 与容量占用，可重新调用关闭。
- `closeAllSessions` 尝试关闭全部设备，期间拒绝新建或连接；失败通过 `JWSessionCloseException.failures` 按设备汇总。
- `watch.dispose()` 停止扫描、关闭全部 Session，最后关闭自有数据库与状态流。失败可重试，销毁开始后不能再开启业务。

## 公开 API

```dart
final watch = JWWatch(maxConnectedDevices: 4); // 默认 BLE
await watch.initialize();

final a = await watch.openSession(deviceIdA);
final b = await watch.openSession(deviceIdB);
await Future.wait([a.connect(), b.connect()]);
// connect 不隐式登录或绑定。
await a.login(userId);
await b.login(userId);

final again = watch.sessionOf(deviceIdA);
assert(identical(a, again));
await watch.closeSession(deviceIdA); // B 保持连接
await watch.dispose();
```

`attachedSessionsSnapshot` 是不可修改的同步列表；`attachedSessions` 是广播变化流（不重放初值，UI 首次使用 snapshot）。每项包含 deviceId、Session、最近 state、是否模拟、isClosing、closeError。列表包括尚未连接的 Session，连接数应按 `state.isConnected` 过滤。

`maxConnectedDevices` 默认 4，仅约束本 Watch，是策略限制，不是平台保证：正在连接、已连接及尚未成功释放的连接均占位。容量检查发生在 `connect()` 前，同设备重复 connect 共享 Future；不同设备不设全局命令锁。`maxAttachedSessions` 默认 64，单独约束未连接对象数量。超限抛 `JWException(JWErrorCode.sessionLimit, ...)`。

当前操作设备由 App 管理，不放入 SDK。异步操作必须在开始时捕获 Session，不能在 await 后根据新的选择查找目标。

## ACK 重发与错误约定

JW 已使用 WS 修复所覆盖的公共帧通道：

- JW 默认等待 ACK 3 秒，最多重发 2 次（共发送 3 次），重发保持相同序号与帧内容；NACK 同样按预算重发。
- 匹配到当前请求的 JW 业务回复，可确认发送已被接收，兼容缺少独立 ACK 的老固件；不能照搬 WS 的 bit6 语义。
- ACK 耗尽、NACK、写超时、写失败、业务回复超时通过调用 Future 抛出，调用方 `try/catch`。这些错误不伪造设备断开，后续命令可继续。
- 只有真实 transport 断开或显式关闭才终止通道。同步过程通过 `JWHistorySyncListener.onSyncFailed` 回调失败，同时调用 Future 失败；普通命令不额外广播全局错误。
- 本次修复公共帧通道中写超时被再次包装成 `writeFailed` 的问题，保留准确的 `writeTimeout`。
- 本次补齐 JW Link 主动销毁资源、终止等待中的主动/非主动回复、排队命令失败传播、认证失败退出 loggingIn、断开后清理认证身份。
- JW 协议日志携带 deviceId、Session 序号，便于区分两台表相同的 L1 seq。Demo 的同步日志携带 deviceId。

## Demo 使用

HoneyBox → JW SDK Demo：默认走 BLE，可在顶栏切换“双机模拟”。切换传输会先完成旧 Watch 的清理，之后重新初始化。

1. 初始化，点击“扫描并添加设备”。模拟扫描返回 `jw-sim-1` 与 `jw-sim-2`。
2. 分别添加两台设备，第一台保持连接。顶栏设备卡展示各自 phase、同步进度与单台关闭按钮。
3. 点击设备卡切换操作目标；按设备登录或首次绑定。切换时数据/设置主页面重新创建，避免沿用另一台的页面缓存。
4. 同步进度由 Demo controller 按 Session 保存，离开数据 Tab 或切换设备后仍继续。可在 A 同步期间切到 B，再发起 B 同步。
5. 关闭 A 不影响 B；关闭失败的 entry 会显示释放失败，可重试。

模拟器使用实际 JW 帧与 L2 编解码，支持登录、绑定/解绑、时钟接收、语言/时制/单位读写、功能查询、心率历史同步与确认。两台默认心率分别为 70、80；每台状态独立，重连保留绑定与设置。不支持的模拟业务不伪造成功。

最近设备记录包含传输类型，模拟 ID 不会作为 BLE 地址自动重连。业务异常保留在原 Session 下并重新抛给页面，不覆盖新选择设备的错误状态。

## 验证与真机清单

自动化覆盖：

- ACK 丢失/NACK 重发与耗尽、写失败/超时、业务回复超时后继续发送、缺 ACK 的有效回复、连接中断后的排队命令与非主动回复失败。
- 相同设备并发获取、连接/对象容量、同设备关闭重开、直接销毁、真实掉线、连接中关闭、批量部分失败与重试、Watch 级联释放。
- 同用户双设备绑定、不同设置与心率、并行历史同步、按 userId + deviceMac 查询隔离、单台关闭与重连。
- Demo 扫描添加两台、设备选择、单台关闭、切换设备时原同步结果与错误归属。

本地回归入口：

```sh
flutter test --no-pub packages/watch_frame_channel/test packages/watch_transport_ble/test packages/watch_transport_simulation/test packages/jw_watch_sdk/test packages/jw_watch_demo/test packages/ws_watch_sdk/test
```

真机还需人工执行：两台 JW 同时连接并登录；A 同步时操作 B；保留 A 扫描并添加 B；断开/重启 A 后 B 继续工作；反复重连与退出 Demo，确认 GATT 与 Coordinator lease 释放。Android 厂商并发上限、吞吐和扫描稳定性需真机验证，模拟器不能替代。

完整回归中的两个既有 Demo 断言（热量格式的单位后缀、设置页“SDK 未支持”文案）在 HEAD 基线也失败；与多设备改动无关，本次保留原实现与断言。

验证结果（2026-11-12）：新增 21 项针对性测试全部通过；公共帧通道、BLE/模拟传输、JW SDK/Demo 与 WS SDK 回归共 208 项通过、上述 2 项旧断言失败。修改范围静态检查通过；Android Debug APK 构建成功。全仓库 analyze 另有既有 WS smoke test 导入路径错误及存量 lint，未在本任务扩展修改。尚未执行双表 BLE 真机验收。
