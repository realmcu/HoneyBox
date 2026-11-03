import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:watch_transport/watch_transport.dart';
import 'package:watch_transport_ble/watch_transport_ble.dart';
import 'jw_smoke.dart';

void main() => runApp(const MaterialApp(home: BleDiagnostics()));

class BleDiagnostics extends StatefulWidget {
  const BleDiagnostics({super.key});
  @override
  State<BleDiagnostics> createState() => _BleDiagnosticsState();
}

class _BleDiagnosticsState extends State<BleDiagnostics> {
  final scanner = WatchBleScanner();
  final hex = TextEditingController();
  final entries = <String>[];
  final subscriptions = <StreamSubscription<dynamic>>[];
  List<WatchBleAdvertisement> devices = [];
  WatchBleConnection? connection;
  bool busy = false, wsProfile = false;
  void log(Object value) {
    if (!mounted) return;
    setState(() {
      entries.insert(0, '${DateTime.now().toIso8601String()} $value');
      if (entries.length > 200) entries.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();
    subscriptions.add(scanner.results.listen((value) {
      if (mounted) setState(() => devices = value);
    }));
    subscriptions.add(scanner.errors.listen(log));
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (error) {
      log(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    if (Platform.isAndroid) {
      final sdk =
          await const MethodChannel('watch_transport_ble_example/platform')
              .invokeMethod<int>('androidSdk');
      if (sdk == null) throw StateError('无法读取 Android 版本');
      if (sdk >= 31) {
        final scan = await Permission.bluetoothScan.request();
        final connect = await Permission.bluetoothConnect.request();
        if (!scan.isGranted || !connect.isGranted) {
          throw StateError('请授予附近设备权限');
        }
      } else {
        if (!(await Permission.locationWhenInUse.request()).isGranted) {
          throw StateError('此 Android 版本扫描需要定位权限');
        }
      }
    }
    await scanner.stop();
    await scanner.start();
    log('扫描开始');
  }

  Future<void> connect(WatchBleAdvertisement device) async {
    await scanner.stop();
    await connection?.dispose();
    final profile = wsProfile
        ? WatchBleProfile(
            service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
            tx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
            rx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e')
        : jwDiagnosticProfile();
    final wire = WatchBleTransport(config: WatchBleConfig(profile: profile))
        .createConnection(
            WatchDeviceTarget(transportId: 'ble', deviceId: device.deviceId));
    connection = wire;
    subscriptions
        .add(wire.received.listen((bytes) => log('RX ${_hex(bytes)}')));
    subscriptions.add(wire.stateChanges.listen((state) =>
        log('${state.name}; write limit=${wire.writeLimits.maxWriteLength}')));
    await wire.connect();
    log('已连接 ${device.name} ${device.deviceId}');
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  Future<void> send() async {
    final text = hex.text.replaceAll(RegExp(r'\s'), '');
    if (text.isEmpty ||
        text.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      throw const FormatException('请输入完整十六进制字节');
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16)
    ]);
    await connection!.write(bytes);
    log('TX ${_hex(bytes)}');
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(scanner.dispose());
    connection?.dispose().ignore();
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = connection?.state == WatchTransportState.connected;
    return Scaffold(
        appBar: AppBar(title: const Text('BLE 连接诊断')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                            onPressed:
                                busy || connected ? null : () => action(scan),
                            child: const Text('扫描')),
                        OutlinedButton(
                            onPressed: busy ? null : () => action(scanner.stop),
                            child: const Text('停止扫描')),
                        OutlinedButton(
                            onPressed: busy || connection == null
                                ? null
                                : () => action(() async {
                                      await connection!.dispose();
                                      log('已释放连接');
                                    }),
                            child: const Text('断开')),
                        DropdownButton<bool>(
                            value: wsProfile,
                            items: const [
                              DropdownMenuItem(
                                  value: false, child: Text('JW Realtek FF')),
                              DropdownMenuItem(
                                  value: true, child: Text('WS UART'))
                            ],
                            onChanged: busy || connected
                                ? null
                                : (value) =>
                                    setState(() => wsProfile = value!)),
                      ]),
                  SizedBox(
                      height: 180,
                      child: ListView(children: [
                        for (final device in devices)
                          ListTile(
                              dense: true,
                              title: Text(
                                  '${device.name.isEmpty ? "未命名设备" : device.name} (${device.rssi})'),
                              subtitle: Text(device.deviceId),
                              trailing: TextButton(
                                  onPressed: busy || connected
                                      ? null
                                      : () => action(() => connect(device)),
                                  child: const Text('连接')))
                      ])),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: hex,
                            decoration:
                                const InputDecoration(labelText: '原始十六进制字节'))),
                    const SizedBox(width: 12),
                    FilledButton(
                        onPressed:
                            busy || !connected ? null : () => action(send),
                        child: const Text('发送')),
                    const SizedBox(width: 12),
                    OutlinedButton(
                        onPressed: busy || !connected || wsProfile
                            ? null
                            : () => action(() async {
                                  log('JW 电量：${await readJwBattery(connection!)}%');
                                }),
                        child: const Text('JW 电量查询')),
                    OutlinedButton(
                        onPressed: busy || !connected || wsProfile
                            ? null
                            : () => action(() async {
                                  log('JW 语言编码：${await queryJwLanguage(connection!)}');
                                }),
                        child: const Text('JW 语言查询'))
                  ]),
                  const SizedBox(height: 12),
                  const Text('收发与状态日志（最近 200 条）'),
                  Expanded(
                      child: ListView(children: [
                    for (final entry in entries)
                      SelectableText(entry,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12))
                  ])),
                ])));
  }
}
