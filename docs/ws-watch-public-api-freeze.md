# WS Watch 公开 API 冻结（W5.0 → W5.1 实施）

> **当前代码**仍为 M3–M6 形态（单 `WSWatch` + `data`/`settings`）。本文是 **W5.1 重构目标契约**；通过评审后仅在 W5.1 修改 `lib/ws_watch_sdk.dart` export 与实现。  
> 对照：`packages/jw_watch_sdk/lib/jw_watch_sdk.dart`、`JWWatch` / `JWWatchSession` 源码。

---

## 1. 生命周期

```dart
// 应用启动一次
final watch = WSWatch(config: WSConfig(simulationEnabled: true));
await watch.initialize(); // 打开 ws_watch.db（应用支持目录或 WSConfig.databasePath）

await watch.startScan();
// watch.scanResults → 含真机 + WS Watch Simulator（kWsWatchSimDeviceId）

final session = watch.createSession(deviceId);
await session.connect(userId: userId); // 或 bind 流，至 ready
try {
  await session.settings.setLanguage(...);
  await session.syncHealthData(); // W5.3
  final rows = await watch.historyStore.querySteps(scope, query);
} finally {
  await session.dispose();
}
await watch.dispose();
```

| 规则 | 说明 |
| --- | --- |
| 单 Session | 一个 `WSWatchSession` 独占一条连接；重连 **new Session**（同 JW） |
| 多设备 | 多 Session 可共享同一 `WSWatch` / DB；同一 `deviceId` 同时仅一个活动 Session |
| initialize | 未 initialize 时 scan/connect 抛 `StateError`（对齐 JW） |

---

## 2. WSWatch（全局）

| 成员 | 语义 |
| --- | --- |
| `Future<void> initialize()` | 打开 `WSHistoryStore` / `ws_watch.db` |
| `WSHistoryStore get historyStore` | 离线查询（不需 Session ready） |
| `Future<void> startScan` / `stopScan` | BLE 或 Sim 扫描 |
| `Stream<List<WSScanDevice>> scanResults` | |
| `WSWatchSession createSession(String deviceId)` | 不发起连接，仅绑定 transport 工厂 |
| `dispose()` | 关闭库（若非注入）、取消扫描 |

**移除或 Deprecated（W5.1）**

- `connect` / `disconnect` on `WSWatch` → Session
- `openSimulationLab` / `isSimulationLabOpen` → `debug` 或删除
- `settings` / `data` on `WSWatch` → Session

---

## 3. WSWatchSession（单连接）

| 子模块 | 协议 | 阶段 | 说明 |
| --- | --- | --- | --- |
| `settings` | 0x02 | W5.1 挂载 + W5.4 扩全 | 原 `WSSettings` |
| `history` | 0x05 | W5.1 挂 M5 API + W5.3 全量 | 原 `WSData` 改名；含 `syncHealthData` |
| `measure` | 0x11 | W5.4 | 点测/自动监测 |
| `control` | 0x04+ | W5.4 | |
| `notify` | 0x04+ | W5.4 | |
| `today` | 0x60–0x63 | W5.4 | 非历史表 |
| `sport` | 0x80–0x81 | W5.4 | 与历史互斥 |
| `debug` | 帧/Raw | W5.1 | 原 `WSDebugApi` 会话级 |

| 成员 | 语义 |
| --- | --- |
| `WSConnectionState get state` | |
| `Stream<WSConnectionChange> get states` | |
| `WSDeviceInfo? get deviceInfo` | ready 后 |
| `WSCapabilities? get capabilities` | |
| `WSHistoryScope? get historyScope` | login/bind 后；**不含**敏感日志默认字段 |
| `Future<void> connect({String? userId})` | 状态机至 ready |
| `Future<void> disconnect()` / `unbind()` | |
| `bool get isHealthSyncActive` | W5.3 |
| `Future<WSSyncHealthResult> syncHealthData({...})` | W5.3；进度 Stream 另定（对齐 JW listener） |

---

## 4. 历史与同步（命名对齐 JW）

| JW | WS（冻结名） |
| --- | --- |
| `JWHistoryStore` | `WSHistoryStore` |
| `JWHistoryScope` | `WSHistoryScope` |
| `JWWatchSession.syncHealthData` | `WSWatchSession.syncHealthData` |
| `querySteps` / `queryHeartRate` / … | `query*` 按类型扩展至 0x0A |
| `WSSyncSession`（单类型） | Deprecated → `syncHealthData` |

存储：设备+用户+墙上时钟；**与 JW 库文件分离**（`ws_watch.db`）。

---

## 5. 错误与能力

- 继续 `WSError` 层次；阶段区分 transport / frame / protocol / business（见 design §12）。
- `WSFeatureSupport`：`unknown` / `supported` / `unsupported` — **禁止**把 unknown 当 unsupported 静默跳过。

---

## 6. Export 规划（`ws_watch_sdk.dart`）

W5.1 目标 export 分组（示意）：

- `connection/`：`WSWatch`, `WSWatchSession`, `WSScanDevice`, `WSConnectionState`
- `storage/`：`WSHistoryStore`, `WSHistoryScope`
- `history/`：各 `WS*Record` 模型
- `settings/`：配置值类型
- `config`, `errors`, `version`
- `debug/`：受控观测（可选单独 import）

**不 export**：`session/session.dart` 内部、`protocol/*`、`connection/connection_machine.dart`。

---

## 7. W5.1 文件级迁移（实施清单）

| 动作 | 路径 |
| --- | --- |
| 新建 Watch/Session 门面 | `lib/src/connection/ws_watch.dart`, `ws_session.dart` |
| 瘦身旧入口 | `lib/src/watch.dart` → Deprecated 转发或删除 |
| 特征模块改挂载 | `features/settings.dart`, `features/data.dart` → `history.dart` |
| 状态机归属 | `connection/connection_machine.dart` 由 Session 驱动 |
| Demo | `ws_watch_demo` M3–M5 页改用 `initialize` + `createSession` |
| 设计文档 | `ws-watch-sdk-design.md` §9 替换为本契约摘要 |

---

## 8. 评审检查（W5.0 关单）

- [ ] 本文件 + [ws-watch-api-coverage.md](ws-watch-api-coverage.md) 与团队评审通过
- [ ] `ws-watch-implementation-plan.md` §3.3 与 RST v1 范围一致（见覆盖表 §2）
- [ ] 无 blocking 开放问题（`ws-watch-sdk-design.md` §18 项若冲突则关闭或改决策）
