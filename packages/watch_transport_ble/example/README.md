# BLE 独立诊断应用

本应用引用 `watch_transport` / `watch_transport_ble` / `watch_frame_channel`，不引用 HoneyBox、JW SDK、WS SDK 或数据库。
用于 T2 的 BLE 字节收发与 T3 的公共 L0/L1 真机验收。

1. `flutter run -d macos` 或 `flutter run -d <android-id>`。Android 首次扫描由应用申请权限；macOS 由系统授权蓝牙。
2. 选择 **JW Realtek FF** 或 **WS UART**，扫描并选择自己的设备；不会自动尝试不同协议。
3. 连接后查看状态和写入限制，可收发原始十六进制字节。原始发送不会自动做 ACK 或解析业务。
4. JW 可执行标准 Battery Service 电量读取，以及 FF02/FF03 语言查询；L2 字节在 example 中组织，语言查询的 CRC/帧/ACK/重传由公共 frame channel 负责。
5. 断开并重新连接，再次查询，确认旧连接清理不影响新连接。

真机脚本：

```sh
flutter test integration_test/jw_ble_smoke_test.dart -d macos --dart-define=BLE_DEVICE_ID=<macOS设备UUID>
```

脚本先扫描，只连接明确指定设备；未指定时要求只有一个 JW 候选。也可以按广播名称或广播中的 MAC 筛选：

```sh
flutter test integration_test/jw_ble_smoke_test.dart -d macos \
  --dart-define=BLE_DEVICE_NAME=2616_GHDBSC \
  --dart-define=BLE_DEVICE_MAC=69:2D:0C:AD:00:1D \
  --dart-define=BLE_SCAN_SECONDS=25
```

同时指定的条件必须全部匹配；MAC 按平台地址或厂家数据中完整 6 字节（正序/反序）匹配。
macOS 的平台设备 ID 是 UUID，不等同于蓝牙 MAC；设备重启后可重新通过广播确认。
校验实际业务回应、GATT 电量、断开与重连。第一轮额外限制每次写入最多 5 字节，
丢弃一次真实 ACK，断言重试的完整字节和 seq 相同；该脚本不会用匹配 L2 提前结束这一轮 ACK 测试。
不会登录、绑定、修改设置、清除历史或执行 OTA。Android 脚本运行前须已授予应用蓝牙权限。

T2 历史记录：GHW-01D 实测 MTU 247，两次连接均返回语言编码 1、电量 52%。这台固件使用标准电量服务，
不能把另一套 BWPS 电量命令仅收到 ACK 当作查询成功。Windows 工程已生成，原生插件需在 Windows 验证。
Android Gradle/AGP/Kotlin 版本沿用当前已验证的 WS 独立 Demo 版本。

T3 当前用户指定目标为 `2616_GHDBSC / 69:2D:0C:AD:00:1D`。本机延长扫描仍未发现目标，
目标设备验收待继续；另一台 GHW-01D 上完成的收发/故障探针不计作本目标的通过结果。
