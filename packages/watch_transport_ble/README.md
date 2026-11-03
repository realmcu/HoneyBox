# watch_transport_ble

`watch_transport` 的真实 BLE 实现。负责扫描、连接、GATT profile 校验、Notify/Indicate 订阅、
动态写入限制、平台操作排队及资源释放，不解析 JW/WS、L0/L1、ACK、seq 或健康数据。
运行时依赖 FlutterBluePlus；Windows 的连接参数调优插件由本包自动注册，不依赖 HoneyBox 媒体插件。

## 基本接入

```dart
import 'dart:typed_data';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';

final transport = WatchBleTransport(config: WatchBleConfig(
  profile: WatchBleProfile(
    service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
    writeMode: BleWriteMode.withResponse,
  ),
));
final connection = transport.createConnection(
  WatchDeviceTarget(transportId: 'ble', deviceId: deviceId),
);
final subscription = connection.received.listen(handleBytes);
try {
  await connection.connect();
  // Callers frame/fragment their own protocol according to current writeLimits.
  await connection.write(Uint8List.fromList([1, 2]));
} finally {
  await subscription.cancel();
  await connection.dispose();
}
```

示例 UUID 是 WS UART。协议拥有者提供 profile；JW 的 FF 服务配置见独立 example，
transport 不会通过发送两种协议来猜测设备。重复服务或重复 TX/RX 会被明确拒绝。

`WatchBleScanner` 提供不含 FlutterBluePlus 类型的广播结果（名称、ID、RSSI、服务、厂商数据）。
先订阅 results/errors，再 start，最终 dispose。候选过滤、模拟设备合并、设备业务身份属于 SDK。
库不会弹权限对话框或打开系统设置；宿主声明并申请权限后调用，错误以中立 code/stage 返回。
接入方可按其 FlutterBluePlus 使用条件为 `FlutterBlueWatchBackend` 指定 license；默认与现有工程一致。

## 生命周期与排队

- 连接对象单次使用，重连创建新对象；订阅先于 connect。只有 profile 校验与接收订阅完成后才 connected。
- 连接阶段/原因由 `WatchBleException.stage` / `code` 表达，权限拒绝、蓝牙关闭、profile 缺失、超时与占用可区分。
- 先订阅 RX 流再写 CCCD，初始化早到字节会保存。无人订阅缓冲默认 64 KiB；溢出断开并报错。
  接收数组只读，发送输入立即复制。协议消费者应持续消费，暂停订阅不提供有界背压。
- 写入按 GATT 操作串行，大小使用当前有效 MTU（最小 23，最大 517，单次 value 最大 512）。
  BLE transport 不分配 seq、不重传业务帧、不等待设备 ACK；帧分片与整帧队列属于 T3。
- 可选 `readGatt(service:, characteristic:)` / `writeGatt(withoutResponse:)` 仅存在于 BLE 具体连接，
  不扩充通用 transport 接口。read 与 write 共用平台队列，普通 read 失败不结束连接；
  超时会结束连接，防止尚未结束的原生操作与新操作重叠。
- disconnect 立即结束 connect/在途写与排队调用的等待。disconnect/dispose 的清理 Future 会等平台操作结束，
  再确认物理断开并释放租约；迟到 connect 会再次断开。平台清理失败保留租约，可显式重试 disconnect/dispose。
- 每个测试/宿主使用一个运行时协调器；默认 `WatchBleCoordinator.shared` 在同一 isolate 内共享。
  自定义 backend/coordinator 时，所有合作入口必须使用同一实例，不声称能跨进程阻止系统其他应用连接。

## 旧入口与 OTA 共存

`WatchBleCoordinator.acquire(id)` 在第一次平台连接之前同步取得租约；同设备独占，普通不同设备可并行。
只有在真实工作结束、物理连接断开后才 release。`lease.addDevice(dfuId)` 为同一升级事务增加别名，保留正常态 ID。
原生后端确实需要全局排他时使用 `exclusive: true`；不要将 Dart Future 超时当作原生 DFU 停止。

公共扫描通过 `startScan(start:, stop:, onRevoked:)` 获取 token；`token.close()` 只关闭自己的扫描。
连接需要停扫描时使用 `stopScanning()`，原扫描收到撤销回调。旧 token 的重复清理不会停止新扫描。
平台 stop 失败保留扫描预留，可对 token 重试 close 或再次 stopScanning。

HoneyBox 的 BleManager、采集、版本/设备探测、Dart DFU、Android Realtek OTA 已接入同一协调器。
原有投屏/导航/JW Session 与 OTA 协议保留在宿主；这些入口只接入资源协调，未在 T2 整体迁入 SDK。
旧 MTU、写队列、调优 Dart 文件已变为薄转导出；投屏的额外帧开销仍留在宿主。

## 验证和平台状态

```sh
# 在本包目录
flutter test
# 独立应用：选择 JW / WS profile，扫描连接、收发原始字节，JW 标准电量读取/语言查询
cd example
flutter run -d macos
# 只读真机集成；多候选必须明确指定 ID
flutter test integration_test/jw_ble_smoke_test.dart -d macos --dart-define=BLE_DEVICE_ID=<id>
flutter build apk --debug
```

原生纯 C++ 地址解析可用 `cmake -S windows -B <build-dir> -DBUILD_TESTING=ON`、build、CTest 独立验证；WinRT 插件仍须 Windows 构建。

假平台测试覆盖失败阶段、通知早到、MTU 变化、写入/读取串行、取消/超时、迟到连接、租约保持与清理重试、
扫描竞争、双设备隔离以及调优通道。Android/macOS 工程包含各自权限与插件声明。
本轮 GHW-01D 已通过 macOS 真机扫描→连接→语言命令/回应→标准电量读取→断开重连；
这不代表完整 JW SDK 业务验收。Windows 插件已迁出并配置自动注册，仍需 Windows 编译与真机验收。
WS UART 可装配；没有 WS 固件，本轮没有 WS 真机结论。iOS/Linux 未提供本包独立 example 的验收结果。
