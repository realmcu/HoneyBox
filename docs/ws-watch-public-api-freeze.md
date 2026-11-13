# WS Watch 公开 API 冻结（W5.0 → W5.1 Greenfield）

> **仓库状态（2026-11）**：原 **M1–M6** 实现已随 `packages/ws_watch_sdk`、`packages/ws_watch_demo` **整包删除**；**当前无 WS SDK/Demo 源码**，本次为 **首版 Greenfield**。  
> **实施方式**：复制 `jw_watch_sdk` / `jw_watch_demo` 的**工程骨架**（目录与 Watch+Session 分层），新建 `ws_watch_sdk` / `ws_watch_demo` 与 `WS*` 类型；**设备协议按 HoneyProtocol 新写**（JW 为老协议对照，**不从旧 WS port**，**无** M 系 `@Deprecated`）。  
> **对照真源（仅 API 形状）**：`packages/jw_watch_sdk/lib/jw_watch_sdk.dart`、`JWWatch` / `JWWatchSession` 及同名子模块。  
> **HoneyBox**：Greenfield 阶段 **不依赖** `ws_watch_demo`；Watch Lab 仅 JW。

---

## 1. 原则

| 项 | 决策 |
| --- | --- |
| API 形状 | 与 JW **一一镜像**（export 列表、Watch + Session、子模块命名仅前缀不同） |
| Session 阶段 | 与 JW 同款 **`WSSessionPhase` / 状态流**（对照 `jw_session_state.dart`） |
| 过渡 API | **不保留** M 系 `connect` on Watch、`data`/`openSimulationLab` 等；**无** `@Deprecated` 垫层 |
| 设备协议 | **HoneyProtocol**（新）；JW 侧为 **HL 老协议**；WS codec **独立实现**，不复用 JW |
| 存储 | `ws_watch.db`；表设计 follow [jw-watch-database-design.md](jw-watch-database-design.md) 语义，**schema 与已删 M 版零兼容** |
| 共用底层 | 仅 `watch_frame_channel`、`watch_transport`、`watch_transport_ble`、`watch_transport_simulation` |

---

## 2. 生命周期（与 JW 同构）

```dart
// 与 jw_watch_demo 主路径相同步骤；类型名为 WS*
final watch = WSWatch(config: WSConfig(simulationEnabled: true));
await watch.initialize();

await watch.startScan();
// scanResults → 真机 + WS 模拟器条目（Sim 设备 ID 常量对照 JW）

final session = watch.createSession(/* 参数语义同 JWWatch.createSession */);
await session.connect(userId: userId);
try {
  await session.settings.setLanguage(...);
  await session.syncHealthData(); // W5.3 起
  final rows = await watch.historyStore.querySteps(scope, query);
} finally {
  await session.dispose();
}
await watch.dispose();
```

| 规则 | 说明 |
| --- | --- |
| 单 Session | 独占一条连接；重连 **new Session**（同 JW） |
| 多设备 | 多 Session 可共享同一 `WSWatch` / DB；同一设备标识同时仅一个活动 Session（规则同 JW）；**Session 登记与重复获取**见 [ws-watch-multi-device-session-hub.md](ws-watch-multi-device-session-hub.md)（Hub 里程碑） |
| initialize | 未 initialize 时 scan/connect 抛 `StateError`（对齐 JW） |

---

## 3. WSWatch / WSWatchSession（模块表）

与 [jw_watch_sdk.dart](../packages/jw_watch_sdk/lib/jw_watch_sdk.dart) export 分组一致：

| 模块 | Honey 命令域（排期） | W5 交付 |
| --- | --- | --- |
| `WSWatch` | 全局扫描、DB、`createSession` | W5.1 |
| `WSWatchSession` | 连接、capabilities、historyScope | W5.1 |
| `settings` | 0x02 | W5.4（W5.1 可挂空壳目录） |
| `history` + `historyStore` | 0x05 | W5.1 挂 store 壳；W5.3 全量同步 |
| `measure` | 0x11 | W5.4 |
| `control` / `notify` | 0x04+ | W5.4 |
| `today` | 0x60–0x63 | W5.4 |
| `debug` | 帧/Raw | W5.1 可选，不进业务必经路径 |

详细成员签名 **以 JW 对应类为准**；逐项能力排期见 [ws-watch-api-coverage.md](ws-watch-api-coverage.md)。

---

## 4. 覆盖表与 W5.0 产出

- [ws-watch-api-coverage.md](ws-watch-api-coverage.md)：HoneyProtocol 对照与三态；**impl 在 Greenfield 后一律回 `none`，待 W5.1+ 填写**。
- 码云 W5.0：[IKUCE5](https://e.gitee.com/priodigit/dashboard?issue=IKUCE5)

---

## 5. 实施顺序（冻结）

1. 文档与删包、HoneyBox 去 WS 依赖（§0）  
2. **编译验证**  
3. **W5.1**：JW 工程骨架复制 → 新建 `ws_watch_sdk` / `ws_watch_demo` 与 `WS*` 公开 API；Honey 协议实现随迭代填入（首版不追求全量 codec）  
4. W5.2–W5.5：见 [ws-watch-implementation-plan.md](ws-watch-implementation-plan.md)
