# 导航投屏 WiFi 传图协议

版本 1.0 | 2026-08-05

## 1. 概述

本协议在 WiFi LAN 环境下通过 TCP 传输导航画面（JPEG 帧），用于在仪表盘 / 车载屏幕等设备上显示实时导航投屏画面。

传输由 Android 端 `NaviCaptureService` 在虚拟屏上渲染导航 UI，逐帧采集、JPEG 编码后通过单个持久 TCP 连接发送。

---

## 2. 传输层

- **协议**: TCP
- **连接模式**: 单个持久连接，整个投屏会话期间保持
- **端口**: 可配置，默认 5004
- **方向**: App (Android) → Dev (接收端)
- **可靠性**: 依赖 TCP 的有序、可靠字节流保证

---

## 3. 帧格式

每帧由 **ASCII 头行 + JPEG 载荷** 两部分组成，连续写入 TCP 流：

```
JPG <size> <seq>\n
<JPEG payload (size bytes)>
```

### 3.1 帧头行

ASCII 文本行，以 `\n` (0x0A) 结尾：

```
JPG 4896 0\n
```

| 字段 | 格式 | 说明 |
|------|------|------|
| `JPG` | 固定字面量 | 帧类型标识 |
| `<size>` | 十进制整数 | JPEG 载荷字节数 |
| `<seq>` | 十进制整数 | 帧序号，每帧递增，0-255 轮转 |
| `\n` | 0x0A | 行结束符 |

### 3.2 JPEG 载荷

紧接头行 `\n` 之后，`size` 字节的完整 JPEG 数据。

### 3.3 完整示例

```
JPG 4896 0\n<4896 bytes of JPEG data>JPG 5120 1\n<5120 bytes of JPEG data>...
```

---

## 4. 接收端解析流程

```
while (连接活跃) {
    1. 读取直到 '\n' → 得到头行 "JPG <size> <seq>"
    2. 解析 size 和 seq
    3. 读取接下来的 size 个字节 → 得到 JPEG 载荷
    4. JPEG 解码 → 显示
}
```

接收端不需要发送任何 ACK 或状态回复，App 也不等待确认。

---

## 5. 采集端行为

Android 端 `NaviCaptureService` 的发送流程：

```
1. 创建 VirtualDisplay (400×480) + Presentation 渲染导航 UI
2. ImageReader 从虚拟屏采集 RGBA 帧
3. libjpeg-turbo 编码为 JPEG (quality=60)
4. 写入 TCP socket（异步专用线程，不阻塞导航渲染）
5. 按目标帧率 (典型 5fps) 定时触发下一帧采集
```

发送线程使用容量为 2 的队列：编码快于网络时丢弃旧帧，确保导航 UI 不因网络反压卡顿。

---

## 6. 断线处理

- TCP 连接断开：App 侧自动重连（间隔 1s），帧序号从 0 重新开始
- 设备端 TCP 监听：使用 SO_REUSEADDR，允许 App 断线后快速重连
