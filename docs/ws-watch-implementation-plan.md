# W5：完整 WS Flutter SDK 实施计划

> 状态：**W5.0 基线已落档**（[覆盖表](ws-watch-api-coverage.md)、[API 冻结](ws-watch-public-api-freeze.md)）；**Greenfield 重置已执行**（见 §0）。码云 Epic **[IKUCE2](https://e.gitee.com/priodigit/dashboard?issue=IKUCE2)**，子任务 §9。前置 **T1–T3 已完成**；JW **T4.0–T4.5 已闭环**（见 [jw-watch-sdk-implementation-plan.md](jw-watch-sdk-implementation-plan.md)、[迁移计划 §20](ws-watch-migration-plan.md)）。  
> 工程约定：**公开 API / Session / Demo 信息架构对齐 `jw_watch_sdk` + `jw_watch_demo`（`JW*` → `WS*`）**；**设备协议**：JW = 老 HL 私有协议，WS = **新 HoneyProtocol**（codec 独立实现，不复用 JW）。WS SDK/Demo 为 **首版 Greenfield**，删包后仓库内尚无任何 WS 落地代码。**不从旧 M1–M6 port**；**不**保留 M 系 `@Deprecated`。链路下层共用 `watch_frame_channel` + transport；**SDK 与 Demo 分包**，业务不进 HoneyBox。  
> 协议：[HoneyProtocol](https://realmcu.github.io/HoneyProtocol/) `0x05-data` 等；设计细节见 [ws-watch-sdk-design.md](ws-watch-sdk-design.md)（M 系实现章节为 **historical**）。  
> **当前无 WS 真机**：**W5.1–W5.5** 以模拟器 + 单测/集成测为验收面；**W5.6** 对应 M7 真机 UART（[IKSABE](https://e.gitee.com/priodigit/dashboard?issue=IKSABE)），不阻塞 W5.1–5.5 关单。

---

## 0. Greenfield 重置（2026-11，W5.1 前置）

| 步骤 | 状态 | 说明 |
| --- | --- | --- |
| 0.1 文档 | ✅ | 本文 §0、API 冻结文、覆盖表顶注；`ws-watch-sdk-design` M3–M6 标 historical |
| 0.2 删包 | ✅ | 移除 `packages/ws_watch_sdk`、`packages/ws_watch_demo` **整目录**（含 example/integration_test） |
| 0.3 HoneyBox | ✅ | `pubspec` / CI 去 WS workspace 与依赖；**不**挂载 `ws_watch_demo`；Watch Lab 仅 JW |
| 0.4 宿主编译 | ⏳ | **由你本地 `flutter pub get` + 构建验证** |
| 0.5 骨架复制 | ⏸️ | **0.4 通过后**：从 `jw_watch_sdk` / `jw_watch_demo` **复制工程骨架**（目录分层 + Watch/Session/Demo 习惯）→ 新建 `ws_watch_sdk` / `ws_watch_demo` 与 `WS*` 公开 API；**Honey 协议编解码在 SDK 内按规范新写**（正常模块命名，非另起「L2 包」） |

**废止：** 码云 **M1–M6** 在 WS 侧视为 **superseded**（JW 线 T4 仍有效）；W5.1 验收为「JW 同构公开 API + 首版包壳 + Sim 最小连通」，**不再**要求「M3–M5 测试迁移通过」。`ws_watch.db` 与旧 M 表 **零兼容**。

**数据库：** 仍用文件名 `ws_watch.db`，schema 按 [jw-watch-database-design.md](jw-watch-database-design.md) **WS 化重写**，与旧 M5 drift **不迁移**。

---

## 1. 交付目标与完成标准

交付独立 `packages/ws_watch_sdk` + `packages/ws_watch_demo`：

- **API 形状对齐 JW**：`WSWatch`（扫描、全局 `ws_watch.db`）+ **`WSWatchSession`**（单连接、settings / history / measure / control / notify / today 等挂在 session 上），与 `JWWatch` + `JWWatchSession` 同构；调用方读 JW 文档即可理解 WS 分组，仅前缀与类型不同。
- **Honey 新协议（HoneyProtocol）**：设置 `0x02`、绑定 `0x03`、数据 `0x05` v1、点测 `0x11` 等；**不**复用 JW 老协议 codec 或 JW 历史 Key。
- **历史同步：HoneyProtocol 全量类型**（请求键 **0x01–0x1F**、数据键 **0x21–0x3F**，以 `0x05-data.rst` 为准）；**W5.3 一次性交付** 全部 codec + drift 表 + 同步，M5 步数/心率为起点代码而非终态范围。
- **内置 drift/SQLite** `ws_watch.db`：按类型分表、查询 API 语义对齐 `JWHistoryStore`（设备+用户+时间范围），**表结构与 JW 库不共用**。
- **模拟器为 Honey 协议设备侧真源**：`SimWatchDevice`（及注册工厂）在无固件时承担协议状态、历史生成、设置读写、点测/上报；通过 **integration_test** 跑通与 `jw_watch_demo` 同级主路径。
- Demo **视觉与信息架构对齐** `jw_watch_demo`（连接、设置、数据首页、同步顶区、类型详情），**仅依赖** `ws_watch_sdk` 公开 API，**不**与 SDK 同包。

**完成标准（W5 主线，模拟器证据即可关单子阶段）：**

- 覆盖表内 **协议-active** 的 `0x05` 历史类型均有 decode → 表 → `query`；全量同步流程 `0x40` → 数据 → `0x41` → 确认 `0x42` 在 Sim 上可重复、可取消、失败不误确认。
- 设置/测量/控制/通知/API 与 JW **同级门面** 暴露；能力 unknown / unsupported 行为一致。
- `ws_watch_demo` 在 `simulationEnabled` 下可完成：连接 → 设置抽样 → **全类型或分批同步** → 库查询 → 点测（若协议已定义）。
- M7：**有固件后**补 UART profile、时序与 payload 上限差异清单，**不推翻** W5 模拟器验收结论。

不包含：OTA、七牛、手机通知采集服务、工厂/Dump/Flash 等设计文档已排除命令。

---

## 2. 架构：与 JW 对齐的分层

```text
ws_watch_demo（独立 package，仅公开 API）
        │
        ▼
WSWatch                    JWWatch（对照）
  ├─ scanner / initialize
  ├─ WSHistoryStore.open → ws_watch.db
  └─ connect → WSWatchSession
        │
        ▼
WSWatchSession             JWWatchSession
  ├─ settings   (0x02)
  ├─ history    (sync + offline query)  ← 0x05 全量
  ├─ measure    (0x11 …)
  ├─ control    (0x04 / 扩展 cmd)
  ├─ notify     (0x04 …)
  ├─ today      (0x05 Key 0x60 段，若产品需要)
  └─ debug      (帧/Raw，不进业务必经路径)
        │
        ▼
WSSession + WSLink adapter → watch_frame_channel → transport (sim / BLE UART)
        │
        ▼
SimWatchDevice（设备端 HoneyProtocol 行为，W5.2 扩全）
```

**与现状差异（W5.1 必做）：**

| 现状（M3–M6） | 目标 |
| --- | --- |
| 单 `WSWatch` 内嵌 machine，`settings`/`data` 挂 watch | `WSWatch` + **`WSWatchSession`**，`data` 拆为 **`history`**（sync + store scope） |
| M2 Lab 与 `connect` 互斥 | Lab 收入 **`debug`** 或 Deprecated；日常仅 **Session + Sim 设备 ID** |
| `data.sync(type: steps \| heartRate)` 单类型 | **`syncHealthData()`** 级联/协调器：对齐 JW 多类型一轮同步 + 进度（wire 条数来自 `0x40`） |
| 公开 export 偏 M 系命名 | 冻结与 JW 平行的模块名；旧 API 可短过渡 `@Deprecated` |

**禁止：**

- `watch_core` 或 JW/WS 共用健康 model/表。
- Demo 页面 import `session/`、`protocol/` 内部类型（调试用 `debug` 门面除外）。
- 在 WS SDK 内 import `jw_watch_sdk`。

---

## 3. 功能基线与覆盖表（W5.0）

### 3.1 对照来源

| 来源 | 用途 |
| --- | --- |
| HoneyProtocol RST（`0x02-settings`、`0x03-bind`、`0x05-data`、`0x11-measurement` 等） | L2 地址、字段、无效值 |
| [ws-watch-sdk-design.md](ws-watch-sdk-design.md) §8–§11、附录 A | 已有 M1–M6 行为与 DB 字段 |
| `jw_watch_sdk` 公开 API 清单 | **门面分组与语义**对照（非字节） |
| `packages/ws_watch_sdk/lib/src/protocol/`、`tool/generate_protocol_catalog.py` | 注册表与 unimplemented 元数据 |

### 3.2 覆盖表字段（与 JW T4.0 同构）

每条记录：**协议地址** · **Dart 公开 API** · **codec/向量** · **drift 表** · **Sim 场景** · **Demo 入口** · **实现/设备/证据** 三态。

### 3.3 历史类型（W5.3：一次全量）

以 **`0x05-data.rst` Version 1** 为准：同步开始 `0x40` 中 **type 1–31** 与请求 Key **0x01–0x1F**、数据 Key **0x21–0x3F** 一一对应。

**决策（已定）**：**W5.3 内一次交付 RST v1 已定义的历史类型**（请求 **0x00～0x0A**、数据 **0x21～0x2A**、控制 **0x40～0x42**；详见 [覆盖表 §2/§6](ws-watch-api-coverage.md)）。分区 **0x0B～0x1F / 0x2B～0x3F** 无 RST 示例 → **reserved**，不纳入 W5.3 强制关单。M5 步数/心率保留并纳入全量协调器。

| 请求 Key | 数据 Key | M5 现状 | W5.3 交付 |
| --- | --- | --- | --- |
| 0x01 | 0x21 | 已实现 | 纳入全量 |
| 0x02 | 0x22 | 未实现 | codec + 表 + 向量 |
| 0x03 | 0x23 | 已实现 | 纳入全量 |
| 0x04–0x1F | 0x24–0x3F | 未实现 | **同迭代全部补齐**（名称与字段以 RST 为准） |

**`syncHealthData()`**（对齐 JW）：W5.3 关单后 Sim 可走完整 `0x40 → 数据 → 0x41 → 0x42`；开发中未齐类型仍遵守设计文档 §10.2。关单条件：**覆盖表 §6.1 各行均为 implemented**（0x00～0x0A 类型 + 控制三元组）。

运动详情 `0x80`/`0x81`、今日 `0x60` 段：列入覆盖表；默认可归 **W5.4** 或 W5.3 尾部，在 W5.0 冻结归属。

### 3.4 非历史门面（W5.4）

| 域 | 协议 | JW 对照 | 阶段 |
| --- | --- | --- | --- |
| 连接与身份 | 0x03 + 0x02 初始化 | T4.1 | W5.1 |
| 设置 | 0x02 active 项 | T4.2 | W5.4 |
| 点测 / 自动监测 | 0x11 等 | T4.5 measure | W5.4 |
| 控制 / 通知 | 0x04 等 | T4.5 control/notify | W5.4 |

---

## 4. 模拟器（W5.2）

**目标：** 无真机时，Sim 设备行为 ≡ 固件应然行为（在规范已定义范围内）。

| 能力 | 要求 |
| --- | --- |
| 设备态 | 语言、显示格式、闹钟等可读写；跨连接保留 |
| 能力位 | `0x02` Key `0x31` 与功能开关一致 |
| 历史 | 按类型生成可重复 seed 数据；支持 `0x40` 声明条数、分批 `0x21…`、异常 `0x41` 码 |
| 点测/上报 | 异步推送走 session 路由，不 completing 错误 Future |
| 脚本 | `test/sim/` + 可选 fixture JSON；integration_test **Simulator 全流程** |

验收：**GHW 类真机脚本逻辑改为 Sim 对等脚本**，条数/校验与 DB 一致。

---

## 5. 数据闭环（W5.3，单 issue：存储 + 全量历史同步）

**一次交付**（原「数据库」与「0x05 同步」合并为 **W5.3**，不再拆 W5.3 / W5.4 两个 issue）：

1. **数据库**：`ws_watch.db` schema 升级（v3+）；**0x01–0x1F 每类型对应表**；`WSHistoryStore` + `WSHistoryScope`；查询/删除语义对齐 `JWHistoryStore`。
2. **协议**：全部历史 codec、注册表、向量；**`syncHealthData()`** 协调器（进度来自 `0x40` / received）。
3. **模拟器**：W5.3 关单前 `SimWatchDevice` 须支持 **各类历史** 全量同步（与 §4 联调，W5.2 可先骨架）。

`SyncLogs` 保留；顶区进度可对齐 `jw_data_home_header` v0.4。

---

## 6. 业务能力（W5.4，单 issue：设置 + 测量 + 控制 + 通知）

原 W5.5 / W5.6 合并为 **W5.4**（一个码云子任务，工程内仍可按模块提交）：

- **设置**：`0x02` 覆盖表 active 项，读写与能力门控对齐 JW `settings`。
- **测量**：`0x11` 点测与自动监测；若协议有 push，可参考 JW Measure 透明缓存模式（仅 WS 槽位）。
- **控制 / 通知**：`0x04` 及扩展 cmd；Stream 与 session 路由对齐 JW。

验收：Sim 上设置抽样读写、点测起停、至少一条控制/通知路径。

---

## 7. Demo（W5.5，独立 `ws_watch_demo`）

| JW Demo 区域 | WS Demo 目标 | 依赖 |
| --- | --- | --- |
| 连接向导 / 最近设备 | 同构；默认 Sim 设备 | `WSWatch` + Session |
| 设置树 | 对齐导航；能力灰显 | `session.settings` |
| 数据首页 + 同步顶区 | 视觉对齐 v0.4；今日概要若协议有 `0x60` | `history` + today |
| 类型卡片 + 详情图表 | 类型齐后移植图表模式 | `historyStore.query` |
| 控制 / 点测实验室 | 对齐交互 | `control` / `measure` |
| M6 Raw/帧/协议表 | 保留为 **调试抽屉**，不挡主路径 | `debug` |

**不做：** 在 `ws_watch_sdk` 内嵌 Widget；不把 JW Demo 代码共用进 WS 包（可复制交互规范/原型 HTML）。

---

## 8. 分阶段实施（W5.0–W5.6，连续编号）

| 阶段 | 名称 | 交付摘要 | 验收（默认 Sim） |
| --- | --- | --- | --- |
| **W5.0** | 覆盖表 + API 冻结 | HoneyProtocol 全表；JW↔WS 门面对照 | 文档 + 评审 |
| **W5.1** | Greenfield 骨架 | 从 JW 复制工程骨架；新建 `WS*` 公开 API（首版）；Honey codec 随模块逐步填充 + Sim 最小连通 | `flutter analyze` + 最小连接单测 |
| **W5.2** | 模拟器 v2 | 设备态、异常路径；为 W5.3 历史打底 | integration_test 基础链路 |
| **W5.3** | 数据：存储与全量历史同步 | **0x01–0x1F codec+表** + `WSHistoryStore` + `syncHealthData` | 全量同步 2 轮去重 |
| **W5.4** | 业务能力 | 设置 + 点测/监测 + 控制/通知 | Sim 读写 + 点测/上报 |
| **W5.5** | 产品 Demo | `ws_watch_demo` 对齐 JW 主路径 | 独立 example + integration_test（**暂不**要求 HoneyBox 卡片） |
| **W5.6** | M7 真机 | UART；跟踪 [IKSABE](https://e.gitee.com/priodigit/dashboard?issue=IKSABE) | 固件记录 |

**依赖：** `W5.0 → W5.1 → W5.2 → W5.3 → W5.4 → W5.5 → W5.6`（W5.2 与 W5.3 开发期可并行，**W5.3 关单须 Sim 历史齐**）。

---

## 9. 码云范围

挂在 program **Flutter Demo SDK**（`wofit-android` 工作项通道），与 JW [IKSKW1](https://e.gitee.com/priodigit/dashboard?issue=IKSKW1) 并列；父级可挂 [IKKGIB](https://e.gitee.com/priodigit/dashboard?issue=IKKGIB)。

| 子任务 | 标题 | Issue |
| --- | --- | --- |
| **父 W5** | 【HoneyBox】【WS Watch SDK】W5 完整实现与模拟器验收 | [IKUCE2](https://e.gitee.com/priodigit/dashboard?issue=IKUCE2) |
| W5.0 | 覆盖表与 WSWatch/Session API 冻结 | [IKUCE5](https://e.gitee.com/priodigit/dashboard?issue=IKUCE5) |
| W5.1 | 门面迁移 Watch + Session | [IKUCE6](https://e.gitee.com/priodigit/dashboard?issue=IKUCE6) |
| W5.2 | SimWatch 协议完备 | [IKUCE7](https://e.gitee.com/priodigit/dashboard?issue=IKUCE7) |
| W5.3 | 数据：0x05 全类型存储与同步（0x01–0x1F 一次交付） | [IKUCE8](https://e.gitee.com/priodigit/dashboard?issue=IKUCE8) |
| W5.4 | 业务能力：设置 / 测量 / 控制 / 通知 | [IKUCEA](https://e.gitee.com/priodigit/dashboard?issue=IKUCEA) |
| W5.5 | ws_watch_demo 产品化 | [IKUCEB](https://e.gitee.com/priodigit/dashboard?issue=IKUCEB) |
| W5.6 | （已有）M7 真机 UART | [IKSABE](https://e.gitee.com/priodigit/dashboard?issue=IKSABE) |

**建议迭代：** Sprint1 = W5.0+W5.1；Sprint2 = W5.2+W5.3；Sprint3 = W5.4+W5.5；固件后 = IKSABE（W5.6）。

---

## 10. 风险与决策记录

| 项 | 决策 |
| --- | --- |
| 门面 | **JW Watch + Session** |
| API | **与 JW 同构**，L2 独立 |
| 历史 | **0x01–0x1F 一次 codec+表**（**W5.3** 单 issue） |
| 业务 | 设置/测量/控制/通知合并为 **W5.4** 单 issue |
| 编号 | **W5.0–W5.6 连续数字**，无 D/B 别名 |
| 无真机 | **W5.5 前**以 Sim 关单 |
| SDK/Demo | **严格分包** |

---

## 11. 文档与仓库联动

- 本文：**实施排期与范围**。
- [ws-watch-sdk-design.md](ws-watch-sdk-design.md)：**协议与模块细节**（门面章节 W5.1 后需改 `WSWatch` 描述）。
- [ws-watch-migration-plan.md](ws-watch-migration-plan.md)：**T1–T3 + JW T4 + WS W5** 总线图。
- **W5.0 产出**：[ws-watch-api-coverage.md](ws-watch-api-coverage.md)、[ws-watch-public-api-freeze.md](ws-watch-public-api-freeze.md)。
