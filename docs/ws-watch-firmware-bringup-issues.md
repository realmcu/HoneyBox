# WS 真机联调：固件与规范差异记录

> **用途**：记录 `hmi-watch-360` + WS Flutter SDK 联调时确认的**固件侧问题**与临时对策。  
> **对照规范**：[HoneyProtocol](https://realmcu.github.io/HoneyProtocol/)（L0 NUS、L1/L2）  
> **状态**：持续更新；修固件后在本表标记关闭并删掉 SDK 权宜逻辑。

---

## 1. 广播 / 扫描（GAP）— Scan Response 仍是老 JW 服务

### 现象

- 系统蓝牙、全量 BLE 扫描能看到名为 **Watch** 的设备。
- 用 **NUS `6e400001` 做 `withServices` 硬件过滤**时扫不到（空中没有该 UUID）。
- **JW SDK** 按 `000001ff` / `fd50` 规则能把同一台表扫进列表，容易误判为老款 JW 设备。

### 根因（固件）

连接后的 GATT 已注册 **Nordic UART（Honey L0）**，但 **GAP 广告未同步更新**，仍沿用 Realtek 老款模板。

| 层级 | UUID / 内容 | 代码位置 |
|------|-------------|----------|
| **连接后 GATT 主服务（Honey/WS 应用协议入口）** | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` | `applications/app/app_bluetooth/hmi_ble/private_service/nordic_uart_service.c` |
| 写特征（手机 → 表） | `6e400002-…` | 同上（NUS RX） |
| Notify 特征（表 → 手机） | `6e400003-…` | 同上（NUS TX） |
| **Adv 包** | 名 `Watch`，16-bit `0xFEE7`，厂商 `0xFEC5` + 6B MAC | `hmi_ble_gap_init.c` → `adv_data[]` |
| **Scan Response** | 128-bit **`000001ff-3c17-d293-8e48-14fe2e4da212`（与 JW `WRISTBAND_SERVICE_UUID` 相同）** | `hmi_ble_gap_init.c` → `GATT_UUID128_BWPS_ADV` / `scan_rsp_data[]` |

**结论**：不是「新协议也用 `01ff` 跑 Honey」，而是 **广播里还写着老 JW 的 `01ff`，连接后才是 `6e400001` NUS**。  
JW 侧 `WristbandManager` 的 `01ff` + `fd50` **只描述老款 JW**；本表 Watch 联调样机的 **应用协议服务是 NUS，不是 `01ff`**。

### 期望（固件修改）

1. **Scan Response（或 Adv）中改为广播 NUS 主服务** `6e400001-…`，**去掉** Scan Response 里的 `GATT_UUID128_BWPS_ADV`（`01ff`），避免 JW/WS 扫描混用。
2. 若需保留 Realtek 厂商字段 / `0xFEE7`，可与 NUS UUID 并存；关键是 **不要再播 `01ff`**（除非设备仍要兼容 JW 客户端，且应作为单独 SKU/模式明确区分）。
3. 修改后：WS SDK 可用 `withServices: [6e400001]` 扫描；JW SDK 不应再看到纯 Honey 样机。

### SDK 临时对策（修固件前）

- WS：**全量扫描** + 软件识别 `Watch` / `FEE7` / `FEC5`（见 `ws_ble_profile.dart` → `isWSCandidate`）。
- JW：若识别为 Honey WS 广播特征，**不进 JW 列表**（避免扫到同一台 Watch）。

---

## 2. L1 帧 byte1 bit6（ACK 语义）— 与 HoneyProtocol / HL 不一致

### 现象

- 手机 WS SDK 按 **JW/Android 默认**发出站数据帧：`AB 00 …`（byte1 = `0x00`）。
- 日志只有 `WIRE tx`，**无 `WIRE rx` L1 ACK**，约 5s 超时重发。
- 将出站 byte1 改为 **`0x40`（bit6 置位）** 后，固件开始回 **`AB 10 …` / `AB 30 …` ACK**（联调验证行为，非最终规范方案）。

### 根因（固件 vs 规范）

| 来源 | byte1 bit6 含义 |
|------|-----------------|
| **HL 私有协议 / JW Android** | 字段名 **Data no_ack**：`1` = **不要求** ACK，**默认 `0` = 要求 ACK**（见 `HL_Private_Protocol.md` L1 header 表） |
| **HoneyProtocol L1（现行 rst）** | byte1 **[7:6] 为 Reserve**，**未定义** no_ack / ack_request（见 `HoneyProtocol/docs/architecture.rst` L1 Header） |
| **`hmi-watch-360/protocol/hmi_proto.c`** | 实现 **`PROTO_FLAG_ACK_REQUEST (1<<6)`**：**仅当 bit6=1** 才对入站**数据帧**调用 `proto_send_ack`；bit6=0 **不回 ACK** |

即：当前 Realtek 实现在 bit6 上使用了「**ack_request**」语义，且 **与 HL 的 no_ack 极性相反**，也与 **HoneyProtocol 已删除 bit6 语义**不一致。

相关代码：

- 设备：`hmi-watch-360/protocol/hmi_proto.c`（`PROTO_FLAG_ACK_REQUEST`、`proto_send_ack`）
- 手机临时：`HoneyBox/packages/watch_frame_channel` → `WatchFrameProfile.ws` 出站 `byte1=0x40`

### 期望（固件修改，择一并对齐文档）

1. **推荐（对齐 HoneyProtocol）**：删除 bit6 分支；**所有合法入站数据帧**（非 ACK 包）在 CRC 通过后**一律回 Success ACK**（与 `architecture.rst` ACK 机制描述一致）。手机恢复出站 `AB 00 …`。
2. **若必须保留 bit6**：在 HoneyProtocol 中**正式定义** bit6 名称与极性，且与 `hmi_proto.c`、Flutter `watch_frame_channel`、JW 迁移说明**同一套**；不得与 HL `no_ack` 混用而不同极性。

### SDK 临时对策（修固件前）

- WS profile 出站数据帧 **byte1 = `0x40`**（`WatchFrameProfile.ws.outboundDataUsesAckRequestBit`）。
- JW profile 不变（`0x00` + HL no_ack 语义）。

---

## 3. SDK 侧：失败可见性与会话恢复（2026-11-11 已修）

### 现象

- 绑定只打出 `API→` 与多次 `WIRE tx`，**没有** `API← … FAILED`。
- UI 停在 `loggingIn`，像「没有超时、没有失败回调」。

### 原因（机制其实有，日志与状态没收尾）

| 层 | 行为 |
|----|------|
| **L1** | `ackTimeout=5s`，`maxRetries=3` → **最多 4 次**同 seq 发送（首包 + 3 次重试），约 **20s** 后抛 `WSErrorCode.ackTimeout`。 |
| **L2 `replyTimeout`** | 仅在 **L1 `outbound.completed` 成功之后** 才等业务 `0x03/0x02` 等回包。固件不回 L1 ACK 时走不到这一步。 |
| **日志** | 旧版对 `WSException` **不打** `API←`，JW 的 `JWLink` 会对所有失败打 `failed …`。 |
| **Session** | `bindFirstTime` / `login` 进入 `loggingIn` 后若抛错，**未**回到 `connected` + `error`，Demo 一直像「绑定中」。 |

### 期望（任意 `0x03` Key，不绑死登录/绑定流程）

1. 发命令 → L1 ACK →（若要回应）等 L2 → 成功/业务拒绝/超时，均有 **明确失败** 抛给调用方。
2. 固件异常时：**有限重试 → 失败回调 → 会话可继续**（例如回到 `connected`），而不是假死。
3. Logcat 过滤 `WSWatchSDK` 应能看到：`WIRE tx retry …`、**`API← WSLink.request FAILED code=ackTimeout …`**。

---

## 4. 其它联调项（简要，后续可拆 issue）

| 项 | 现象 / 状态 | 备注 |
|----|-------------|------|
| 绑定 / 登录 L2 | 固件侧绑定处理以 **`0x03` Key `0x01`** 为主；**登录 `0x03` 待实现** | Demo 真机走 **首次绑定**，勿点登录 |
| 对时 / 设置 L2 | Honey `0x02` 与固件 `hmi_l2_cmd_settings.c` payload 长度/字段可能不一致 | 绑定通过后再逐项对 |
| OTA 模式广播 | `app_ota_mode` 下 Adv 为 DFU 包，与正常 `Watch` 不同 | 联调时确认非 OTA 模式 |

---

## 5. 参考：JW vs WS 服务 UUID（避免混淆）

| | 老款 JW（`WristbandManager`） | Honey WS 样机（连接后 GATT） |
|--|------------------------------|------------------------------|
| 主服务 | `000001ff-3c17-d293-8e48-14fe2e4da212` | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` |
| 扫描常用 | 同上 + `0000fd50-…` | **当前错误地仍在 Scan Response 播 `01ff`**；应播 `6e400001` |
| 写 / Notify 特征 | `ff02` / `ff03`（短 UUID） | `6e400002` / `6e400003` |

`6e400001` 是 **GATT Primary Service**，不是特征 UUID。

---

## 6. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-11-11 | 初版：GAP 老 `01ff` 广播、L1 bit6 ACK 与 Honey/HL 不一致；记录 SDK 临时策略 |
| 2026-11-11 | §3：SDK 失败日志、`loggingIn` 恢复；NUS/HMI 管道未通仅固件记录，不阻塞 SDK 超时语义 |
