# ws_watch_demo_example

独立运行 `ws_watch_demo`，用于在 Mac 上开发和做真机自动化测试。界面和逻辑都在 `ws_watch_demo` 包里，这里只是启动壳。

## 运行

```bash
cd packages/ws_watch_demo/example
flutter run -d macos
```

Android Studio：新建 Flutter 运行配置，Dart entrypoint 选 `packages/ws_watch_demo/example/lib/main.dart`，设备选 macOS。

Simulator 连接及 M4 设置验收无需蓝牙权限。扫描真实蓝牙广播时，需允许系统蓝牙权限。

M4：从首页进入“M4 设置”，连接 Simulator 后验收时间、语言与显示格式；也可从 M3 已连接页面进入复用会话。

## 测试

```bash
# 组件测试，不需要设备
flutter test

# 在 Mac 上运行的集成测试；真机用例需要手表在附近
flutter test integration_test/m6_simulator_script_test.dart -d macos
flutter test integration_test/simulator_connection_test.dart -d macos
```


M5 验收入口：主页「M5 历史数据」，支持活动桶/心率单类型同步、进度与确认状态、取消、断开后的 SQLite 查询、过滤删除和同步日志。模拟记录时间为 2026-10-12；先同步两次检查新增/重复，再断开、退出重进或重启检查持久化。仍使用内存设备传输，真实 BLE 在 M7。

原生持久化集成测试：`flutter test integration_test/simulator_connection_test.dart -d macos`，覆盖默认数据库连接、同步、重复去重、断开查询和关闭实例后重新查询。

## M6 Raw 调试（半屏）

首页「Raw 调试」或各页右下角按钮：L2 hex 发送 + 可选协议表带入。集成脚本见 [Demo README](../README.md)。

`flutter test integration_test/m6_simulator_script_test.dart -d macos`：M3 连接 → Raw 读/写语言 → M5 同步。

macOS 本机批量运行多个集成测试文件时曾遇到 Flutter 测试壳重启失败（尚未进入用例）；单文件分别执行已通过，推荐使用上面的单文件命令。
