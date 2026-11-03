# WS Watch Demo

M2–M6 的模拟器验收与接入示例。业务代码只依赖 Flutter、SDK 公开 API 和文件选择辅助包，不引用 HoneyBox、Link、Session 或 Transport 实现。

从 HoneyBox 的 WS Watch 入口进入，或独立运行：

```bash
cd packages/ws_watch_demo/example
flutter pub get
flutter run -d macos
# Android：选择 flutter devices 列出的设备 ID
flutter run -d <android-device-id>
flutter build apk --debug
```

独立应用名称为 **WS Watch Demo**，Android applicationId 为 `com.wosmart.ws_watch_demo_example`，与 HoneyBox 分开安装、各自保存数据。当前有 Android/macOS 运行壳；真实 BLE UART 连接在 M7，M6 完整流程使用 Simulator，无需蓝牙权限。

M6 **Raw 调试**：`ready` 后点右下角虫子按钮（或首页「Raw 调试」）打开半屏 BottomSheet。主输入为 **L2 请求 hex**（示例读语言 `02 00 03 00 01 01`）；可选等待回应、折叠「从协议表带入」。SDK 能力仍为 `watch.debug.sendRaw` + 帧/上报流；详细解析请用日志或脚本。

验收顺序：M3 连接 Simulator → Raw 读语言 → hex 写 `02 00 03 00 02 00 07` 关回应等待 → M5 同步两次检查去重。M5 模拟数据日期为 2026-10-12。

```bash
# 在各包目录运行
(cd packages/ws_watch_sdk && flutter test)
(cd packages/ws_watch_demo && flutter test)
# 在 HoneyBox 仓库根目录运行原生完整脚本（默认 SQLite + 系统剪贴板）
(cd packages/ws_watch_demo/example && flutter test integration_test/m6_simulator_script_test.dart -d macos)
```

文件导出组件测试使用系统文件选择器替身，并实际写入、读取 UTF-8 临时文件；原生脚本验证系统剪贴板。系统“另存为”对话框与 Android 安装交互请按上述步骤手动验收。
