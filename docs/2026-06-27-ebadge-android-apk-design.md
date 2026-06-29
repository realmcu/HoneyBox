# eBadge BLE Android APK 设计文档

**日期：** 2026-06-27  
**参考：** `miniprogram/`（微信小程序源码，BLE 协议层已验证）  
**技术栈：** Flutter 3.x + Riverpod + flutter_blue_plus  
**主题：** Material Design 3 浅色轻量风格  

---

## 1. 整体架构

### 1.1 目录结构

```
ebadge_app/
├── lib/
│   ├── main.dart                      # App 入口，ProviderScope
│   ├── app.dart                       # MaterialApp 配置（主题/路由）
│   │
│   ├── providers/
│   │   ├── ble_provider.dart          # BLE 状态：扫描/连接/写队列
│   │   └── transfer_provider.dart     # 文件传输状态：进度/错误
│   │
│   ├── services/                      # 纯 Dart 协议层
│   │   ├── l1_engine.dart             # L1 帧协议：CRC16/帧构造/流式解析/ACK
│   │   ├── l2_file_transfer.dart      # L2 文件传输：CRC32/状态机
│   │   └── ble_manager.dart           # BLE 连接管理
│   │
│   ├── pages/
│   │   ├── scan/
│   │   │   ├── scan_page.dart
│   │   │   └── widgets/device_tile.dart
│   │   ├── device/
│   │   │   ├── device_page.dart
│   │   │   └── widgets/action_card.dart
│   │   ├── image/
│   │   │   ├── image_page.dart
│   │   │   └── widgets/progress_widget.dart
│   │   ├── danmaku/danmaku_page.dart
│   │   ├── gif/gif_page.dart
│   │   ├── video/video_page.dart
│   │   └── stream/stream_page.dart
│   │
│   └── theme/
│       └── app_theme.dart
│
├── android/
├── pubspec.yaml
└── README.md
```

**分层原则：**
- `services/` — 纯 Dart，零 Flutter 依赖，直接移植 miniprogram 已验证的 L1/L2 协议逻辑
- `providers/` — Riverpod 状态管理，桥接 services 和 pages
- `pages/` — Flutter Widget，只依赖 providers，不直接操作 BLE

### 1.2 数据流

```
用户操作
    │
    ▼
Riverpod Provider（状态变更 → UI 自动重建）
    │
    ▼
BleManager（封装 flutter_blue_plus）
    │
    ├─▶ L1Engine（sendL2 / onNotified）
    │       CRC16 / 分片 / ACK / 停等
    │
    └─▶ FileTransferSession
            BEGIN→DATA→END 状态机 / CRC32 / 超时
```

**接收方向：**
```
FlutterBluePlus.onCharacteristicChanged
    └─→ BleManager._onNotify(data)
            └─→ L1Engine.onNotified(data)
                    └─→ session.onL2Frame(raw)
```

**发送方向：**
```
Page（选图/输入/推流）
    └─→ session.send(fileType, buffer, filename)
            └─→ L1Engine.sendL2(l2Frame)
                    └─→ BleManager.write(chunk) → 串行队列 → 蓝牙写入
```

### 1.3 Provider 设计

```dart
// BLE 全局状态
@riverpod
class BleNotifier extends _$BleNotifier {
  // state = AsyncValue<BleState>
  // BleState: { disconnected, scanning, connecting, connected }
  // 方法：startScan(), stopScan(), connect(id), disconnect()
}

// 当前连接设备
@riverpod
class ConnectedDevice extends _$ConnectedDevice {
  // state = (deviceId, name, mtu)?
}

// 文件传输进度
@riverpod
class TransferProgress extends _$TransferProgress {
  // state = { status, progress%, speedKB/s, errorMsg? }
  // status: { idle, sending, done, error }
}
```

**页面 ↔ Provider 关系：**

| 页面 | Provider | 操作 |
|------|----------|------|
| ScanPage | BleNotifier | startScan(), connect() |
| DevicePage | ConnectedDevice | disconnect() |
| ImagePage | TransferProgress | session.send(TYPE.IMAGE, ...) |
| DanmakuPage | TransferProgress | session.send(TYPE.RAW, ...) |
| StreamPage | TransferProgress | session.send(TYPE.RAW, ...) 循环 |

---

## 2. 协议层

### 2.1 L1 帧协议（`services/l1_engine.dart`）

完整移植 miniprogram `utils/l1-engine.js`。

**帧格式：**
```
数据帧：[0xAB, 0x00, len_hi, len_lo, crc_hi, crc_lo, seq_hi, seq_lo] + l2_payload
ACK 帧：[0xAB, 0x10, 0x00, 0x00, crc_hi, crc_lo, seq_hi, seq_lo]
ERR 帧：[0xAB, 0x30, 0x00, 0x00, crc_hi, crc_lo, seq_hi, seq_lo]
```

**CRC16 算法：** CRC-CCITT（多项式 0x8408，初值 0），与 JS 实现完全一致。

**L1Engine 类：**
| 方法 | 说明 |
|------|------|
| `sendL2(payload)` | 构造 L1 帧，按 MTU 分片，写入队列，返回 seq |
| `onNotified(data)` | 追加到 rxBuf，调 _drainRx() |
| `attach(session)` | 绑定当前 session，重置 seq 和 rxBuf |
| `detach()` | 解绑 session |
| `setMtu(mtu)` | 更新 chunkSize = max(20, mtu - 3) |
| `reset()` | 清空 rxBuf、重置 seq |

### 2.2 L2 文件传输协议（`services/l2_file_transfer.dart`）

完整移植 miniprogram `utils/l2-file-transfer.js`。

**L2 帧格式：**
```
[CMD=0x0B, 0x00, KEY, v_len_hi, v_len_lo] + value
```

**Key 常量：**
```dart
K: { BEGIN_REQ: 0x01, BEGIN_RSP: 0x02, DATA: 0x03, END_REQ: 0x05, END_RSP: 0x06, ABORT: 0x07 }
TYPE: { RAW: 0x00, IMAGE: 0x01, VIDEO: 0x02 }
```

**状态机：**
```
IDLE → NEGOTIATING（BEGIN_REQ，超时 5s）
     → TRANSFERRING（逐块 DATA，每块等 L1 ACK，超时 10s/块）
     → VERIFYING（END_REQ(CRC32)，超时 8s）
     → IDLE（onComplete 回调）
```

**FileTransferSession：**
```dart
class FileTransferSession {
  send(TYPE.IMAGE, buffer, filename);
  abort();
  // 回调
  void Function(int sent, int total) onProgress;
  void Function() onComplete;
  void Function(String reason) onError;
}
```

---

## 3. BLE 管理层（`services/ble_manager.dart`）

### 3.1 连接流程

```dart
startScan() → FlutterBluePlus.startScan()
            → 扫描结果去重 → 回调 onDeviceFound

connect(deviceId) → FlutterBluePlus.connect()
                  → 发现服务 FFD0
                  → 获取特征 FFD1(write) / FFD2(notify)
                  → 协商 MTU（requestMtu(512)）
                  → 订阅 notify
                  → 创建 L1Engine + FileTransferSession
```

### 3.2 串行写队列

```
_writeQueue: Queue<Uint8List>     // 待写 chunk
_writing: bool                    // 是否正在写

write(chunk):
  _writeQueue.add(chunk)
  if (!_writing) _flushQueue()

_flushQueue():
  if _writeQueue.isEmpty → _writing = false
  chunk = _writeQueue.removeFirst()
  characteristic.write(chunk, withoutResponse: true)
    .then(_flushQueue)
    .catchError(_onWriteError)
```

### 3.3 断线处理

FlutterBluePlus.onConnectionStateChanged 监听断开事件：
1. `l1Engine.reset()` 清空 RX 缓冲和序号
2. `activeSession?.abort()` 中止当前传输
3. 清空 `_writeQueue`
4. Provider 状态自动通知页面
5. 各页面导航回 ScanPage

### 3.4 UUID 常量

```dart
const TX_UUID = '0000FFD1-0000-1000-8000-00805F9B34FB';  // write
const RX_UUID = '0000FFD2-0000-1000-8000-00805F9B34FB';  // notify
const SERVICE_UUID = '0000FFD0-0000-1000-8000-00805F9B34FB';
```

---

## 4. 页面设计

### 4.1 ScanPage — 扫描页

- `initState()` 自动调用 `startScan()`
- 列表条目：设备名（空则显示"未知设备"）+ deviceId 后 8 位 + RSSI
- 点击：停止扫描 → `connect(deviceId)` → 加载动画 → 成功 push DevicePage
- 连接失败：SnackBar 提示
- `dispose()` 停止扫描

### 4.2 DevicePage — 设备主页

- AppBar：设备名 + "断开" TextButton
- GridView 2 列，5 张 ActionCard
- 断开连接：弹窗确认 → disconnect → pop
- 断线自动检测：AlertDialog → pop

### 4.3 ImagePage / GifPage / VideoPage

**状态：** idle → sending → done / error

**布局：**
```
[LinearProgressIndicator — sending 时显示]
[DashedBorder pick 区域 — 点击选文件]
[Text: 45% · 12 KB/s / ✓ 成功 / ✗ 错误]
[FilledButton: 发送到设备 / 取消]
```

- **ImagePage：** image_picker 插件选 JPG/PNG，TYPE_IMAGE
- **GifPage：** file_picker 插件过滤 .gif，TYPE_RAW
- **VideoPage：** image_picker 选视频，TYPE_VIDEO

**文件大小限制：** 超过 10MB 提示"文件过大，建议压缩后发送"

### 4.4 DanmakuPage — 弹幕页

- TextField，最多 60 字符，实时计数
- 发送按钮（空文本时禁用）
- 编码：UTF-8（Dart `utf8.encode()` 内置），TYPE_RAW

### 4.5 StreamPage — 摄像头推流

**推流循环（停等模式）：**
```
1. 点"开始推流"→ 打开 camera 预览
2. camera.takePicture() → File
3. 按分辨率压缩
4. session.send(TYPE.RAW, bytes, '') 发送一帧
5. 等待 onComplete 回调后采下一帧
```

**分辨率档位：**

| 档位 | 目标尺寸 | JPEG 质量 |
|------|---------|----------|
| 低 | 320×240 | 50 |
| 中 | 480×360 | 65 |
| 高 | 640×480 | 80 |

---

## 5. 主题设计

**Material Design 3 色彩方案：**

```dart
// 浅色主题（light color scheme）
primary: Color(0xFF1A73E8)     // Google Blue
onPrimary: Colors.white
primaryContainer: Color(0xFFD3E3FD)
secondary: Color(0xFF34A853)   // Google Green
surface: Colors.white
surfaceVariant: Color(0xFFF8F9FA)
background: Colors.white
error: Color(0xFFEA4335)       // Google Red
outline: Color(0xFFDADCE0)
```

**文字样式：**
- 卡片标题：TextTheme.titleMedium（w600）
- 设备名：TextTheme.titleLarge
- 描述文字：TextTheme.bodyMedium
- 辅助信息：TextTheme.bodySmall

---

## 6. 错误处理

| 场景 | 处理方式 |
|------|----------|
| 蓝牙未开启 | SnackBar + 引导到系统设置 |
| 位置权限未授予 | 运行时请求，拒绝后 SnackBar |
| 连接超时（10s） | SnackBar "连接超时，请重试" |
| 写特征值失败 | 清空队列，通知 error |
| ACK 超时 | 发 ABORT，SnackBar |
| 传输中断开 | AlertDialog → 跳转扫描页 |
| 文件 >10MB | 前置校验，SnackBar 提示 |
| 无 FFD1/FFD2 | SnackBar "设备不支持此功能" |

---

## 7. 技术约束

| 约束 | 处理方案 |
|------|----------|
| FlutterBluePlus 写不可并发 | 串行写队列 |
| Android 12+ BLE 权限 | 请求 BLUETOOTH_SCAN / BLUETOOTH_CONNECT |
| CameraX 权限 | camera 插件，运行时请求 |
| 文件选择 | image_picker / file_picker 插件 |
| MTU 协商 | FlutterBluePlus.requestMtu，兜底 20 |
| 生命周期暂停/恢复 | AppLifecycleListener 处理 |

---

## 8. 不在本期范围

- 发送历史记录
- 多设备连接
- TCP/WiFi 传输
- WiFi 配网
- 弹幕样式参数配置
