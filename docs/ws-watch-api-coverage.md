# WS Watch SDK 能力覆盖表（W5.0）

> **状态**：W5.0 基线（2026-11）；**Greenfield 后无 SDK 源码**，表中既有 **impl/device/evidence** 仅作排期与协议对照，**不表示仓库内仍有实现**（待 W5.1 复制 JW 骨架后重填）。  
> 与 [jw-watch-sdk-implementation-plan.md](jw-watch-sdk-implementation-plan.md) §2.2 **三态分离** 同构。  
> **规范真源**：[HoneyProtocol](https://realmcu.github.io/HoneyProtocol/)（仓库 `HoneyProtocol/docs/protocol/*.rst`）。  
> **机器可读清单**：W5.1 起在 `packages/ws_watch_sdk` 重建 `tool/generate_protocol_catalog.py` + `catalog.dart`。  
> **门面冻结**：[ws-watch-public-api-freeze.md](ws-watch-public-api-freeze.md)。  
> **码云**：[IKUCE5](https://e.gitee.com/priodigit/dashboard?issue=IKUCE5)

---

## 1. 三态与阶段列

| 列 | 含义 |
| --- | --- |
| **impl** | `none` / `partial` / `done` — Dart 公开 API + codec + 持久化（若适用） |
| **device** | `unknown` / `sim` / `fw` — 当前验收面（无 WS 真机阶段默认以 `sim` 为目标） |
| **evidence** | 单测、integration_test、向量、Demo 路由；无则写 `—` |
| **stage** | W5.0～W5.6 / M* — 本表排期标签 |

**规则**：`impl=done` 且 `device=unknown` 不允许关单；设备不支持不得把 `impl=none` 标成 `done`。

---

## 2. W5.0 冻结决策

| 项 | 决策 |
| --- | --- |
| 门面 | **W5.1** 起 `WSWatch` + **`WSWatchSession`**，与 `JWWatch` + `JWWatchSession` 同构（见公开 API 冻结文） |
| 历史同步范围 | **W5.3** 以 `0x05-data.rst` **v1 已定义** 的历史类型为强制关单集：**请求 0x00～0x0A**、**数据 0x21～0x2A**、**控制 0x40～0x42** |
| 分区预留 | 同步请求 **0x0B～0x1F**、数据 **0x2B～0x3F** 在规范分区中预留，**当前 RST 无示例** → 标 `reserved`，**不纳入 W5.3 强制关单**；若 RST 增补再开 issue |
| `0x40` 进度 type 字节 | 与 **同步请求 Key** 一致（如 `0x01` 活动），不是数据 Key `0x21`（见 RST 示例） |
| 今日数据 **0x60～0x63** | **W5.4**（`session.today`）；不进 W5.3 历史表 |
| 运动详情 **0x80/0x81** | **W5.4**（`session.sport` 或 `history` 扩展）；与主历史同步互斥（RST §6） |
| 点测 **0x11** | **W5.4** `session.measure` |
| 通知/控制 **0x04** 等 | **W5.4** `session.control` / `session.notify` |
| OTA **0x01**、日志 **0x0a**、WiFi 等 | **排除** W5 主线（设计文档已排除） |

---

## 3. 公开门面 ↔ JW 对照

| JW（T4 已交付） | WS 目标模块 | 当前 M 系实现 | stage |
| --- | --- | --- | --- |
| `JWWatch.initialize` / `historyStore` | `WSWatch.initialize` / `historyStore` | 连接时隐式 `historyStore()`，无 initialize | W5.1 |
| `JWWatch.startScan` / `createSession` | 同左 | `WSWatch.scanner` 静态 + `connect` 在 Watch | W5.1 |
| `JWWatchSession` + `historyScope` | `WSWatchSession` + `historyScope` | 无 Session 类型；scope 在 `WSDataConnection` | W5.1 |
| `JWWatchSession.syncHealthData` | `WSWatchSession.syncHealthData` | `WSData.sync(type: steps\|heartRate)` 单类型 | W5.3 |
| `JWWatchSession` settings API | `session.settings` | `WSWatch.settings` | W5.1 迁挂；W5.4 扩表 |
| measure / control / notify / today | 同名 Session 子模块 | 未导出 | W5.4 |
| `JWWatchSession` diagnostics | `session.debug` | `WSWatch.debug` + `openSimulationLab` | W5.1 收拢 debug |

---

## 4. 连接与身份（cmd 0x03 + 初始化 0x02）

| 协议 | 名称 | Dart API（目标） | codec | impl | device | evidence | stage |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0x03/0x01 | 绑定 | `session.bind` / 状态机 | `cmd_03_bind.dart` | partial | sim | `m3_connection_test` | M3 / W5.1 |
| 0x03/0x03 | 登录 | 状态机 `login` | 同上 | partial | sim | 同上 | M3 / W5.1 |
| 0x03/0x05 | 解绑 | `WSWatch.unbind` → Session | 同上 | partial | sim | 同上 | M3 / W5.1 |
| 0x02/0x01 op0 | 对时 | 初始化链 | `WSInitializationProtocol.time` | partial | sim | M3 | W5.1 |
| 0x02/0x02 op0 | 手机系统 | 初始化链 | `setSystem` | partial | sim | M3 | W5.1 |
| 0x02/0x30 | 设备信息 | `deviceInfo` | `WSDeviceInfo` | partial | sim | M3 | W5.1 |
| 0x02/0x31 | 能力位 | `capabilities` | 16B blob | partial | sim | M3/M4 | W5.1 |

公开类型：`WSConnectionState`、`WSDeviceInfo`、`WSCapabilities`、`WSUserId`（已 export）。

---

## 5. 设置（cmd 0x02）

`core_registry.dart` 中 **active** 项 = 已实现可发送（非 Raw）；catalog 中其余为 `unimplemented` 或 `reserved`。

| Key×op | 名称（catalog） | 目标 API | impl | device | evidence | stage |
| --- | --- | --- | --- | --- | --- | --- |
| 0x01/0 时间 | 对时 | init / `settings`（只写） | partial | sim | M3/M4 | W5.1 |
| 0x03 语言 | 读/写/通知 | `setLanguage` / `getLanguage` | partial | sim | `m4_settings_test` | M4 / W5.4 补项 |
| 0x04 显示格式 | 读/写/通知 | `WSDisplayFormat` 便利方法 | partial | sim | `m4_settings_test` | M4 / W5.4 |
| catalog 其余 0x02 | 见 RST | `session.settings.*` | none | — | — | **W5.4**（覆盖表 active 项逐项） |

能力门控：`WSCapabilities` + `WSFeature` / `WSFeatureSupport`（与 JW unknown/unsupported 语义对齐，W5.4 补全矩阵）。

---

## 6. 历史与健康数据（cmd 0x05 v1）

### 6.1 同步类型（W5.3 强制集）

| 请求 Key | 数据 Key | `0x40` type | 名称 | drift 表 | impl | device | evidence | stage |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0x00 | — | — | 全量拉齐 | 多表协调 | none | — | — | W5.3 |
| 0x01 | 0x21 | 0x01 | 活动 15min 桶 | `StepRecords` | partial | sim | `m5_history_test` | W5.3 |
| 0x02 | 0x22 | 0x02 | 睡眠 | `SleepRecords`（待建） | none | — | — | W5.3 |
| 0x03 | 0x23 | 0x03 | 心率 | `HeartRateRecords` | partial | sim | `m5_history_test` | W5.3 |
| 0x04 | 0x24 | 0x04 | 血压 | 待建 | none | — | — | W5.3 |
| 0x05 | 0x25 | 0x05 | 血氧 | 待建 | none | — | — | W5.3 |
| 0x06 | 0x26 | 0x06 | HRV | 待建 | none | — | — | W5.3 |
| 0x07 | 0x27 | 0x07 | 压力 | 待建 | none | — | — | W5.3 |
| 0x08 | 0x28 | 0x08 | 体温 | 待建 | none | — | — | W5.3 |
| 0x09 | 0x29 | 0x09 | 血糖 | 待建 | none | — | — | W5.3 |
| 0x0A | 0x2A | 0x0A | 运动摘要 | 待建 | none | — | — | W5.3 |
| 0x40 | — | — | 同步开始 | — | partial | sim | M5 | W5.3 |
| 0x41 | — | — | 同步结束 | — | partial | sim | M5 | W5.3 |
| 0x42 | — | — | 同步确认 | — | partial | sim | M5 | W5.3 |

**W5.3 退出**：上表 0x00～0x0A 相关类型均为 **impl=done**（含 `syncHealthData()` 一轮协调）；schema **v3+**；Sim 两轮全量去重。

### 6.2 分区预留（非 W5.3 强制）

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 请求 0x0B～0x1F | reserved | RST 无定义；禁止发送（除非 RST 更新） |
| 数据 0x2B～0x3F | reserved | 同上 |

### 6.3 今日与运动详情（W5.4）

| Key | 名称 | 目标 API | stage |
| --- | --- | --- | --- |
| 0x60～0x63 | 今日查询/推送/策略 | `session.today` | W5.4 |
| 0x80～0x81 | 运动详情拉取/流式 | `session.sport` | W5.4 |

---

## 7. 点测（cmd 0x11）

| 项 | impl | stage |
| --- | --- | --- |
| catalog 所列 0x11 向量 | none（占位 `cmd_11_measurement.dart`） | W5.4 |

---

## 8. 通知与控制（cmd 0x04 等）

| 项 | impl | stage |
| --- | --- | --- |
| `cmd_04_notification.dart` 拆分 control/notify | none | W5.4 |

---

## 9. 传输与调试

| 项 | impl | evidence | stage |
| --- | --- | --- | --- |
| L0/L1 `watch_frame_channel` + sim/BLE UART | partial（sim） | T1–T3 | 已完成 |
| `WSDebugApi` Raw / 协议表 | partial | `m6_debug_test` | M6；W5.5 进调试抽屉 |
| `openSimulationLab` | partial | M2 | **W5.1** @Deprecated，合并 Sim 主路径 |

---

## 10. Demo 入口（W5.5 产品化）

| 能力 ID（拟） | 当前页面 | 目标（对齐 JW） | stage |
| --- | --- | --- | --- |
| `connection.*` | `m3_connection_page` | 连接向导 + 会话条 | W5.5 |
| `settings.*` | `m4_settings_page` | 设置树 | W5.5 |
| `history.*` | `m5_history_page` | 数据首页 v0.4 + 详情 | W5.5 |
| `debug.*` | `m2_simulation_lab_page` | 调试抽屉 | W5.5 |

正式 **feature ID 表** 在 W5.5 与 JW `feature_catalog` 对齐时冻结一行引用本表。

---

## 11. M 系 → W5 过渡 API

| 当前（导出/行为） | W5.1+ 目标 | 动作 |
| --- | --- | --- |
| `WSWatch.connect` | `createSession` + `session.open` | 迁移；`connect` 可 Deprecated 包装 |
| `WSWatch.settings` / `data` | 迁至 `WSWatchSession` | W5.1 |
| `WSData.sync(type:)` | `session.syncHealthData()` | W5.3；前 Deprecated |
| `openSimulationLab` / `closeSimulationLab` | `WSConfig.simulationEnabled` + 常规 Session | W5.1 Deprecated |
| `WSWatch.scanner` 静态工厂 | 保留或并入 `WSWatch.startScan` | W5.0 冻结：与 JW 一致走实例方法（W5.1 改） |

---

## 12. 包边界（禁止项）

- `ws_watch_sdk` **不得** depend_on `jw_watch_sdk`。
- **不得** 与 JW 共用 health drift 表或 model。
- `ws_watch_demo` **不得** import `jw_watch_demo`；可抄 UX 规范/HTML 原型。
- Demo **不得** import `package:ws_watch_sdk/src/**`（除公开 `debug` 观测）。
- HoneyBox **`lib/pages/ws_watch/`** 仅 launcher，**不** 承载业务协议逻辑。

---

## 13. 维护

- 实现状态变更时：**先改本表**，再改 issue 证据列。
- 规范变更：先跑 `dart run` / `python tool/generate_protocol_catalog.py`，再 diff `catalog.dart`，最后更新本表 impl 列。
