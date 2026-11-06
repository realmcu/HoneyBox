import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble_mtu.dart';
import 'ota_platform.dart';
import 'rtl87x3g_firmware_image.dart';

const _dfuService = '00006287-3c17-d293-8e48-14fe2e4da212';
const _dfuPacket = '00006387-3c17-d293-8e48-14fe2e4da212';
const _dfuControl = '00006487-3c17-d293-8e48-14fe2e4da212';
const _deviceInfo = '0000fff1-0000-1000-8000-00805f9b34fb';
const _otaEnter = '0000ffd1-0000-1000-8000-00805f9b34fb';
const _otaManufacturerId = 0x005d;

const _opStartDfu = 0x01;
const _opReceiveImageInfo = 0x02;
const _opValidFw = 0x03;
const _opActiveImageReset = 0x04;
const _opBufferCheckEnable = 0x09;
const _opReportBufferCrc = 0x0a;
const _notifyOpcode = 0x10;
const _success = 0x01;

/// RTL87x3G normal OTA over FlutterBluePlus.
///
/// The normal application accepts FFD1=1, reboots into a dedicated OTA-only
/// firmware mode, and then advertises BeTgt with the 128-bit DFU service.
final class Rtl87x3gOtaPlatform implements OtaPlatform {
  final _events = StreamController<Map<String, Object?>>.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _packet;
  BluetoothCharacteristic? _control;
  BluetoothCharacteristic? _otaEnterCharacteristic;
  StreamSubscription<List<int>>? _controlNotifications;
  StreamSubscription<BluetoothConnectionState>? _connectionState;
  Completer<Uint8List>? _reply;
  String? _sessionId;
  String? _normalDeviceId;
  int _mtu = kMinAttMtu;
  bool _ownsConnection = false;
  bool _switchingToOtaMode = false;
  bool _prepared = false;
  bool _running = false;
  bool _closing = false;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> prepare(String deviceId, {String? sessionId}) async {
    if (sessionId == null || sessionId.isEmpty) {
      throw ArgumentError('sessionId required');
    }
    if (_prepared || _running || _closing) {
      throw StateError('OTA 会话尚未关闭');
    }
    _sessionId = sessionId;
    _normalDeviceId = deviceId;
    await _cleanupConnection();
    _device = BluetoothDevice.fromId(deviceId);
    _ownsConnection = true;
    try {
      await _device!.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 30),
      );
      final services = await _device!.discoverServices();
      _packet = _findCharacteristic(services, _dfuPacket);
      _control = _findCharacteristic(services, _dfuControl);
      _otaEnterCharacteristic = _findCharacteristic(services, _otaEnter);
      if (!services.any((s) => s.uuid.str128.toLowerCase() == _dfuService)) {
        throw StateError('设备未提供 RTL87x3G DFU 服务');
      }
      _mtu = await negotiatePlatformMtu(_device!.remoteId, desired: 247);
      final info = _findCharacteristic(services, _deviceInfo);
      final rawInfo = Uint8List.fromList(await info.read());
      if (rawInfo.length < 14 ||
          rawInfo[0] != rtl87x3gIcType ||
          rawInfo[10] | (rawInfo[11] << 8) != rtl87x3gControlHeaderOffset) {
        throw StateError('设备信息不匹配 RTL8773G 普通 OTA');
      }
      final reportedMtu =
          ByteData.sublistView(rawInfo).getUint16(6, Endian.little);
      if (reportedMtu > kMinAttMtu && reportedMtu <= kMaxAttMtu) {
        _mtu = reportedMtu;
      }
      _controlNotifications = _control!.onValueReceived.listen((value) {
        final reply = _reply;
        if (reply != null && !reply.isCompleted) {
          reply.complete(Uint8List.fromList(value));
        }
      });
      await _control!.setNotifyValue(true);
      _listenConnectionState();
      _prepared = true;
      _emit(sessionId, message: '设备已连接，请选择匹配的固件', ready: true);
    } catch (error) {
      await _cleanupConnection();
      rethrow;
    }
  }

  @override
  Future<void> start(String filePath) async {
    if (!_prepared || _running || _closing) {
      throw StateError('OTA 会话未准备或已启动');
    }
    final package = Rtl87x3gOtaPackage.parse(
      await File(filePath).readAsBytes(),
    );
    _running = true;
    _emit(_sessionId!, message: '开始传输固件', progress: 0, ready: false);
    unawaited(_run(package.image));
  }

  Future<void> _run(Rtl87x3gFirmwareImage image) async {
    final sessionId = _sessionId!;
    try {
      _emit(sessionId, message: '正在切换升级模式', ready: false);
      await _switchToOtaMode();
      final startPayload = Uint8List(32)
        ..setRange(0, rtl87x3gControlHeaderSize, image.controlHeader);
      await _command(
        _opStartDfu,
        startPayload,
        expectedOpcode: _opStartDfu,
        expectedLength: 3,
      );
      final receive = Uint8List(7)..setRange(0, 1, [0]);
      receive[0] = _opReceiveImageInfo;
      ByteData.sublistView(receive).setUint16(1, image.imageId, Endian.little);
      ByteData.sublistView(receive).setUint32(3, 0, Endian.little);
      await _control!.write(receive, withoutResponse: false);

      final bufferResponse = await _command(
        _opBufferCheckEnable,
        Uint8List(0),
        expectedOpcode: _opBufferCheckEnable,
        expectedLength: 7,
      );
      final bufferSize =
          ByteData.sublistView(bufferResponse).getUint16(3, Endian.little);
      if (bufferSize == 0) {
        throw StateError('设备未启用 DFU 缓冲校验');
      }
      final blockSize = math.min(bufferSize, 4096).toInt();
      final packetSize = math.max(20, math.min(240, _mtu - 3)).toInt();

      for (var offset = 0; offset < image.bytes.length; offset += blockSize) {
        final end = math.min(offset + blockSize, image.bytes.length);
        final block = Uint8List.sublistView(image.bytes, offset, end);
        for (var packetOffset = 0;
            packetOffset < block.length;
            packetOffset += packetSize) {
          final packetEnd = math.min(packetOffset + packetSize, block.length);
          await _packet!.write(
            Uint8List.sublistView(block, packetOffset, packetEnd),
            withoutResponse: true,
          );
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        final crc = Rtl87x3gFirmwareImage.blockChecksum(block);
        final check = Uint8List(4);
        final data = ByteData.sublistView(check);
        data.setUint16(0, block.length, Endian.little);
        data.setUint16(2, crc, Endian.little);
        final response = await _command(
          _opReportBufferCrc,
          check,
          expectedOpcode: _opReportBufferCrc,
          expectedLength: 7,
        );
        final confirmed =
            ByteData.sublistView(response).getUint32(3, Endian.little);
        if (confirmed != end) {
          throw StateError('设备确认偏移 $confirmed，预期 $end');
        }
        _emit(
          sessionId,
          message: '正在传输固件',
          progress: end * 100 / image.imageSize,
        );
      }

      _emit(sessionId, message: '正在校验固件', phase: 'validating', progress: 100);
      final valid = Uint8List(3);
      ByteData.sublistView(valid).setUint16(0, image.imageId, Endian.little);
      valid[2] = 1;
      await _command(
        _opValidFw,
        valid,
        expectedOpcode: _opValidFw,
        expectedLength: 3,
      );

      _emit(sessionId, message: '正在激活固件', phase: 'activating');
      try {
        await _control!.write([_opActiveImageReset], withoutResponse: false);
      } catch (error) {
        // ACTIVE_IMAGE_RESET disconnects immediately on this target. WinRT and
        // Android may report the resulting GATT operation as cancelled.
        debugPrint('RTL87x3G activation write ended with disconnect: $error');
      }
      _emit(sessionId, message: '设备正在重启', phase: 'rebooting');
      if (_device?.isConnected == true) {
        try {
          await _device!.connectionState
              .firstWhere((s) => s == BluetoothConnectionState.disconnected)
              .timeout(const Duration(seconds: 20));
        } on TimeoutException {
          // Completion is still verified by the app-level post-check.
        }
      }
      _emit(
        sessionId,
        message: 'SDK 报告升级完成，设备版本待核验',
        done: true,
        progress: 100,
        outcome: 'pendingVerification',
      );
    } catch (error) {
      _emit(
        sessionId,
        message: '升级失败：$error',
        done: true,
        outcome: 'failed',
        errorType: -1,
        errorCode: -1,
      );
    } finally {
      _running = false;
      _prepared = false;
      await _cleanupConnection();
    }
  }

  Future<void> _switchToOtaMode() async {
    final switchCharacteristic = _otaEnterCharacteristic;
    final deviceId = _normalDeviceId;
    if (switchCharacteristic == null || deviceId == null) {
      throw StateError('设备缺少 OTA 模式切换特征');
    }

    _switchingToOtaMode = true;
    try {
      final device = _device;
      final disconnected = device?.connectionState.firstWhere(
        (s) => s == BluetoothConnectionState.disconnected,
      );
      try {
        await switchCharacteristic.write([0x01], withoutResponse: true);
      } catch (error) {
        debugPrint('RTL87x3G FFD1 switch write ended with disconnect: $error');
      }
      if (device?.isConnected == true) {
        try {
          await disconnected!.timeout(const Duration(seconds: 20));
        } on TimeoutException {
          throw StateError('设备未在切换 OTA 模式后断开');
        }
      }
      await _cleanupConnection();
      await Future<void>.delayed(const Duration(seconds: 3));

      _device = await _findOtaDevice(deviceId);
      _ownsConnection = true;
      await _device!.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 30),
      );
      final services = await _device!.discoverServices();
      _packet = _findCharacteristic(services, _dfuPacket);
      _control = _findCharacteristic(services, _dfuControl);
      _mtu = await negotiatePlatformMtu(_device!.remoteId, desired: 247);
      try {
        final info = _findCharacteristic(services, _deviceInfo);
        final rawInfo = Uint8List.fromList(await info.read());
        if (rawInfo.length >= 8) {
          final reportedMtu =
              ByteData.sublistView(rawInfo).getUint16(6, Endian.little);
          if (reportedMtu > kMinAttMtu && reportedMtu <= kMaxAttMtu) {
            _mtu = reportedMtu;
          }
        }
      } catch (_) {}
      _controlNotifications = _control!.onValueReceived.listen((value) {
        final reply = _reply;
        if (reply != null && !reply.isCompleted) {
          reply.complete(Uint8List.fromList(value));
        }
      });
      await _control!.setNotifyValue(true);
      _listenConnectionState();
    } finally {
      _switchingToOtaMode = false;
    }
  }

  Future<BluetoothDevice> _findOtaDevice(String normalDeviceId) async {
    await FlutterBluePlus.stopScan();
    final found = Completer<BluetoothDevice>();
    final started = DateTime.now();
    final identity = _addressBytes(normalDeviceId);
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        if (result.timeStamp.isBefore(started) || found.isCompleted) continue;
        final advertisement = result.advertisementData;
        final manufacturer = advertisement.manufacturerData[_otaManufacturerId];
        final identityMatch = manufacturer != null &&
            identity.isNotEmpty &&
            _identityMatches(manufacturer, identity);
        final named = advertisement.advName == 'BeTgt' ||
            result.device.platformName == 'BeTgt';
        final dfuService = advertisement.serviceUuids.any(
          (uuid) => uuid.str128.toLowerCase() == _dfuService,
        );
        if (identityMatch || (named && dfuService)) {
          found.complete(result.device);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 45));
      return await found.future.timeout(const Duration(seconds: 45));
    } finally {
      await subscription.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  List<int> _addressBytes(String value) {
    final hex = value.replaceAll(RegExp('[^0-9a-fA-F]'), '');
    if (hex.length != 12) return const [];
    return List<int>.generate(
      6,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  bool _identityMatches(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    var direct = true;
    var reversed = true;
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) direct = false;
      if (actual[i] != expected[expected.length - 1 - i]) reversed = false;
    }
    return direct || reversed;
  }

  void _listenConnectionState() {
    unawaited(_connectionState?.cancel());
    _connectionState = _device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          _sessionId != null &&
          _ownsConnection &&
          !_switchingToOtaMode) {
        _emit(_sessionId!, message: '设备已断开', disconnected: true, ready: false);
      }
    });
  }

  Future<Uint8List> _command(
    int opcode,
    Uint8List payload, {
    required int expectedOpcode,
    required int expectedLength,
  }) async {
    if (_reply != null) throw StateError('上一个 DFU 指令尚未完成');
    final reply = Completer<Uint8List>();
    _reply = reply;
    try {
      await _control!.write([opcode, ...payload], withoutResponse: false);
      return await _awaitReply(
        expectedOpcode,
        expectedLength,
        const Duration(seconds: 30),
      );
    } finally {
      _reply = null;
    }
  }

  Future<Uint8List> _awaitReply(
    int opcode,
    int expectedLength,
    Duration timeout,
  ) async {
    final current = _reply;
    if (current == null) throw StateError('DFU 响应状态无效');
    var reply = current;
    while (true) {
      final response = await reply.future.timeout(timeout);
      if (response.length < 3 ||
          response[0] != _notifyOpcode ||
          response[1] != opcode) {
        if (reply.isCompleted) {
          reply = Completer<Uint8List>();
          _reply = reply;
        }
        continue;
      }
      if (response.length != expectedLength) {
        throw StateError('DFU 响应长度错误：${response.length}，预期 $expectedLength');
      }
      if (response[2] != _success) {
        throw StateError(
          '设备拒绝 DFU 指令 0x${opcode.toRadixString(16)}：'
          '0x${response[2].toRadixString(16)}',
        );
      }
      return response;
    }
  }

  BluetoothCharacteristic _findCharacteristic(
    List<BluetoothService> services,
    String uuid,
  ) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.str128.toLowerCase() == uuid) {
          return characteristic;
        }
      }
    }
    throw StateError('设备缺少 OTA 特征 $uuid');
  }

  void _emit(
    String sessionId, {
    required String message,
    bool? ready,
    bool? done,
    bool? disconnected,
    num? progress,
    String? phase,
    String? outcome,
    int? errorType,
    int? errorCode,
  }) {
    if (_events.isClosed || sessionId != _sessionId) return;
    _events.add({
      'sessionId': sessionId,
      'message': message,
      if (ready != null) 'ready': ready,
      if (done != null) 'done': done,
      if (disconnected != null) 'disconnected': disconnected,
      if (progress != null) 'progress': progress,
      if (phase != null) 'phase': phase,
      if (outcome != null) 'outcome': outcome,
      if (errorType != null) 'errorType': errorType,
      if (errorCode != null) 'errorCode': errorCode,
    });
  }

  @override
  Future<void> close() async {
    if (_running) throw StateError('升级进行中，无法关闭会话');
    if (_closing) throw StateError('OTA 正在关闭');
    _closing = true;
    try {
      await _cleanupConnection();
      _prepared = false;
    } finally {
      _closing = false;
    }
  }

  Future<void> _cleanupConnection() async {
    final reply = _reply;
    if (reply != null && !reply.isCompleted) {
      reply.completeError(StateError('OTA 连接已关闭'));
    }
    _reply = null;
    await _controlNotifications?.cancel();
    _controlNotifications = null;
    await _connectionState?.cancel();
    _connectionState = null;
    final device = _device;
    final control = _control;
    _packet = null;
    _control = null;
    _otaEnterCharacteristic = null;
    _device = null;
    _ownsConnection = false;
    if (device != null && device.isConnected) {
      try {
        if (control != null) await control.setNotifyValue(false);
      } catch (_) {}
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }
}
