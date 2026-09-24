// gatt_dump.dart —— 独立的 GATT 服务表探针。
//
// 用途:连上设备,把它**实际暴露**的每个 service / characteristic / descriptor
// 连属性一起打出来,然后立刻断开。回答的就是一个问题:「这台固件到底有哪几根特征」。
//
// 为什么单独一个入口而不是加进 App:
//
// - 它不依赖 `BleManager`、不依赖 Riverpod、不依赖项目里任何一行代码。于是**任何
//   checkout 上都能跑** —— 排查「旧版本能投屏、新版本不能」这类问题时,探针本身
//   必须是常量,不能跟着被测版本一起变。
// - 它不匹配任何 UUID、不订阅 notify、不写一个字节。纯读 GATT 表,跑它不会改变
//   设备状态,也不会跟 App 的连接抢同一条 GATT(跑之前把 App 退干净即可)。
//
// 跑法(项目根目录):
//
//     flutter run -t tool/gatt_dump.dart
//
// 认哪台设备:默认扫名字里带 `eBadge` 的第一台。改 [kNameFilter] 即可;留空串
// 表示「不挑,扫到第一台有名字的就连」。也可以直接填 [kDeviceId] 跳过扫描。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 按名字前缀挑设备(大小写不敏感)。空串 = 不挑。
const String kNameFilter = 'eBadge';

/// 直连指定 MAC / remoteId,填了就不扫描。形如 `03:22:33:77:33:13`。
const String kDeviceId = '';

/// 扫描超时。扫不到就报错退出,不无限等。
const Duration kScanTimeout = Duration(seconds: 10);

void main() => runApp(const _DumpApp());

class _DumpApp extends StatelessWidget {
  const _DumpApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GATT Dump',
        theme: ThemeData.dark(useMaterial3: true),
        home: const _DumpPage(),
      );
}

class _DumpPage extends StatefulWidget {
  const _DumpPage();

  @override
  State<_DumpPage> createState() => _DumpPageState();
}

class _DumpPageState extends State<_DumpPage> {
  /// 屏幕上显示的行。同时也 debugPrint 一份到 logcat —— 手机屏幕能直接看、
  /// logcat 能复制粘贴,两边都要。
  final List<String> _lines = [];
  bool _running = false;

  void _log(String s) {
    debugPrint(s);
    if (!mounted) return;
    setState(() => _lines.add(s));
  }

  @override
  void initState() {
    super.initState();
    // 首帧之后再跑:要用 ScaffoldMessenger / setState,也让界面先画出来。
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _lines.clear();
    });
    BluetoothDevice? device;
    try {
      // 插件默认把每条扫描结果都打进 logcat,会把我们自己的输出冲掉。
      FlutterBluePlus.setLogLevel(LogLevel.none);

      if (!await _ensurePermissions()) {
        _log('✗ 蓝牙权限被拒 —— 到系统设置里授予「附近设备」和定位后重试');
        return;
      }
      if (!await _ensureAdapterOn()) {
        _log('✗ 蓝牙未开启');
        return;
      }

      device = await _pickDevice();
      if (device == null) return;

      _log('连接 ${device.remoteId}…');
      // license 是 flutter_blue_plus 2.x 的硬要求(内部调试工具走 nonprofit 档)。
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      _log('✓ 已连接');

      // MTU 只是顺带报一下:分片预算按它算,排查投屏时这个数有用。
      // 已协商过再请求在部分 Android 上会抛,失败就读当前值。
      var mtu = device.mtuNow;
      try {
        mtu = await device.requestMtu(512);
      } catch (_) {}
      _log('MTU = $mtu(单次 ATT 写净荷 ${mtu - 3} B)');

      await device.discoverServices();
      _dumpTable(device.servicesList);
    } catch (e) {
      _log('✗ 出错:$e');
    } finally {
      // 一定要断开:留着连接会让 App 下次连不上(同一条 GATT 被占)。
      try {
        await device?.disconnect();
        _log('已断开');
      } catch (_) {}
      if (mounted) setState(() => _running = false);
    }
  }

  /// Android 需要运行期蓝牙权限;扫描在部分机型上还要定位。桌面端无此模型。
  Future<bool> _ensurePermissions() async {
    // 不引 permission_handler:这个脚本要能在任何 checkout 上跑,依赖越少越好。
    // Android 12+ 上 startScan 自己会触发系统授权流程;真被拒了下面扫不到设备,
    // 会走到「扫不到」那条分支。这里只做一次 adapter 可用性检查。
    return true;
  }

  Future<bool> _ensureAdapterOn() async {
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    }
    _log('等待蓝牙开启…');
    try {
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 拿到要 dump 的那台设备:[kDeviceId] 填了就直连,否则扫描按 [kNameFilter] 挑。
  Future<BluetoothDevice?> _pickDevice() async {
    if (kDeviceId.isNotEmpty) {
      _log('直连 $kDeviceId(跳过扫描)');
      // ignore: prefer_const_constructors —— BluetoothDevice 的构造不是 const,
      // 项目 lint 的这条建议在这里是误报(加上 const 直接编译不过)。
      return BluetoothDevice(remoteId: const DeviceIdentifier(kDeviceId));
    }

    _log(kNameFilter.isEmpty
        ? '扫描中(不挑名字)…'
        : '扫描中(找名字含「$kNameFilter」的)…');

    final found = Completer<BluetoothDevice?>();
    final seen = <String>{};
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final adv = r.advertisementData.advName.trim();
        final name = adv.isNotEmpty ? adv : r.device.platformName.trim();
        final id = r.device.remoteId.toString();
        if (seen.add(id)) _log('  · ${name.isEmpty ? "(无名)" : name}  $id  ${r.rssi}dBm');
        final hit = kNameFilter.isEmpty
            ? name.isNotEmpty
            : name.toLowerCase().contains(kNameFilter.toLowerCase());
        if (hit && !found.isCompleted) {
          _log('✓ 选中 ${name.isEmpty ? "(无名)" : name}  $id');
          found.complete(r.device);
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: kScanTimeout);
      final device = await found.future.timeout(
        kScanTimeout + const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (device == null) {
        _log('✗ 没扫到匹配的设备 —— 确认设备在广播,或把 kNameFilter 改成空串看全部');
      }
      return device;
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  /// 把整张 GATT 表打出来。
  ///
  /// **不做任何 UUID 匹配、不加任何角色标注** —— 这正是重点:探针只如实报告设备
  /// 暴露了什么,要不要认、认成什么,是 App 那边的事。想知道「投屏能不能用」,
  /// 自己在输出里找有没有一根 write/writeNR 的 FFC4 加一根 notify 的 FFC5。
  void _dumpTable(List<BluetoothService> services) {
    var chars = 0;
    for (final s in services) {
      chars += s.characteristics.length;
    }
    _log('── GATT ────────────────────────────────');
    _log('${services.length} 个服务,$chars 个特征');

    for (final s in services) {
      _log('┌ service ${s.uuid}  (${s.characteristics.length} char, '
          'primary=${s.isPrimary})');
      for (final c in s.characteristics) {
        final props = <String>[
          if (c.properties.read) 'read',
          if (c.properties.write) 'write',
          if (c.properties.writeWithoutResponse) 'writeNR',
          if (c.properties.notify) 'notify',
          if (c.properties.indicate) 'indicate',
          if (c.properties.broadcast) 'broadcast',
          if (c.properties.authenticatedSignedWrites) 'signedWrite',
          if (c.properties.extendedProperties) 'ext',
        ];
        _log('│  char ${c.uuid}  [${props.isEmpty ? "none" : props.join(",")}]');
        for (final d in c.descriptors) {
          _log('│    descriptor ${d.uuid}');
        }
      }
      _log('└');
    }
    _log('────────────────────────────────────────');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('GATT Dump'),
          actions: [
            IconButton(
              tooltip: '重新探测',
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_running) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _lines.length,
                // 等宽字体 + 不换行:UUID 和属性列要能对齐着扫。
                itemBuilder: (_, i) => Text(
                  _lines[i],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
