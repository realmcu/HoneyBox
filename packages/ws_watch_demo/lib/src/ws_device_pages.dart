import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_content_sheet.dart';
import 'ws_demo_controller.dart';
import 'ws_device_function_labels.dart';
import 'compat/ws_demo_compat.dart';

void openJwDeviceHub(BuildContext context, WSDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WSDeviceHubPage(controller: controller),
      ),
    ),
  );
}

class WSDeviceHubPage extends StatefulWidget {
  const WSDeviceHubPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WSDeviceHubPage> createState() => _JWDeviceHubPageState();
}

class _JWDeviceHubPageState extends State<WSDeviceHubPage> {
  bool _infoLoading = false;
  bool _batteryLoading = false;
  bool _featuresLoading = false;
  Object? _infoError;
  Object? _batteryError;
  Object? _featuresError;

  WSDemoController get controller => widget.controller;

  bool get _connected => controller.state.isConnected;

  Future<void> _readInfo() async {
    if (_infoLoading) return;
    setState(() {
      _infoLoading = true;
      _infoError = null;
    });
    try {
      await controller.readDeviceInfo();
    } catch (error) {
      if (mounted) setState(() => _infoError = error);
    } finally {
      if (mounted) setState(() => _infoLoading = false);
    }
  }

  Future<void> _readBattery() async {
    if (_batteryLoading) return;
    setState(() {
      _batteryLoading = true;
      _batteryError = null;
    });
    try {
      await controller.readBattery();
    } catch (error) {
      if (mounted) setState(() => _batteryError = error);
    } finally {
      if (mounted) setState(() => _batteryLoading = false);
    }
  }

  Future<void> _readFeatures() async {
    if (_featuresLoading) return;
    setState(() {
      _featuresLoading = true;
      _featuresError = null;
    });
    try {
      await controller.readDeviceFeatures();
    } catch (error) {
      if (mounted) setState(() => _featuresError = error);
    } finally {
      if (mounted) setState(() => _featuresLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final device = controller.state.device;
        final functionInfo = controller.functionInfo;
        final batteryPercent = controller.batteryPercent;
        return Scaffold(
          appBar: AppBar(title: const Text('设备信息与能力')),
          body: !_connected
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('请先连接设备后再读取信息与功能。'),
                )
              : ListView(
                  key: const Key('jw.demo.device.hub'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '点标题可查看公开 API 调用示例。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _DeviceSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DeviceApiTitle(
                            title: '设备基础信息',
                            apiCode: 'await session.readDeviceInfo();',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('jw.demo.device.info.read'),
                            onPressed: _infoLoading ? null : () => unawaited(_readInfo()),
                            icon: _infoLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(_infoLoading ? '正在读取…' : '读取设备信息'),
                          ),
                          if (_infoError != null)
                            _inlineError(context, _infoError!),
                          if (device != null && _hasIdentityFields(device)) ...[
                            const Divider(height: 24),
                            WsDeviceIdentityFieldList(device: device),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DeviceSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DeviceApiTitle(
                            title: '电量',
                            apiCode: 'final level = await session.readBattery();',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('jw.demo.device.battery.read'),
                            onPressed: _batteryLoading ? null : () => unawaited(_readBattery()),
                            icon: _batteryLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.battery_std_outlined),
                            label: Text(_batteryLoading ? '正在读取…' : '读取电量'),
                          ),
                          if (_batteryError != null)
                            _inlineError(context, _batteryError!),
                          if (batteryPercent != null) ...[
                            const Divider(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('电量'),
                              trailing: Text('$batteryPercent%'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DeviceSectionCard(
                      key: const Key('jw.demo.device.features'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DeviceApiTitle(
                            title: '设备功能',
                            apiCode: '''await session.readDeviceFeatures();
final capabilities = session.state.capabilities;
final supportsHeartRate = functions?.supports(WSDeviceFunction.rate);''',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('jw.demo.device.features.read'),
                            onPressed: _featuresLoading ? null : () => unawaited(_readFeatures()),
                            icon: _featuresLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.list_alt),
                            label: Text(_featuresLoading ? '正在读取…' : '读取设备功能'),
                          ),
                          if (_featuresError != null)
                            _inlineError(context, _featuresError!),
                          if (functionInfo != null) ...[
                            const Divider(height: 24),
                            WsDeviceFunctionPanel(functions: functionInfo),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _inlineError(BuildContext context, Object error) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          describeWSDemoError(error),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}

class _DeviceSectionCard extends StatelessWidget {
  const _DeviceSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child,
        ),
      );
}

bool _hasIdentityFields(WSDeviceInfo device) =>
    device.name != null || device.deviceMac.isNotEmpty;

/// GATT identity fields only (no battery).
class WsDeviceIdentityFieldList extends StatelessWidget {
  const WsDeviceIdentityFieldList({super.key, required this.device});

  final WSDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    String text(String? value) => value == null || value.isEmpty ? '未提供' : value;
    return Column(
      children: [
        _infoTile(context, '名称', text(device.name)),
        _infoTile(context, 'MAC', device.deviceMac),
        if (device.modelId != null)
          _infoTile(
            context,
            '型号 ID',
            '0x${device.modelId!.toRadixString(16).padLeft(4, "0")}',
          ),
        if (device.serialNumber != null && device.serialNumber!.isNotEmpty)
          _infoTile(context, '序列号', device.serialNumber!),
      ],
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      );
}

/// Home guide detail: identity + optional battery when already read.
class WsDeviceInfoFieldList extends StatelessWidget {
  const WsDeviceInfoFieldList({
    super.key,
    required this.device,
    this.batteryPercent,
  });

  final WSDeviceInfo device;
  final int? batteryPercent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WsDeviceIdentityFieldList(device: device),
          if (batteryPercent != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('电量'),
              trailing: Text('$batteryPercent%'),
            ),
        ],
      );
}

class WsDeviceInfoPanel extends StatelessWidget {
  const WsDeviceInfoPanel({super.key, required this.state});

  final WSSessionState state;

  @override
  Widget build(BuildContext context) {
    final device = state.device;
    if (device == null) return const SizedBox.shrink();
    return WsDeviceInfoFieldList(device: device);
  }
}

class WsDeviceFunctionPanel extends StatelessWidget {
  const WsDeviceFunctionPanel({super.key, required this.functions});

  final WSDeviceFunctionInfo functions;

  @override
  Widget build(BuildContext context) {
    final supported = jwSupportedFunctionsSorted(functions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('共 ${supported.length} 项'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final function in supported)
              Chip(label: Text(jwDeviceFunctionLabel(function))),
          ],
        ),
      ],
    );
  }
}

class _DeviceApiTitle extends StatelessWidget {
  const _DeviceApiTitle({
    required this.title,
    required this.apiCode,
  });

  final String title;
  final String apiCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(
        WsDemoContentSheet.showApiExample(
          context,
          stepTitle: title,
          code: apiCode,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(title, style: theme.textTheme.titleMedium),
      ),
    );
  }
}
