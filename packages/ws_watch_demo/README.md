# ws_watch_demo

WS Watch SDK 的 UI Demo，同时内置一个无 UI 操作的自动化 Lab。Lab 调用与页面相同的
`WSDemoController`，完整经过 SDK 的扫描、连接、绑定、读写和历史同步路径；设备端使用
进程内协议模拟器，所以固件未完成时也能稳定回归。

## AI / ADB 自动化入口

连接一台 Android 设备后，在本目录运行：

```bash
./tool/run_ws_lab.sh all
```

也可以只运行一个计划，或在连接多台设备时显式传入 adb serial：

```bash
./tool/run_ws_lab.sh smoke T813A256GB25376353627
./tool/run_ws_lab.sh settings T813A256GB25376353627
./tool/run_ws_lab.sh multi-device T813A256GB25376353627
```

脚本会执行 `integration_test/ws_demo_smoke_test.dart`。可用计划：

- `smoke`：单设备扫描/连接/绑定、设备信息、实时数据、设置写入回读恢复、测量启停、历史同步。
- `settings`：0x02 显示/单位、全部自动监测时段、健康告警、通用设置、闹钟和联系人 CRUD。
- `binding`：0x03 登录优先认证、普通绑定、确认保护、解绑、重新连接和超级绑定。
- `notifications`：0x04 来电/消息/音乐/查找/相机发送，以及模拟设备反向事件流。
- `history-data`：0x05 能力 TLV、今日配置、运动详情分帧、单类型/全量同步和操作互斥。
- `measurement-sport`：0x11 全部点测通道、持续心率、状态查询和运动开始/暂停/恢复/结束事件。
- `multi-device`：双设备连接、并行同步、单设备断开隔离。
- `all`：依次执行全部计划（默认）。

每个事件都会输出一行 `WS_LAB_JSON { ... }`，便于 AI 或 CI 解析步骤、耗时、返回值和
错误。任何步骤失败都会让 Flutter 测试返回非零退出码。新增协议场景时，在
`lib/src/lab/ws_demo_lab.dart` 中增加 plan/step 即可，不需要增加页面或点击流程。

如果 Flutter 不在 `PATH`，可显式指定：

```bash
FLUTTER_BIN=/path/to/flutter ./tool/run_ws_lab.sh all
```
