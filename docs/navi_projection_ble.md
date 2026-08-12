# 导航投屏 BLE 传图协议

版本 1.0 | 2026-08-05

## 1. 概述

本协议在 BLE GATT 上传输导航画面（JPEG 帧），用于在仪表盘 / 车载屏幕等 BLE 设备上显示实时导航投屏画面。

通过独立的 GATT Service（FFD0）承载，控制与数据分离：控制消息走带校验的可靠通道，数据帧走高吞吐通道。

---

## 2. GATT Profile

### 2.1 Service

```
UUID: 0000FFD0-0000-1000-8000-00805F9B34FB
```

### 2.2 Characteristics

| 特征 | UUID | 属性 | 方向 | 封装 |
|------|------|------|------|------|
| NAVI_CTRL_TX | `0000FFD1-...` | Write | App → Dev | L1 (0xAB头 + CRC16 + seq + ACK) |
| NAVI_CTRL_RX | `0000FFD2-...` | Notify | Dev → App | L1 |
| NAVI_DATA_TX | `0000FFD3-...` | Write Without Response | App → Dev | 裸 L2 |
| NAVI_DATA_RX | `0000FFD4-...` | Notify | Dev → App | 裸 L2 |

- **控制通道** (FFD1/FFD2): 承载 OPEN / ACK / CLOSE / ERROR。L1 封装，带 CRC16 校验和 ACK 确认。
- **数据通道** (FFD3/FFD4): 承载 FRAME chunk / CREDIT / REPORT。裸 L2，靠 credit flow control 和 gap retransmission 保证可靠性。

### 2.3 与现有 BLE 通道的关系

独立于现有通道，互不干扰：

| 通道对 | CMD | 用途 |
|--------|-----|------|
| FFC1/FFC2 | 0x0D, 0x10 | 命令：WiFi配网、文件传输 |
| FFC4/FFC5 | 0x0E | 流媒体：摄像头推流 |
| **FFD1/FFD2** | **0x11** | **导航投屏 — 控制** |
| **FFD3/FFD4** | **0x11** | **导航投屏 — 数据** |

所有 GATT write 共享串行写队列，逐条发出。

---

## 3. L1 帧格式 (控制通道)

控制通道（FFD1/FFD2）所有消息均经 L1 封装：

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬─────────────┐
│ 0xAB │ ctrl │ len_h│ len_l│crc_h │crc_l │seq_h │seq_l │  payload    │
│  1B  │  1B  │  2B (big-endian) │  2B (big-endian) │  2B (big-endian) │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴─────────────┘
```

| 字段 | 长度 | 说明 |
|------|------|------|
| 0xAB | 1B | 帧同步字节 |
| ctrl | 1B | 0x00=DATA, 0x10=ACK, 0x30=ERROR(NAK) |
| len | 2B BE | payload 字节数（不含 8 字节头） |
| crc | 2B BE | CRC-16/ARC (poly=0x8005, init=0x0000, reflected)，**仅覆盖 payload** |
| seq | 2B BE | L1 帧序号，0-65535 轮转 |

**CRC 自检向量**: `crc16("123456789") == 0xBB3D`

**设备端职责：**
1. 收到完整 L1 DATA 帧 → 发送 ACK(ctrl=0x10, 原 seq)
2. CRC 校验失败 → 发送 ERROR(ctrl=0x30, 原 seq)
3. 维护接收缓冲区，按 0xAB + len 拼帧（L1 帧可能跨多个 BLE notification chunk）

---

## 4. L2 协议

CMD: `0x11`

### 4.1 L2 帧格式

控制通道（经 L1 解帧后）和数据通道（直接在 FFD4 notify 中）均使用统一的 L2 帧：

```
┌──────┬──────┬──────┬──────┬──────┬─────────────┐
│ cmd  │ 0x00 │ key  │vlen_h│vlen_l│  value      │
│ 1B   │ 1B   │ 1B   │  2B (big-endian)  │  vlen bytes │
└──────┴──────┴──────┴──────┴──────┴─────────────┘
```

| 字段 | 长度 | 说明 |
|------|------|------|
| cmd | 1B | 固定 0x11 |
| 0x00 | 1B | 保留 |
| key | 1B | 子命令（见下表） |
| vlen | 2B BE | value 长度 |
| value | vlen | 子命令 payload |

### 4.2 子命令一览

| key | 名称 | 通道 | 方向 | 说明 |
|-----|------|------|------|------|
| 0x01 | OPEN | 控制 | App→Dev | 握手请求：分辨率/帧率/质量 |
| 0x02 | ACK | 控制 | Dev→App | 握手应答：结果/max_chunk/初始credit |
| 0x03 | CLOSE | 控制 | App→Dev | 停止投屏 |
| 0x04 | ERROR | 控制 | Dev→App | 设备异常报告 |
| 0x05 | FRAME | 数据 | App→Dev | JPEG 帧数据块（消耗 1 credit） |
| 0x06 | CREDIT | 数据 | Dev→App | 信用补充 |
| 0x07 | REPORT | 数据 | Dev→App | 缺口报告（请求重传） |

---

## 5. 子命令详细格式

### 5.1 OPEN (key=0x01)

**方向**: App → Dev（控制通道，经 L1 封装）

```
Value (7 bytes):
┌──────┬──────┬──────┬──────┬─────┬───────┬───────┐
│ w_lo │ w_hi │ h_lo │ h_hi │ fps │ qual  │ flags │
│  u8  │  u8  │  u8  │  u8  │ u8  │  u8   │  u8   │
└──────┴──────┴──────┴──────┴─────┴───────┴───────┘
```

| 字段 | 格式 | 说明 |
|------|------|------|
| w | u16 LE | 投屏宽度（典型 400） |
| h | u16 LE | 投屏高度（典型 480） |
| fps | u8 | 目标帧率 1-30（典型 5） |
| qual | u8 | JPEG 质量 10-100（典型 60） |
| flags | u8 | bit 0 = flow_ctrl_enable（**必须为 1**） |

**典型 OPEN payload**: `90 01 E0 01 05 3C 01` (400×480, 5fps, quality=60, flow_on)

**设备端收到 OPEN 后：**
1. 校验参数（分辨率、帧率是否支持）
2. 分配 JPEG 解码器 + 环形帧缓冲（≥3 帧容量）
3. 回复 ACK

### 5.2 ACK (key=0x02)

**方向**: Dev → App（控制通道）

```
Value (5 bytes):
┌────────┬───────────┬───────────┬───────────┬───────────┐
│ result │ max_chunk_lo│ max_chunk_hi│ credit_lo │ credit_hi │
│  u8    │    u16 LE      │    u16 LE      │
└────────┴───────────┴───────────┴───────────┴───────────┘
```

| 字段 | 格式 | 说明 |
|------|------|------|
| result | u8 | 见结果码表 |
| max_chunk | u16 LE | 设备接受每 chunk 最大数据字节数（典型 480） |
| credit | u16 LE | 初始信用数（**必须为有限值，不允许 0xFFFF**） |

**结果码：**

| 值 | 含义 |
|---|------|
| 0x00 | OK |
| 0x01 | Busy（设备忙） |
| 0x02 | Unsupported（参数不支持） |
| 0x03 | Decoder error（解码器错误） |
| 0x04 | Low memory（内存不足） |

**credit 建议值**: `ceil(expected_max_jpeg_size / max_chunk) × 3`

**典型 ACK (OK)**: `00 E0 01 2D 00` (OK, max_chunk=480, credit=45)

**典型 ACK (Reject)**: `01 00 00 00 00` (Busy)

### 5.3 CLOSE (key=0x03)

**方向**: App → Dev（控制通道）

```
Value (1 byte):
┌────────┐
│ reason │
│  u8    │
└────────┘
```

| 值 | 含义 |
|---|------|
| 0x00 | Normal（正常结束） |
| 0x01 | User cancel（用户取消） |
| 0x02 | Credit timeout（信用超时） |
| 0x03 | Encode error（编码错误） |

设备收到 CLOSE 后立即释放解码器和帧缓冲，不需回复。

### 5.4 ERROR (key=0x04)

**方向**: Dev → App（控制通道）

```
Value (2 bytes):
┌────────────┬───────────┐
│ error_code │ frame_seq │
│    u8      │    u8     │
└────────────┴───────────┘
```

| error_code | 含义 |
|-----------|------|
| 0x01 | Buffer overflow（缓冲溢出） |
| 0x02 | Decode failed（解码失败） |
| 0x03 | Timeout（超时） |
| 0x04 | Unexpected frame（非预期的帧序号） |

### 5.5 FRAME (key=0x05)

**方向**: App → Dev（数据通道 FFD3）

```
Value (8 + N bytes):
┌───────────┬───────────┬───────────┬───────────┬──────────┐
│ frame_seq │chunk_offset│ total_len │   data    │
│ u16 BE    │  u24 BE    │  u24 BE   │  N bytes  │
└───────────┴───────────┴───────────┴───────────┴──────────┘
```

| 字段 | 格式 | 说明 |
|------|------|------|
| frame_seq | u16 BE | 帧序号，每帧递增，0-65535 轮转 |
| chunk_offset | u24 BE | 本块在完整 JPEG 中的起始偏移，0-based |
| total_len | u24 BE | 完整 JPEG 帧总字节数 |
| data | N bytes | JPEG 数据，N ≤ max_chunk |

**每发送一个 FRAME chunk，消费 1 credit。** 同一帧的多个 chunk 各自消费 1 credit。

**示例：一帧 4896 字节 JPEG，max_chunk=480，分 11 片：**

```
Chunk 0:  frame_seq=0, offset=0,    total=4896, data[480]
Chunk 1:  frame_seq=0, offset=480,  total=4896, data[480]
Chunk 2:  frame_seq=0, offset=960,  total=4896, data[480]
...
Chunk 10: frame_seq=0, offset=4800, total=4896, data[96]
```

同一帧所有 chunk 共享 `frame_seq`；App 一帧所有 chunk 发完后将 seq 递增。

### 5.6 CREDIT (key=0x06)

**方向**: Dev → App（数据通道 FFD4）

```
Value (2 bytes):
┌───────────┬───────────┐
│ credit_hi │ credit_lo │
│  u16 BE               │
└───────────┴───────────┘
```

设备每当帧缓冲区有空间释放时，向 App 补充 credit。

**补充策略：**
- 每完整接收并解码一帧 → 释放该帧占用的缓冲 → 补充该帧消耗的 credit 数量
- 可逐帧释放，也可批量补充（不影响协议正确性）
- 建议在帧完成后立即补充，避免 App 侧进入 credit 等待

### 5.7 REPORT (key=0x07)

**方向**: Dev → App（数据通道 FFD4）

```
Value (3 + 6×N bytes):
┌───────────┬───────────┬────────────────────────────────┐
│ frame_seq │ gap_count │  gaps (6×N bytes)              │
│ u16 BE    │    u8     │ [gap_start_24, gap_end_24] × N │
└───────────┴───────────┴────────────────────────────────┘
```

每个 gap 结构 (6 bytes)：

```
┌──────┬──────┬──────┬──────┬──────┬──────┐
│ gs_hi│gs_mid│gs_lo │ge_hi │ge_mid│ge_lo │
│     u24 BE (gap_start)     │     u24 BE (gap_end)     │
└──────┴──────┴──────┴──────┴──────┴──────┘
```

- `frame_seq`: 缺口所属帧序号
- `gap_count`: 缺口数量。**0 表示该帧已完整接收，App 可释放 retx buffer。**
- 每个缺口 `[gap_start, gap_end)`: 缺失的字节偏移范围（左闭右开）

**设备端 REPORT 发送策略：**

1. 维护每帧的已到达区间列表，收到 chunk 时更新
2. 收到某帧 `chunk_offset + data.length >= total_len` → 帧结束，计算覆盖缺口
3. 也可定时扫描未完成的帧（100-200ms 周期）
4. 最多保留最近 **3 帧**的缺口检测，超出 3 帧的丢弃
5. 帧完整无缺口 → 发送 `REPORT gap_count=0` → App 释放 retx buffer
6. 帧有缺口 → 发送 REPORT 带缺口列表 → App 重传缺失 chunk（**不消耗 credit**）

---

## 6. 设备端状态机

```
                    ┌──────────┐
                    │   IDLE   │
                    │ 无活跃会话 │
                    └────┬─────┘
                         │ 收到 OPEN
                         ▼
                    ┌──────────┐
                    │VALIDATING│
                    │校验参数   │
                    └──┬───┬───┘
              参数OK  │   │ 参数不支持 / 无资源
                       ▼   ▼
                ┌────────┐ ┌────────────┐
                │ 发送ACK │ │ 发送 ACK   │
                │ (OK+   │ │ (result≠0) │
                │ credit) │ │ → 回 IDLE  │
                └───┬────┘ └────────────┘
                    │
                    ▼
   ┌────────────────────────────────────┐
   │              ACTIVE                │
   │                                    │
   │  接收 FRAME chunks                 │
   │  ├─ 按 (seq, offset) 拼帧          │
   │  ├─ 帧完整 → JPEG解码 → 显示       │
   │  ├─ 释放缓冲 → 发送 CREDIT         │
   │  └─ 检测缺口 → 发送 REPORT         │
   │                                    │
   │  收到 CLOSE / 异常 → IDLE          │
   └────────────────────────────────────┘
```

---

## 7. 环形帧缓冲建议

```
Buffer size = max_jpeg_bytes × 3

Frame slots: [slot 0] [slot 1] [slot 2]
              ↑ oldest      ↑ current

每个 slot:
  - frame_seq:     u16
  - total_len:     u24
  - received:      区间合并列表（已到达的 [start, end) 区间）
  - jpeg_buffer:   拼帧缓冲区（total_len 字节）
  - complete:      bool
```

收到 FRAME chunk 时：
1. `frame_seq` 匹配当前或最近 3 帧之一 → 写入对应 slot
2. `frame_seq` 落后太多（差距 > 3 且非重传目标） → 忽略
3. 更新该 slot 的 `received` 区间
4. 检测 `received` 是否连续覆盖 `[0, total_len)` → complete
5. complete → JPEG 解码 → 显示 → 发送 CREDIT + `REPORT gap_count=0` → slot 标记可复用

---

## 8. 错误处理

| 场景 | 设备行为 |
|------|---------|
| 收到不支持的 OPEN 参数 | ACK result≠0，回 IDLE |
| OPEN 后 5s 无 FRAME | 发送 ERROR(0x03, timeout) → 释放资源 → IDLE |
| 3 个 slot 都未完成且收到新帧 chunk | 发送 ERROR(0x01, buffer_overflow) → 释放最旧 slot → 继续 |
| JPEG 解码失败 | 发送 ERROR(0x02, decode_failed) → 丢弃该帧 → 发送 CREDIT |
| 收到未知 frame_seq（跳号 > 3） | 忽略，不 report |
| FFD2 L1 CRC 校验失败 | 发送 L1 ERROR (ctrl=0x30) |
| BLE 连接断开 | 释放所有资源 → IDLE |

---

## 9. 完整交互时序

```
App                                      Device
 │                                         │
 │── OPEN (w=400,h=480,fps=5,q=60) ──────→│  (FFD1, L1)
 │←── L1 ACK ────────────────────────────│  (FFD2, L1)
 │←── NAVI_ACK (OK, chunk=480,c=45) ────│  (FFD2, L1)
 │                                         │
 │── FRAME seq=0 off=0    [480B] ────────→│  (FFD3, c→44)
 │── FRAME seq=0 off=480  [480B] ────────→│  (FFD3, c→43)
 │── FRAME seq=0 off=960  [480B] ────────→│  (c→42)
 │    ...                                  │
 │── FRAME seq=0 off=4800 [96B]  ────────→│  (c→34) ← 帧完整
 │                                         │  解码 → 显示
 │←── CREDIT +11 ────────────────────────│  (FFD4, c→45)
 │←── REPORT seq=0 gap_count=0 ─────────│  (FFD4, 释放 retx)
 │                                         │
 │── FRAME seq=1 off=0    [480B] ────────→│
 │── FRAME seq=1 off=480  [480B] ────────→│  ← 本片丢包
 │── FRAME seq=1 off=960  [480B] ────────→│
 │    ...                                  │
 │── FRAME seq=1 off=4800 [96B]  ────────→│  帧结束, 检测到缺口 [480,960)
 │←── REPORT seq=1 gap=1 [480,960) ─────│  (FFD4)
 │── FRAME seq=1 off=480  [480B] ────────→│  (重传, 不消耗 credit)
 │←── REPORT seq=1 gap_count=0 ─────────│  完整确认
 │←── CREDIT +10 ───────────────────────│
 │    ...                                  │
 │                                         │
 │── CLOSE (reason=0x00) ────────────────→│  (FFD1, L1)
 │                                         │  释放所有资源
```
