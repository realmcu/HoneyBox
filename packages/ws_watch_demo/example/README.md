# ws_watch_demo_example

独立运行 `ws_watch_demo`，用于在 Mac 上开发和做真机自动化测试。界面和逻辑都在 `ws_watch_demo` 包里，这里只是启动壳。

## 运行

```bash
cd packages/ws_watch_demo/example
flutter run -d macos
```

Android Studio：新建 Flutter 运行配置，Dart entrypoint 选 `packages/ws_watch_demo/example/lib/main.dart`，设备选 macOS。

首次运行时系统会请求蓝牙权限，需要允许。

## 测试

```bash
# 组件测试，不需要设备
flutter test

# 在 Mac 上运行的集成测试；真机用例需要手表在附近
flutter test integration_test -d macos
```
