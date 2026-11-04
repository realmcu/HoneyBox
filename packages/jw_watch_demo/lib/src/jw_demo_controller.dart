import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// HoneyBox-side composition of public JW SDK objects.
///
/// This controller never writes GATT bytes or imports transport packages; it
/// only coordinates the public scanner, session, and identity APIs.
///
/// Scan result updates use [scanDevices] so high-frequency BLE advertisements
/// coalesce to at most one UI refresh per frame.
class JWDemoController extends ChangeNotifier {
  JWDemoController({JWWatch? watch}) : _watch = watch ?? JWWatch() {
    _subscriptions.add(_watch.scanResults.listen((devices) {
      _devices = devices;
      _scheduleScanUiUpdate();
    }));
    _subscriptions.add(_watch.scanErrors.listen((error) {
      sheetError.value = error;
      scanActive.value = _watch.isScanning;
    }));
  }

  final JWWatch _watch;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final ValueNotifier<List<JWScanDevice>> scanDevices = ValueNotifier(const []);
  final ValueNotifier<bool> scanActive = ValueNotifier(false);
  final ValueNotifier<Object?> sheetError = ValueNotifier(null);
  bool _scanUiUpdateScheduled = false;
  bool _uiNotifyScheduled = false;

  List<JWScanDevice> _devices = const [];
  JWWatchSession? _session;
  JWIdentityStore? _identityStore;
  JWSessionState _state = const JWSessionState();
  Object? _error;
  bool _disposed = false;
  final _sessionLog = <String>[];

  List<JWScanDevice> get devices => scanDevices.value;
  JWSessionState get state => _state;
  Object? get error => _error ?? sheetError.value;
  bool get isScanning => scanActive.value;
  bool get isInitialized => _watch.isInitialized;
  bool get isConnecting => _connecting;
  List<String> get sessionLog => List.unmodifiable(_sessionLog);
  bool _connecting = false;
  JWScanDevice? _connectingDevice;

  Listenable get scanListenable =>
      Listenable.merge([scanDevices, scanActive, sheetError]);

  JWScanDevice? get connectingDevice => _connectingDevice;

  /// Clears stale scan rows when opening the connection page.
  void resetConnectionScanUi() {
    clearScanResults();
    _error = null;
    sheetError.value = null;
  }

  void clearScanResults() {
    _devices = const [];
    scanDevices.value = const [];
  }

  void _scheduleScanUiUpdate() {
    if (_disposed || _scanUiUpdateScheduled) return;
    _scanUiUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scanUiUpdateScheduled = false;
      if (_disposed) return;
      scanDevices.value = List.unmodifiable(_devices);
      scanActive.value = _watch.isScanning;
    });
  }

  void _publishScanUiNow() {
    _scanUiUpdateScheduled = false;
    if (_disposed) return;
    scanDevices.value = List.unmodifiable(_devices);
    scanActive.value = _watch.isScanning;
  }

  void _notifyUi() {
    if (_disposed || _uiNotifyScheduled) return;
    _uiNotifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _uiNotifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> startScan() async {
    sheetError.value = null;
    try {
      if (!isInitialized) {
        throw StateError('JW SDK must be initialized before scanning.');
      }
      await _ensurePermissions();
      await _watch.stopScan();
      clearScanResults();
      scanActive.value = true;
      await _watch.startScan();
      _publishScanUiNow();
    } catch (error) {
      scanActive.value = _watch.isScanning;
      sheetError.value = error;
    }
  }

  Future<void> initialize() async {
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await _watch.initialize();
    } catch (error) {
      _error = error;
      sheetError.value = error;
    }
    _notifyUi();
  }

  Future<void> stopScan() async {
    try {
      await _watch.stopScan();
    } finally {
      scanActive.value = false;
      _publishScanUiNow();
    }
  }

  Future<bool> connect(JWScanDevice device) async {
    if (_connecting) return false;
    if (_state.isConnected) return true;
    if (!isInitialized) {
      final error = StateError('JW SDK must be initialized before connecting.');
      _error = error;
      sheetError.value = error;
      _notifyUi();
      return false;
    }
    _connecting = true;
    _connectingDevice = device;
    clearScanResults();
    _notifyUi();
    await stopScan();
    await _session?.dispose();
    _sessionLog.clear();
    _session = _watch.createSession(device);
    _subscriptions.add(_session!.states.listen((state) {
      _state = state;
      _recordState(state);
      _notifyUi();
    }));
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await _session!.connect();
      return _state.isConnected;
    } catch (error) {
      _error = error;
      sheetError.value = error;
      _notifyUi();
      return false;
    } finally {
      _connecting = false;
      _connectingDevice = null;
      _notifyUi();
    }
  }

  Future<void> login() => _runSession((session) async {
        await session.login(await _identity());
      });

  Future<void> bindFirstTime({required bool confirmed}) =>
      _runSession((session) async {
        await session.bindFirstTime(await _identity(), confirmed: confirmed);
      });

  Future<void> unbind({required bool confirmed}) =>
      _runSession((session) => session.unbind(confirmed: confirmed));

  Future<void> readDeviceInfo() =>
      _runSession((session) => session.readDeviceInfo());

  Future<void> readDeviceDetails() =>
      _runSession((session) => session.readDeviceDetails());

  Future<void> readDeviceFeatures() =>
      _runSession((session) => session.readDeviceFeatures());

  Future<void> disconnect() async {
    final session = _session;
    _session = null;
    _state = const JWSessionState(phase: JWSessionPhase.disconnected);
    await session?.dispose();
    _notifyUi();
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (scan.isGranted && connect.isGranted) return;
    if (!(await Permission.locationWhenInUse.request()).isGranted) {
      throw StateError('请授予蓝牙/定位权限以扫描 JW 设备');
    }
  }

  Future<JWIdentity> _identity() async {
    if (_identityStore == null) {
      final directory = await getApplicationSupportDirectory();
      _identityStore = JWIdentityStore(File(
          '${directory.path}${Platform.pathSeparator}jw_identity_v1.json'));
    }
    return _identityStore!.loadOrCreate();
  }

  Future<void> _runSession(
      Future<void> Function(JWWatchSession session) operation) async {
    final session = _session;
    if (session == null) {
      _error = StateError('请先连接 JW 设备');
      sheetError.value = _error;
      _notifyUi();
      return;
    }
    _error = null;
    sheetError.value = null;
    _notifyUi();
    try {
      await operation(session);
    } catch (error) {
      _error = error;
      sheetError.value = error;
      _notifyUi();
    }
  }

  void _recordState(JWSessionState state) {
    final message = switch (state.phase) {
      JWSessionPhase.connecting => '正在连接设备',
      JWSessionPhase.connected => '设备已连接',
      JWSessionPhase.loggingIn => '正在登录',
      JWSessionPhase.ready => '登录完成',
      JWSessionPhase.loginRejected => '登录被拒绝，需要首次绑定',
      JWSessionPhase.disconnected => '设备已断开',
      JWSessionPhase.failed => '会话失败：${state.error}',
      _ => null,
    };
    if (message == null ||
        (_sessionLog.isNotEmpty && _sessionLog.last == message)) {
      return;
    }
    _sessionLog.add(message);
    if (_sessionLog.length > 12) _sessionLog.removeAt(0);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_session?.dispose());
    unawaited(_watch.dispose());
    scanDevices.dispose();
    scanActive.dispose();
    sheetError.dispose();
    super.dispose();
  }
}
