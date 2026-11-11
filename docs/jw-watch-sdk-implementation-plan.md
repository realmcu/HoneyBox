# T4：完整 JW Flutter SDK 实施计划

> 状态：**T4.0–T4.5 主体已实施**（2026-11，`feat/ws-watch-sdk-skeleton`），进入**覆盖表缺口补齐与 bugfix**。前置 T1–T3 已完成；见[整体迁移计划](ws-watch-migration-plan.md) §20。**T4.6/T4.7 码云子任务已取消**，Demo 与真机验收并入 `jw_watch_demo`。产品设计见 [JW Flutter SDK 与 Demo 产品设计](jw-flutter-sdk-demo-design.md)。

## 1. 交付目标与完成标准

交付独立 `packages/jw_watch_sdk`：可扫描并连接现有 JW 设备，完成认证/初始化、设置、历史同步、实时测量、控制、通知及本地数据查询，拥有自己的公开数据类与数据库。调用方可只接 JW，也可同时接 WS；不需要 HoneyBox 的 provider、页面、数据库或原生手动注册。

这次不是把 `lib/services/jw/` 搬成 package 即结束。现有 Flutter 实现是可复用起点，Android SDK 的有效能力与量产设备行为是功能基准；对照缺口必须进入实施任务。

完整交付需要同时满足：

- 计划支持的 Android JW 能力均有对应 Dart API、编码/解析、状态/错误与测试；声明“不支持设备”不能代替尚未实现的 SDK 功能。
- 支持真机的完整操作通过新 SDK → 公共 frame channel → BLE transport 收发，没有借道旧 JW Session/ACK 实现。
- JW 数据库真实保存设备数据，重启/断开后可查询；事务、去重、取消/失败、确认不确定与恢复状态有证据。
- Demo 使用 SDK 公开 API，独立 example 可安装、接入方可复现；功能验收记录型号、固件、平台和原始通信证据。
- 未覆盖型号、未实现能力、尚无设备证据分别列出，不能因覆盖表填写完整就宣布功能完成。

OTA、手机系统通知采集、七牛、通用多设备原始采集不包含在 JW 协议 SDK 的完成标准中；这些是独立模块。JW 的通知发送/设备事件 API 属于本计划。

## 2. 功能基线与覆盖表（T4.0）

### 2.1 对照来源

源码路径相对 HoneyBox 根目录：

- Android：`../Cavo-Ble-SourceCode-Android/UkProtocolLibary/src/main/java/com/wosmart/ukprotocollibary/v2/`。
- 公开入口：`JWManager`、`JWSettingsManager`、`JWFunctionManager`、`JWDataManager`、`JWNotifyManager`；结合 `JWSDKConfig`、`JWDBConfig`、实体和 listener，而非只数 `JWManager` 方法。
- 迁移说明：Android `UkProtocolLibary/docs/v2-{scan-connect,bind,settings,sports-data,control,notify,custom-made,multiple-cmd}-migration.md`。
- 现有 Flutter：`lib/services/jw/`、`lib/providers/jw_device_provider.dart`、`lib/pages/watch/jw_*` 与 `health/jw_*`；现有测试、抓包和固件契约共同核对。

T4.0 固定 Android/Flutter 源 commit 与首批真机型号/固件；若源码说明与设备行为不一致，记录差异和证据，避免照搬旧实现缺陷。

### 2.2 必须建立逐项覆盖表

每个 API/事件/数据类型至少记录：Android 入口、CMD/version/key、能力/profile 条件、Dart API 与类型、读写/上报语义、Flutter 当前实现、编码向量、数据库映射、Demo 验收入口、测试、真机结果和未完成原因。每个实际重载也要核对其参数语义。

分开维护三个状态：**实现状态**（未实现/开发中/完成）、**设备支持状态**（unknown/supported/unsupported）、**证据状态**（向量/单测/真机）。例如，设备不支持血糖不能把未实现的血糖 codec 标为“已完成”。历史/废弃能力的排除需写明依据和范围决定；待确认项保持未完成。

| 功能域 | Android/Flutter 对照范围 | 所属阶段 |
| --- | --- | --- |
| 连接与身份 | 扫描/过滤、连接/断开、登录/绑定/解绑、设备信息/功能/电量、初始化、重连 | T4.1 |
| 常规设置 | 用户信息、对时/手机系统、目标、语言/时制/单位/日期、亮屏/亮度、设备开关等 | T4.2 |
| 提醒与配置 | 两代闹钟、久坐、翻腕、勿扰、高心率/热应激、自动测量、睡眠/低氧及设备特有开关等 | T4.2，扩展缺口在 T4.5 收口 |
| 历史与离线查询 | 步数、睡眠、心率、血压、血氧、体温、运动、HRV、压力、准备度及其他有效历史类型 | T4.3/T4.4 |
| 扩展健康数据 | 血糖、尿酸/血脂及连续监测、体脂、体检、佩戴、pulse/sauna/HR movement、HRV RMSSD、紫外等 Android 已公开数据与事件 | T4.3–T4.5 按清单补齐，不能默认为不迁 |
| 实时测量与运动 | 心率/血压/血氧/体温、ECG/血糖等测量，自动监测配置、设备运动查询/开始/暂停/恢复/停止 | T4.5 |
| 控制与扩展 | 找设备、拍照、天气、音乐、计时、自定义 UI/颜色、通讯录/SOS、女性健康、饮水/服药等公开能力 | T4.5 |
| 通知与主动事件 | 来电/接听/拒接/其他通知、notify/function/data listener、组合命令与自定义事件 | T4.5 |

清单不是对当前设备能力的承诺；实现按有效协议覆盖，真机按能力组合测试。Android 中带 OTA 字样的状态读取仍作为普通命令核对，独立升级流程本身归 OTA 模块。

## 3. SDK 对外结构

建议门面 `JWWatch` 组合连接和功能服务，分组为 device/settings/history/measurements/sport/control/notify/debug；最终方法名在 T4.0 覆盖表冻结。保持 Dart 风格，不机械复制 Android 单例和回调签名。

- 默认使用公共 BLE 和当前帧通道，支持注入连接工厂/运行环境。外部不需要操作 FlutterBluePlus、裸 GATT 对象或 HoneyBox provider。
- 对外数据类统一 JW 命名，例如 `JWHeartRate`、`JWBloodPressure`；现有 `Jw*` 内部类型可通过 adapter 迁移，不借用 WS 的数据类、数据库实体或配置对象。
- Future 表示一次调用结果，Stream 表示连接变化/测量/设备主动事件。命令发送、帧 ACK、业务回应、读回验证分开表达；不把 `ACK` 翻译成“设备设置已生效”。
- 能力、配置契约、设备支持与实现状态分别判断；unknown 不能静默当 supported/unsupported。现有 `v101S200` 等契约限制迁移时保留依据。
- 调试 API 提供帧/Raw/操作结果观测，但日志监听、UI 暂停或导出不得阻塞真实通信。错误带阶段和可恢复信息，不泄露用户身份/凭据。
- 同一设备重复实例受 BLE 租约约束；业务 Session、同步任务和数据范围由各实例明确拥有。dispose 取消其任务，不关闭其他 SDK/实例仍在使用的公共资源。

## 4. T4.1：独立包与真实连接闭环

迁入现有 JW L2 codec、业务 Session 和 repository 的必要部分；L0/L1 可靠性由 T3 提供，禁止独立包内部仍保有另一套实际 ACK/重传队列。SDK 负责匹配 L2 回应，并通过受限发送句柄保留现有“匹配业务回应证明收包”语义。

实现扫描→选设备→连接→通知订阅→设备信息/能力→身份→登录/绑定→初始化→ready；保留设备支持的只读/未绑定状态，认证失败不能误显示 ready。绑定、解绑及用户确认遵循现有 JW 协议，不套用 WS 握手。

身份沿用现有 `jw_identity_v1.json`；安装/路径/文件异常不得自动更换身份抢绑设备。默认路径可配置，初始化/存储错误向上报告。连接取消、阶段超时、蓝牙关闭、断开重连和旧代次回应全部清理。

从本阶段提供薄真机验收页：扫描、设备信息、连接状态、登录/绑定/解绑、断开、帧观测。可先复用现有页面布局，但改为调用包公开 API，不等 T4.6 才接真机 UI。

**退出条件**：独立应用能操作现有 JW 真机；设备信息/能力/身份与旧实现一致；正常/失败/重连路径实际通过公共 BLE 与 frame channel；记录对 T2/T3 暴露的问题并在公共层修复，而非在 JW 私下增加第二套底层实现。

## 5. T4.2：设置和设备配置

按照覆盖表迁移并补齐设置 API，按“读取、写入、设备回应、可读回验证”分类。用户信息/时间/语言/单位等基础配置优先，再完成提醒、显示、自动监测和其他有效配置。

- 读回支持的配置执行写后读校验；只有发送型的接口返回提交结果，不伪造读回成功。
- 部分字段修改遵循该协议实际要求，必要时先读完整结构再改写，避免覆盖其他配置；相同配置事务串行。
- 常规配置继续按契约和能力准入，全局历史游标 reset 等危险/特定固件操作保留单独限制，不能恢复成全部功能按 T005/H001 锁死。
- 参数边界、单位转换、设备返回异常、通知先于回应、设备忙与写入失败均有测试；写入失败不得把本地缓存更新为成功状态。

**退出条件**：覆盖表内设置全部有实现或明确范围决定；真机支持项逐项写入/读回/恢复验证。重连后读取设备真实状态，不以 Demo 的最后一次输入充当设备状态。

## 6. T4.3：JW 独立数据模型与数据库

### 6.1 数据库选择与边界

采用 drift + SQLite，默认 `jw_watch.db`，拥有自己的 schemaVersion、生成代码与迁移测试。WS 继续使用自己的 `ws_watch.db`，两者没有共用健康表或 model。对外不暴露 drift DAO，应用通过 JW 查询接口获取 JW 类型。

先实现真实类型化数据库，不长期停留在通用 `Map<String, Object?>` + 文件 journal。原始数据保留用于排查/兼容，不能代替健康数据类型、索引与查询实现。不同类型的字段/时间语义按实际协议定义，不能强行套一个只含数值和时间的万能表。

### 6.2 表与仓储规划

| 存储域 | 主要内容与约束 |
| --- | --- |
| 记录范围 | 每次读写均要求 JW 登录 userID 和连接使用的 deviceMac；不建设备表、身份表或 deviceId 映射 |
| 各类健康记录 | 十张独立类型表，以 `user_id + device_mac + time` 为主键；不预建日汇总、raw 或诊断数据表 |
| 查询与去重 | 固定用户和设备范围内按 UTC 时间范围排序、分页、去重；每批写入使用事务 |

首个可用闭环优先步数/心率/血压，再按覆盖表补全全部有效类型。每增加类型必须同时完成公开模型、decode、表/索引、query、同步映射与测试；只有原字节落盘不算该类型完成。

### 6.3 数据语义与访问

- 健康记录以 UTC Unix 毫秒存储；连接认证后设备自动校时，时间字段是固定 userID + MAC 范围内的分页游标。
- 缺失/无效值不入库；字段单位由公开模型文档说明，不编码进字段名。
- 去重依据 userID、MAC 与时间；不同业务指标使用不同的表，因此同一时刻不会彼此覆盖。
- 查询支持设备/身份范围、类型、日期/时间区间、稳定排序分页；离线与重启后可查。删除按范围执行，并说明删除本地记录不自动重置设备游标。
- SDK 内明确同一路径的连接/引用管理和最后引用关闭，读写/导入/同步之间有事务边界；不同数据库路径隔离，WS/JW 两种 schema 的显式路径误用应被识别。

### 6.4 全新数据库边界

`jw_watch.db` 不读取、迁移或兼容旧 Flutter journal、旧数据库或 WS 数据库。Android 历史数据库仅可作为字段语义的人工对照，不属于运行时数据源。

**退出条件**：真实设备数据入库并在重启后查询；内存/磁盘库、同路径共享、事务、分页/删除、复合主键去重和 schema 升级均有测试。数据库是可独立使用的 JW 模块，不 import WS 或调试页面。

## 7. T4.4：历史同步完整闭环

每个有效历史类型按实际 JW 协议完成“启动→开始/数据/结束标记→解码→批次写入→持久化完成→设备确认→结果查询”。保留当前 START 显式类型映射与固件行为，不能直接复用 WS `0x05` 的 Key/同步流程。

- 协调器对业务同步状态负责，公共帧通道只负责可靠传递。ACK 丢失、重复帧、重复记录、重复同步分别验证，不把链路去重等同于数据库去重。
- 数据库真正提交成功后才发送该类型要求的设备完成确认；解析/数量/存储失败不误报成功。设备只要求特定确认行为的类型据协议实现，不强行统一一套确认命令。
- 提供类型化进度、接收/提交数量、空数据、取消、失败原因、确认 unknown 等结果；取消/超时后隔离旧回应，重连不能接着消费旧任务。
- 真机同步中断、设备忙、应用重启、提交后确认丢失、再次同步都要有可解释状态。只有协议和设备确实支持时才暴露续传/游标恢复，不伪造断点续传。
- 同步期间离线历史查询和必要的控制命令按 Session 策略管理；不允许两套同步任务并发推动同一设备游标。

**退出条件**：覆盖表中数据类型均有 decode→数据库→公开查询路径；支持真机类型完成首次/重复/空数据同步、断链/取消、重启离线查询与失败不确认验证，结果能关联到批次、记录和帧证据。

## 8. T4.5：测量、控制、通知和扩展补齐

### 8.0 Measure 自动监测：设备配置与透明缓存（设计约定）

自动监测的**开关、间隔、可选间隔档位**统一归属 **`JWSession.measure`**（`JWMeasure`）。接入方只使用 `read*` / `set*`，**不**感知缓存、设备主动上报、`syncSwitch`、Bootstrap 或 `forceRefresh`。

#### 对外语义

| 规则 | 说明 |
| --- | --- |
| 读配置 | 调用 `read*()` 得到当前设备上的配置；SDK 在连接期内可使用会话缓存，**对调用方透明**。 |
| 读不完整 | 该条目缓存不完整或不存在时，`read*()` **自动**发协议读设备，写满缓存后返回；不暴露 `forceRefresh`。 |
| 写配置 | `set*()` 成功则**立即**用提交值更新对应缓存；失败则不修改缓存。 |
| 重连 | `disconnect`、换 `deviceMac` 或新建会话时 **清空** `measure` 下全部设备配置缓存。 |
| 断线后 | 接入方应再次调用 `read*()`（缓存已清空，会走设备读）。 |

可选间隔与当前配置分 API 表达（学习成本低、与设置页 UI 一致）：

- **当前值**：如 `readHeartRateAutoMeasure()` → `JWAutoMeasureConfig`（`enabled` + `intervalMinutes`）。
- **可选档位**：如 `readHeartRateIntervalOptions()` → `List<int>`（分钟）；仅当设备支持心率自动监测且协议提供间隔种类时有效。

`settings` 门面的其它项（语言、勿扰等）不适用本节；若日后采用相同「透明缓存」模式，在 T4.2 文档中单独开表，**不**与 `measure` 混用缓存实现。

#### 对内实现（不写入公开 README 的要点）

- 单一会话内组件（建议名 `JWMeasureConfigCache`）按 **缓存 key** 分槽；`JWMeasure.read*` / `set*` 为唯一公开读写路径。
- 设备**主动上报**（含 `syncSwitch` 单项、运动 `0x12` / `0x18` 等）经 **unsolicited 路由表** merge 进对应槽位；**不**提供「一次读取 syncSwitch 全包」的公开 API。
- 部分推送只含子字段（例如 `syncSwitch` type=2 仅开关）：合并后若该 key 仍不完整，`read*()` 按上表自动补读设备。
- WoFit「连上按 App 习惯写回设备」属于 **App 层 Provisioning**，在 `ready` 后自行 `set*`；**不是** SDK 默认行为。

#### Measure 设备配置缓存 key 表

下表为 SDK **内部**缓存槽与协议来源；公开 API 仅「公开读 / 公开写」列。实现状态指 HoneyBox `jw_watch_sdk` 截至本约定起草时。

| 缓存 key | 公开读 | 公开写 | 缓存类型 | 视为「完整」 | 主动读（pull） | 被动更新（push，内部） | 间隔选项 API | 能力位 | 实现状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `heartRate.autoMeasure` | `readHeartRateAutoMeasure` | `setHeartRateAutoMeasure` | `JWAutoMeasureConfig` | `enabled` 与 `intervalMinutes` 均已知 | `cmd 0x05` `0x11` → `0x12` | `0x12` 主动下发；`syncSwitch` type **2** 仅更新 `enabled` | `readHeartRateIntervalOptions` | `JWDeviceFunction.rate` | **已实现**（透明缓存） |
| `heartRate.intervalOptions` | `readHeartRateIntervalOptions` | — | `List<int>` | 已知（含空列表） | 设置 `cmd 0x02` `0x3F` 请求 → 运动 `0x18` 间隔种类 | 运动 `0x18` 主动下发 | （同上） | `JWDeviceFunction.rate` | **已实现** |
| `spo2.autoMeasure` | `readSpO2AutoMeasure` | `setSpO2AutoMeasure` | `JWAutoMeasureConfig` | 同上 | `0x34` → `0x35` | `0x35`；`syncSwitch` type **4** 仅 `enabled` | 无独立选项 API（间隔按协议/机型；待覆盖表补） | `JWDeviceFunction.spo2Continuous` | 读写无缓存 |
| `bloodPressure.autoMeasure` | `readBloodPressureAutoMeasure` | `setBloodPressureAutoMeasure` | `JWAutoMeasureConfig` | 同上 | `0x3e` → `0x3f` | `0x3f`；`syncSwitch` type **3** 仅 `enabled` | 待覆盖表 | `JWDeviceFunction.rtkBp3` | 读写无缓存 |
| `bloodSugar.autoMeasure` | `readBloodSugarAutoMeasure` | `setBloodSugarAutoMeasure` | `JWBloodSugarAutoMeasureConfig` | `enabled` + `intervalMinutes` | `0x44` → `0x45` | `0x45`；`syncSwitch` type **8** 仅 `enabled` | 待覆盖表 | `JWDeviceFunction.bloodSugar` | 读写无缓存 |
| `temperature.control` | `readTemperatureControl` | `setTemperatureControl` | `JWTemperatureControlSetting` | 结构内各字段按 codec 定义齐全 | `0x23` → `0x24` | `0x24`；`syncSwitch` type **5**/**6**/**7** 映射部分开关 | — | `JWDeviceFunction.temperature` | 读写无缓存 |
| `pressure.autoMeasure` | `readPressureAutoMeasure`（待补） | `setPressureAutoMeasure` | `bool` 或扩展配置 | `enabled` 已知 | 待 Android V2 对齐 | `syncSwitch` 待核 | — | `JWDeviceFunction.pressure` | **仅 set** |

`syncSwitch` 解析：`cmd 0x07` key `0x1D`（Android `KEY_CTRL_CUS_RSP`）设备同步开关包；type 定义对齐 `ApplicationLayerSyncSwitchItemPacket`。SDK **仅**用于 merge 上表对应槽位，不对外暴露。

#### 验收与测试（本约定）

- 单元：缓存不完整时 `readHeartRateAutoMeasure` 触发 pull；`set` 成功后不 pull 再 `read` 仍得写入值；`disconnect` 后缓存 miss。
- 真机：连接后在不手动发读命令的情况下，设备若主动推 `0x18`/`0x12`，随后 `read*` 不额外发包（可用帧日志断言）；重连后第一次 `read*` 走 pull。

---

按功能表逐项完成，而非只保留当前调试控制台已有按钮：

- 实时测量：开始/停止/结果/主动上报，包含对应能力检查、重复调用、测量中断、超时与订阅释放。是否持久化按数据来源与 Android 语义明确，实时结果不能混作历史同步记录。
- 运动：查询、开始、暂停、恢复、结束及设备主动状态变化；状态以设备回应/事件为依据，拒绝或断连不能只更新 UI 为成功。
- 控制与扩展：逐项完成 Android 有效公开命令及参数/返回/事件，单列自定义和型号专属能力；不能用“其他接口稍后补”跳过覆盖表。
- 通知：来电、接听/拒接和其他通知的内容编码、长度/截断、设备回应/事件；发送 API 接收上层提供的通知内容，不依赖 Android NotificationListenerService。
- 监听：连接/设备功能/测量/通知等事件明确拥有者和释放语义，主动上报不错误完成当前业务读取；listener 等价能力可采用 Dart Stream。

**退出条件**：有效 API 缺口清零或已有明确范围决定；每项有参数/协议测试，真机支持项具备可执行验收入口和结果。未知/不支持/尚未实现的状态可区分，开发中的功能不能伪装成 unsupported。

## 9–10. T4.6 / T4.7（已取消）

码云 **IKSKRA / IKSKRB** 已删除。原「独立 example 收口」「全量宿主切换」里程碑改为：

- **`packages/jw_watch_demo`**：HoneyBox 挂载的主 Demo（连接、设置、数据、控制、测量）；`example/` 与集成测试满足 path 依赖与 CI。
- **真机验收**：在迭代中完成多轮联调，不再等待单独 T4.7 才宣布可用。
- **宿主切换**：`lib/services/jw/` 可与 package SDK 短期并存；完全下线旧链路由产品节奏决定，**非 JW SDK 关单前置**。

维护期验收域仍可参考原 T4.7 表格（连接/帧/业务/数据库/隔离），但按 issue 与覆盖表逐项补证据，不单独开里程碑。

## 11. 顺序、独立工作流与 WS 后续

主线：**T1 → T2 → T3 → T4.0 → T4.1 → T4.2/T4.3 → T4.4/T4.5**（**无 T4.6/T4.7**）。T4.2 和 T4.3 可按任务独立推进；T4.4 先贯通历史写库再补类型；**当前处于 T4.5 之后收尾**。

OTA、采集、七牛是独立工作流，按各自真实依赖安排，不排在 T4 主线里强制串行。它们发现公共 BLE 问题时修公共层，不另复制一套连接框架。

WS 近期只保持受基础提取影响的既有回归，不新增大规模模拟场景或 JW 模拟器。WS 固件到位后再做 M7，主要核对 UART/profile、L2、绑定/能力、业务时序和固件差异；复用 JW 已验证的底层机制与工程经验，但不混用 JW 公开模型或数据库，也不提前承诺固件接入零改动。
