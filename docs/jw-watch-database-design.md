# JW Watch SDK 数据库存储设计

> 状态：T4.3 设计冻结草案。适用于 `packages/jw_watch_sdk` 的
> `jw_watch.db`；不使用或修改 WS 的数据库、表或 migration。

## 1. 目标和边界

数据库是 JW SDK 的**健康历史查询库**，只保存产品实际需要的、已经
解析为业务模型的数据。它不是通信抓包库，也不承担 App 的云端上传、
Google 同步、用户账户或设备管理职责。

数据类型范围以 WS `0x05` 新协议保留的健康类型为产品基线；字段名称、
单位、有效值规则和实际解析仍以 JW 当前协议及其 Flutter 实现为准。

以下内容不进入 `jw_watch.db`：

- L0、L1、L2 原始帧和单条 payload；诊断抓包仅在用户显式开启时写入独立的
  限额文件。
- 上传状态、上传失败次数、云端或 Google 同步状态。
- WS 的表、模型、实体、数据库文件或 migration。
- WS `0x05` 的今日实时快照和运动详情采样。前者由当次查询/推送使用，后者
  仅在用户主动拉取时在内存中处理，不默认持久化。
- 旧 JW 的 `metabolism`、`readiness`。它们不在新的产品数据范围内，不再为其
  新建公开模型或表。

## 2. 共同约定

每张健康历史表都使用同一复合主键：

```sql
PRIMARY KEY (user_id, device_mac, time)
```

- `user_id`：JW 登录和首次绑定使用的 userID。SDK 不生成、不替换该值；登录
  成功的 session 通过 `JWWatchSession.historyScope` 将它带入历史写入和查询范围。
  不得在普通日志中打印它。
- 数据库文件由 `JWWatch.initialize()` 打开（默认应用支持目录下的
  `jw_watch.db`）。历史同步写入该库；宿主只需 `watch.historyStore` 或
  `session.historyStore` 配合 `historyScope` 查询，不必自行 `open()`。
- `device_mac`：当前 JW 对外连接使用的 MAC 地址，也是持久化设备标识；不另建
  deviceId 或设备表。
- `time`：UTC Unix 毫秒。连接、登录成功后 SDK 自动将终端时间同步给手表；
  因而健康记录时间与手机/PC 同时区，落库时统一转成 UTC 毫秒。

复合主键同时保证用户/设备隔离、重复同步幂等和按时间分页。例如：

```sql
SELECT time, heart_rate
FROM jw_heart_rate
WHERE user_id = :userId
  AND device_mac = :deviceMac
  AND time > :afterTime
ORDER BY time ASC
LIMIT :limit;
```

不使用自增 `id`，也不为上述主键再建重复索引。`time` 是唯一的分页游标：在
固定的 `user_id + device_mac` 范围内，它已处于唯一主键中。

写入使用事务。重复同步同一条业务记录时按主键覆盖（`INSERT OR REPLACE`）或
忽略（`INSERT OR IGNORE`）由对应记录的协议语义决定；不得生成第二条记录。

协议无效值不写入对应业务表：1 字节 `FF`、2 字节 `FFFF`、有符号 2 字节
`8000`，以及当前 JW 解码器明确判为无效的 `0`。一个同时携带多个指标的旧 JW
记录，只写入其中有效的指标。

## 3. 最终保留的表

### 3.1 活动桶 `jw_activity`

对应当前 JW `steps` 历史记录，以及 WS 所定义的 15 分钟活动桶。`time` 为桶
起点；`mode` 直接沿用 JW 的模式值。

```sql
CREATE TABLE jw_activity (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 桶起点，UTC Unix 毫秒
  steps INTEGER NOT NULL,            -- 步数
  distance INTEGER NOT NULL,         -- 距离，米；对应 JW distanceMeters
  energy INTEGER NOT NULL,           -- 能量，kcal；对应 JW energyCalories
  active_time INTEGER NOT NULL,      -- 活动时长，分钟；对应 JW activeMinutes
  mode INTEGER NOT NULL,             -- JW 活动模式
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.2 睡眠状态 `jw_sleep`

对应当前 JW `sleep` 历史记录。睡眠是状态变化序列，不预先合成为一条“睡眠报告”；
跨日区间由查询层按 `time` 和 `mode` 组合。保持现有字段名 `mode`。

```sql
CREATE TABLE jw_sleep (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 状态开始时刻，UTC Unix 毫秒
  mode INTEGER NOT NULL,             -- 当前 JW 睡眠模式
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.3 心率 `jw_heart_rate`

对应当前 JW `heartTemperature` 记录中的 `heartRateBpm`。表名和公开模型以心率
为业务含义；数据库字段不在名称中编码单位。

```sql
CREATE TABLE jw_heart_rate (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 测量时刻，UTC Unix 毫秒
  heart_rate INTEGER NOT NULL,       -- 心率，bpm；0/无效值不入库
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.4 血压 `jw_blood_pressure`

对应当前 JW `bloodPressure` 历史记录。只保存收缩压与舒张压；随附的
`heartRateBpm` 不属于血压核心数据，不落库。

```sql
CREATE TABLE jw_blood_pressure (
  user_id TEXT NOT NULL,                 -- JW userID
  device_mac TEXT NOT NULL,              -- 手表 MAC
  time INTEGER NOT NULL,                 -- 测量时刻，UTC Unix 毫秒
  systolic INTEGER NOT NULL,             -- 收缩压，mmHg；对应 systolicMmHg
  diastolic INTEGER NOT NULL,            -- 舒张压，mmHg；对应 diastolicMmHg
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.5 血氧 `jw_blood_oxygen`

对应当前 JW `bloodOxygen` 历史记录；保留当前 `percent`、`highPercent`、
`lowPercent` 的业务语义，但数据库字段不把百分比写进名称。

```sql
CREATE TABLE jw_blood_oxygen (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 测量时刻，UTC Unix 毫秒
  value INTEGER NOT NULL,            -- 当前血氧，百分比；对应 percent
  high INTEGER,                      -- 最高血氧，百分比；对应 highPercent；无值为 NULL
  low INTEGER,                       -- 最低血氧，百分比；对应 lowPercent；无值为 NULL
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.6 HRV `jw_hrv`

对应当前 JW `hrv` 历史记录。当前可靠业务值为 `sdnnMilliseconds`，不为尚未
实际下发的 sampleCount、flags 预留列。

```sql
CREATE TABLE jw_hrv (
  user_id TEXT NOT NULL,                 -- JW userID
  device_mac TEXT NOT NULL,              -- 手表 MAC
  time INTEGER NOT NULL,                 -- 测量时刻，UTC Unix 毫秒
  sdnn INTEGER NOT NULL,                 -- SDNN，毫秒；对应 sdnnMilliseconds
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.7 压力 `jw_pressure`

对应当前 JW `pressure` 历史记录。

```sql
CREATE TABLE jw_pressure (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 测量时刻，UTC Unix 毫秒
  value INTEGER NOT NULL,            -- 压力值
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.8 体温 `jw_temperature`

对应当前 JW `heartTemperature` 扩展记录中的温度字段。字段名称和含义严格沿用
当前 Flutter JW 解码结果：不改写为新的 body/skin 原始整数模型。字段名不携带
单位，单位在注释与公开模型文档中说明。

```sql
CREATE TABLE jw_temperature (
  user_id TEXT NOT NULL,                     -- JW userID
  device_mac TEXT NOT NULL,                  -- 手表 MAC
  time INTEGER NOT NULL,                     -- 测量时刻，UTC Unix 毫秒
  skin_temperature REAL NOT NULL,            -- 摄氏度；对应 skinTemperatureCelsius
  heat_stress INTEGER NOT NULL,              -- heatStress，JW 热应激等级
  worn INTEGER NOT NULL,                     -- worn：1=佩戴，0=未佩戴
  compensated INTEGER NOT NULL,              -- compensated：1=已补偿，0=未补偿
  PRIMARY KEY (user_id, device_mac, time)
);
```

若旧 JW 的同一记录同时给出有效 `heartRateBpm` 与温度，则分别写入
`jw_heart_rate` 和 `jw_temperature`，二者具有相同主键时间；这不是重复保存，
而是保留两个可独立查询的业务指标。

### 3.9 血糖 `jw_blood_glucose`

血糖是最终保留类型。当前 Flutter JW 历史协议尚无已验证的对应记录，因此本表
在协议和真机证据齐备前不对外宣称可用、不写入模拟数据。字段 `value` 延续 Android
JW SDK 的血糖存储语义：以 0.1 mmol/L 的整数保存。

```sql
CREATE TABLE jw_blood_glucose (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 测量时刻，UTC Unix 毫秒
  value INTEGER NOT NULL,            -- 血糖值，0.1 mmol/L
  PRIMARY KEY (user_id, device_mac, time)
);
```

### 3.10 运动记录 `jw_sport`

对应当前 JW `exercise` 历史记录。运动与其他类型一样按 `user_id + device_mac +
time` 作为唯一事实，不因 WS 新协议有 `sport_id` 而改变主键。所有字段沿用当前
JW 解析名称和单位。

```sql
CREATE TABLE jw_sport (
  user_id TEXT NOT NULL,             -- JW userID
  device_mac TEXT NOT NULL,          -- 手表 MAC
  time INTEGER NOT NULL,             -- 运动记录时刻，UTC Unix 毫秒
  mode INTEGER NOT NULL,             -- mode，运动模式
  duration INTEGER NOT NULL,         -- 运动持续时长，秒；由 durationMinutes/Seconds 合成
  pause_count INTEGER NOT NULL,      -- pauseCount，暂停次数
  pause_duration INTEGER NOT NULL,   -- 暂停时长，秒；由 pauseMinutes/Seconds 合成
  steps INTEGER NOT NULL,            -- 步数
  distance INTEGER NOT NULL,         -- distanceMeters，距离（米）
  energy INTEGER NOT NULL,           -- energyCalories，能量（kcal）
  heart_rate_max INTEGER,            -- heartRateMax，bpm；无效时为 NULL
  heart_rate_average INTEGER,        -- heartRateAverage，bpm；无效时为 NULL
  heart_rate_min INTEGER,            -- heartRateMin，bpm；无效时为 NULL
  PRIMARY KEY (user_id, device_mac, time)
);
```

## 4. 实施和兼容约束

1. 初始数据库文件固定为 `jw_watch.db`，独立 schema version 与 migration；不得
   打开、升级或重建 `ws_watch.db`。
2. SDK 的公开查询接口必须要求 `userID` 与 `deviceMac`；不得提供默认用户或
   跨设备的模糊查询。
3. 这是全新的 JW 数据库，不读取、迁移或兼容旧 Flutter journal、旧数据库或 WS
   数据库；旧存储资产不属于本 SDK 的运行时依赖。
4. 当前 JW 真机已能证明的类型先完成表、模型、decoder 映射、查询和测试；血糖等
   尚无协议证据的类型保持“目标已定义、功能未实现”。
5. Drift 仅是 Dart/Flutter 中定义 SQLite 表、生成类型化 DAO 与执行 schema
   migration 的工具，等价于 Android 侧的 Room/GreenDAO；它不要求自增主键，也
   不决定时间查询或分页方式。
