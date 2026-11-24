import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/ble_provider.dart';
import '../../providers/ota_in_progress_provider.dart';
import '../../providers/watch_ota_result_provider.dart';
import '../../services/ota/ota_session.dart';
import '../../services/ota/ota_target.dart';
import '../launcher/app_catalog.dart';
import 'realtek_ota_page.dart';

const watchRtl87x3gBundledFirmwareAsset =
    'assets/ota/watch_rtl8773g_app_mp.bin';
const watchRtl87x3gBundledFirmwareName = 'Watch 内置固件';

/// Lowers the Realtek MP OTA package bundled in the APK into a file the OTA
/// transport can read. The MP package (not the bare download image) is what
/// the device expects.
Future<String> stageWatchRtl87x3gBundledFirmware({Directory? directory}) async {
  final data = await rootBundle.load(watchRtl87x3gBundledFirmwareAsset);
  final targetDirectory = directory ?? await getTemporaryDirectory();
  final file = File(
    '${targetDirectory.path}${Platform.pathSeparator}watch_rtl87x3g_app_mp.bin',
  );
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}

/// Watch-specific OTA entry. The current Watch is handed over from the normal
/// BLE connection to a bundled RTL8773G MP image without chip selection or a
/// second scan; when the run ends the route pops back to the Watch home page.
class WatchRtl87x3gOtaPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const WatchRtl87x3gOtaPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<WatchRtl87x3gOtaPage> createState() =>
      _WatchRtl87x3gOtaPageState();
}

class _WatchRtl87x3gOtaPageState extends ConsumerState<WatchRtl87x3gOtaPage> {
  String? _firmwarePath;
  Object? _error;
  bool _isJw = false;
  String? _ownerApp;
  bool _finishing = false;
  String? _stage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepareHandoff());
    });
  }

  Future<void> _prepareHandoff() async {
    // Keep the Watch root from popping this route while the normal connection
    // is intentionally released for OTA mode.
    ref.read(otaInProgressProvider.notifier).state = true;
    try {
      final connected = ref.read(connectedDeviceProvider);
      if (connected == null || connected.deviceId != widget.deviceId) {
        throw StateError('当前连接已变化，请返回 Watch 主页重新进入');
      }
      // Remember how the Watch was attached so it can be restored afterwards.
      _isJw = connected.isJw;
      _ownerApp = connected.ownerApp;
      await ref.read(bleNotifierProvider.notifier).disconnect();
      final path = await stageWatchRtl87x3gBundledFirmware();
      if (!mounted) return;
      setState(() => _firmwarePath = path);
    } catch (error) {
      if (!mounted) return;
      ref.read(otaInProgressProvider.notifier).state = false;
      setState(() => _error = error);
    }
  }

  /// Hands the radio back to a normal Watch connection, then returns home with
  /// the result so the tester never lands on a scan page.
  Future<void> _handleFinished(OtaOutcome outcome, String message) async {
    if (_finishing) return;
    _finishing = true;
    if (mounted) setState(() => _stage = '正在重新连接 Watch');
    final reconnected = await _reconnect();
    if (!mounted) return;
    // The Watch home page shows this as a banner. A SnackBar would be replaced
    // by the automatic bind message that follows the reconnect.
    ref.read(watchOtaResultProvider.notifier).state = WatchOtaResult(
      outcome: outcome,
      detail: message,
      reconnected: reconnected,
    );
    ref.read(otaInProgressProvider.notifier).state = false;
    Navigator.of(context).pop(outcome);
  }

  /// A freshly flashed Watch reboots before its normal service is advertised,
  /// so retry instead of surfacing a transient connect failure.
  Future<bool> _reconnect() async {
    final notifier = ref.read(bleNotifierProvider.notifier);
    for (var attempt = 0; attempt < 6; attempt++) {
      if (!mounted) return false;
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return false;
      }
      try {
        final connected = await notifier.connect(
          widget.deviceId,
          widget.deviceName,
          allowJw: _isJw,
          ownerApp: _ownerApp ?? AppId.watch.name,
        );
        if (connected) return true;
      } catch (_) {
        // Retry: the device may still be rebooting into normal mode.
      }
    }
    return false;
  }

  @override
  void dispose() {
    final otaInProgress = ref.read(otaInProgressProvider.notifier);
    Future.microtask(() => otaInProgress.state = false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('RTL8773G OTA')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              '无法准备 Watch 升级：$_error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final path = _firmwarePath;
    if (path == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在准备 Watch 升级'),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_finishing,
      child: Stack(
        children: [
          RealtekOtaPage(
            device: ScanDevice(
              deviceId: widget.deviceId,
              name: widget.deviceName,
              rssi: 0,
            ),
            target: OtaTarget.rtl87x3g,
            initialFirmwarePath: path,
            initialFirmwareName: watchRtl87x3gBundledFirmwareName,
            fixedFirmware: true,
            autoVerify: true,
            onFinished: _handleFinished,
          ),
          // Keep the OTA page mounted while the radio is handed back, so its
          // teardown still owns the transport.
          if (_stage != null)
            Positioned.fill(
              // Material is required: text outside a Material ancestor renders
              // with Flutter's red error style.
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_stage!,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
