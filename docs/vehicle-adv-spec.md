# 仪表 BLE 广播规范（ADV_IND + SCAN_RSP）

版本 1.0 | 2026-11-10

## 1. 目的

Dashboard 的「+ 连接」在没有二维码的情况下靠 BLE 广播发现仪表。为了在 31 字节的
legacy 广播预算内同时满足「可过滤」和「可读」，广播拆成两包：

- **ADV_IND**：只放过滤标识 —— HMIS 服务 UUID（128 位）+ Realtek 厂商数据
- **SCAN_RSP**：放设备名与可选信息（设备名不进广播包）

App 侧实现见 `android/mapfeature/src/main/java/com/example/map1/VehicleAdvFilter.kt`
与 `AddBleDeviceActivity.kt`。

---

## 2. ADV_IND（31 B，可连接）

| # | AD 结构 | 字节 | 长度 |
|---|---------|------|------|
| 1 | Flags (0x01) | `02 01 06` | 3 B |
| 2 | Complete List of 128-bit Service UUIDs (0x07) | `11 07` + 16 B UUID | 18 B |
| 3 | Manufacturer Specific Data (0xFF) | `09 FF 5D 00` + 6 B 载荷 | 10 B |

合计 31 B，无剩余空间。

### 2.1 HMIS 服务 UUID

```
484D4953-0000-1000-8000-00805F9B34FB
```

空口按 **整段小端**排列：

```
FB 34 9B 5F 80 00 00 80 00 10 00 00 53 49 4D 48
```

自检：末尾 `53 49 4D 48` 倒读即 ASCII `"HMIS"`。

### 2.2 完整示例

```
02 01 06                                             Flags
11 07 FB 34 9B 5F 80 00 00 80 00 10 00 00 53 49 4D 48 HMIS UUID
09 FF 5D 00 01 01 03 5A 12 34                        Realtek 厂商数据
```

`0x005D` 是 Bluetooth SIG 分配给 Realtek Semiconductor 的 Company ID，空口小端写作
`5D 00`。

### 2.3 厂商载荷（6 B）

| 偏移 | 字段 | 说明 |
|------|------|------|
| 0 | 载荷版本 | 固定 `0x01`；格式升级时递增，App 只解析已知版本 |
| 1 | 型号码 | `01`=RTL8773G，`02`=RTL8773E，`03`=RTL8782 |
| 2 | 能力位 | bit0 可投屏，bit1 已绑定，bit2 充电中，bit3-7 保留填 0 |
| 3 | 电量 | 0–100，`0xFF` 表示未知 |
| 4–5 | 短 ID | SN 低 16 位，大端；用于列表二次核对 |

字段变化频率限制：电量等易变字段建议 ≤ 30 s 更新一次。每次载荷变化都会让 Android
重新上报一次广播，App 虽按 MAC 去重，但会增加射频与唤醒开销。

---

## 3. SCAN_RSP（≤ 31 B）

| # | AD 结构 | 字节 | 长度 |
|---|---------|------|------|
| 1 | Complete Local Name (0x09) | `0E 09` + `RTL8773G-8A2F` | 15 B |
| 2 | Service Data 16-bit (0x16) | `05 16 C0 00 01 02` | 6 B |
| 3 | Tx Power Level (0x0A) | `02 0A F4`（−12 dBm） | 3 B |

合计 24 B，余 7 B 预留。

设备名建议定长 13 字符：`<型号码>-<MAC 后 4 位>`，例如 `RTL8773G-8A2F`。名称必须
放在 SCAN_RSP 里，因为 ADV_IND 已无空余字节。

---

## 4. 射频与连接参数要求

| 项目 | 要求 | 原因 |
|------|------|------|
| 广播类型 | `ADV_IND`（可连接、非定向） | `ADV_SCAN_IND` / `ADV_NONCONN_IND` 无法直连 |
| 地址类型 | Public 或 Static Random，**不可用 RPA** | 二维码里存固定 MAC，RPA 轮换会导致扫码建连失败、列表重复 |
| 广播间隔 | 前 30 s 100–150 ms，之后 300–500 ms | 发现速度与功耗折中；未连接时不要超过 1 s |
| 扫描响应 | 必须响应 `SCAN_REQ` | 设备名只存在于 SCAN_RSP；Android 默认主动扫描 |
| 扩展广播 | 不使用，保持 legacy（每包 ≤ 31 B） | App 扫描参数为默认 `legacy = true`，扩展包收不到 |
| Tx Power | ADV 里不放，放 SCAN_RSP 的 `0x0A` | 节省 ADV 空间 |

## 5. GATT 侧约束（连接后校验）

广播只负责发现，连接后 App 会校验以下内容，缺任何一项都会进入错误态并断开：

- HMIS 服务 `484D4953-0000-1000-8000-00805F9B34FB`
- `0xFFC1`（Write / Write No Rsp）
- `0xFFC2`（Notify，需带 CCCD）
- MTU 协商 512（失败会退回 23 继续，不阻断）

导航投屏的 GATT 细节见 `docs/navi_projection_ble.md`。

---

## 6. 验收清单

1. nRF Connect 查看 ADV：包含 `0x07`（128 位 UUID）与 `0xFF` 且 Company ID 为 `0x005D`
2. 查看 SCAN_RSP：包含 `0x09` 完整设备名
3. App 首页点「+ 连接」：列表出现该设备，徽标为「HMIS 服务 UUID」，副行显示型号 / 电量
4. 停发 SCAN_RSP 再试：设备仍在列表，标题退化为「型号 · MAC 后 4 位」，不出现空白行
5. 点「连接」：首页状态行依次变为「正在连接」→「已连接」，可进入投屏
6. 打开「显示全部」：能看到原始 ADV 十六进制，用于核对字段
