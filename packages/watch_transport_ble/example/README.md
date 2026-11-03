# BLE 独立诊断应用

本应用只引用 `watch_transport` / `watch_transport_ble`，不引用 HoneyBox、JW SDK、WS SDK 或数据库。
用于 T2 的真实 BLE 连接/字节收发验收。

1. `flutter run -d macos` 或 `flutter run -d <android-id>`。Android 首次扫描由应用申请权限；macOS 由系统授权蓝牙。
2. 选择 **JW Realtek FF** 或 **WS UART**，扫描并选择自己的设备；不会自动尝试不同协议。
3. 连接后查看状态和写入限制，可收发原始十六进制字节。原始发送不会自动做 ACK 或解析业务。
4. JW 可执行标准 Battery Service 电量读取，以及 FF02/FF03 语言查询；这些诊断协议字节只在 example 中组织。
5. 断开并重新连接，再次查询，确认旧连接清理不影响新连接。

真机脚本：

```sh
flutter test integration_test/jw_ble_smoke_test.dart -d macos --dart-define=BLE_DEVICE_ID=<macOS设备UUID>
```

脚本先扫描，只连接明确指定设备；未指定时要求只有一个 JW 候选。校验实际业务回应、GATT 电量、断开与重连。
不会登录、绑定、修改设置、清除历史或执行 OTA。Android 脚本运行前须已授予应用蓝牙权限。

GHW-01D 本轮实测：MTU 247，两次连接均返回语言编码 1、电量 52%。这台固件使用标准电量服务，
不能把另一套 BWPS 电量命令仅收到 ACK 当作查询成功。Windows 工程已生成，原生插件需在 Windows 验证。
Android Gradle/AGP/Kotlin 版本沿用当前已验证的 WS 独立 Demo 版本。
