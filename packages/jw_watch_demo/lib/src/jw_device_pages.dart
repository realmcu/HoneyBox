import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_content_sheet.dart';
import 'jw_demo_controller.dart';
import 'jw_device_function_labels.dart';

void openJwDeviceHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWDeviceHubPage(controller: controller),
      ),
    ),
  );
}

class JWDeviceHubPage extends StatefulWidget {
  const JWDeviceHubPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JWDeviceHubPage> createState() => _JWDeviceHubPageState();
}

class _JWDeviceHubPageState extends State<JWDeviceHubPage> {
  bool _infoLoading = false;
  bool _batteryLoading = false;
  bool _featuresLoading = false;
  Object? _infoError;
  Object? _batteryError;
  Object? _featuresError;

  JWDemoController get controller => widget.controller;

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
        final functionInfo = controller.state.functionInfo;
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
                      '点标题「· API」可查看公开调用示例。',
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
                            JwDeviceIdentityFieldList(device: device),
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
                          if (device?.battery != null) ...[
                            const Divider(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('电量'),
                              trailing: Text('${device!.battery}%'),
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
final functions = session.state.functionInfo;
final supportsHeartRate = functions?.supports(JWDeviceFunction.rate);''',
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
                            JwDeviceFunctionPanel(functions: functionInfo),
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
          describeJWDemoError(error),
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

bool _hasIdentityFields(JWDeviceInfo device) =>
    device.name != null ||
    device.serialNumber != null ||
    device.firmware != null ||
    device.hardware != null;

/// GATT identity fields only (no battery).
class JwDeviceIdentityFieldList extends StatelessWidget {
  const JwDeviceIdentityFieldList({super.key, required this.device});

  final JWDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    String text(String? value) => value == null || value.isEmpty ? '未提供' : value;
    return Column(
      children: [
        _infoTile(context, '名称', text(device.name)),
        _infoTile(context, '序列号', text(device.serialNumber)),
        _infoTile(context, '固件', text(device.firmware)),
        _infoTile(context, '硬件', text(device.hardware)),
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
class JwDeviceInfoFieldList extends StatelessWidget {
  const JwDeviceInfoFieldList({super.key, required this.device});

  final JWDeviceInfo device;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JwDeviceIdentityFieldList(device: device),
          if (device.battery != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('电量'),
              trailing: Text('${device.battery}%'),
            ),
        ],
      );
}

class JwDeviceInfoPanel extends StatelessWidget {
  const JwDeviceInfoPanel({super.key, required this.state});

  final JWSessionState state;

  @override
  Widget build(BuildContext context) {
    final device = state.device;
    if (device == null) return const SizedBox.shrink();
    return JwDeviceInfoFieldList(device: device);
  }
}

class JwDeviceFunctionPanel extends StatelessWidget {
  const JwDeviceFunctionPanel({super.key, required this.functions});

  final JWDeviceFunctionInfo functions;

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
    final style = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
    );
    return InkWell(
      onTap: () => unawaited(
        JwDemoContentSheet.showApiExample(
          context,
          stepTitle: title,
          code: apiCode,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$title · API', style: style),
      ),
    );
  }
}
