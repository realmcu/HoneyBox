# Watch 手动绑定设计

## 目标

在 Watch 设备主页增加协议 3.4 的手动绑定入口。用户点击按钮后，App 通过现有 BLE L1 命令通道发送绑定请求，等待设备返回绑定结果，并在原位置展示完整状态反馈。

本阶段仅用于设备联调，不接入账号、手机号、邮箱或云端服务。

## 已确认交互

- 用“绑定设备”替换 Watch 页面顶部连接状态栏中的“WiFi 配网”。
- 不自动绑定，不显示确认对话框。
- 状态为：`绑定设备`、`绑定中...`、`已绑定`、`重新绑定`、`无法绑定`。
- 绑定成功后按钮禁用；失败或等待响应超时后允许重新绑定。
- 使用 SnackBar 显示成功、设备返回失败和 App 等待超时的结果。
- 已确认的交互原型位于 `docs/prototypes/watch-bind-mockup.html`。

## 协议

绑定命令使用 L2 command `0x03`：

- 请求 key：`0x01`
- 请求 value：32 字节 User ID
- 请求帧：`03 00 01 00 20 <32-byte user_id>`
- 响应 key：`0x02`
- 响应 value：`0x00` 成功，`0x01` 超时失败
- 成功响应：`03 00 02 00 01 00`

App 复用 `BleManager.sendCommand()` 发送 L2，并监听 `commandNotifications`。其他 command、其他 key 以及格式不完整的帧均忽略。

## User ID

App 进程启动后使用 `Random.secure()` 生成一个 32 字节 User ID。同一进程内重复进入页面或重新绑定均使用同一个值；App 重启后重新生成。发送时将完整 User ID 以十六进制写入调试日志，方便与固件日志比对。

该行为是临时联调方案。持久化账号身份、跨 Android/Windows 同步和云端账户不在本次范围内。

## 组件边界

- `watch_bind_protocol.dart`：生成 User ID、构建请求、解析响应；不依赖 Flutter UI。
- `watch_bind_provider.dart`：管理通知订阅、8 秒超时和绑定状态；通过回调依赖传输层，便于单元测试。
- `watch_device_page.dart`：渲染按钮、进度指示和 SnackBar，不解析协议字节。

绑定控制器随 Watch 页面对应的 Riverpod provider 生命周期释放，释放时取消通知订阅和定时器。

## 错误处理

- 命令通道未就绪：显示 `无法绑定`，不发送。
- `sendCommand()` 返回 `null`：切换为不可用状态。
- 响应 `0x00`：显示 `已绑定`。
- 响应 `0x01` 或其他非零状态：显示 `重新绑定`，提示设备绑定失败。
- 8 秒未收到有效响应：显示 `重新绑定`，提示响应超时。
- 绑定进行中忽略重复点击和无关通知。

## 测试与验收

- 单元测试覆盖请求字节、32 字节校验、响应解析、随机 ID 长度。
- 控制器测试覆盖成功、设备失败、超时、通道不可用、无关/畸形通知和重复点击。
- Widget 测试覆盖按钮替换、绑定中和绑定成功状态。
- 运行 `flutter test`、`flutter analyze` 和 `flutter build windows`。

