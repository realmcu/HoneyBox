import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/jw_device_provider.dart';
import '../../services/jw/jw_configuration.dart';
import '../../services/jw/jw_models.dart';

class JwObservationPanel extends ConsumerStatefulWidget {
  const JwObservationPanel({super.key});
  @override
  ConsumerState<JwObservationPanel> createState() => _JwObservationPanelState();
}

class _JwObservationPanelState extends ConsumerState<JwObservationPanel> {
  bool _loading = false;
  String? _report, _error;
  Future<void> _observe() async {
    final repository = ref.read(jwDeviceProvider.notifier).repository;
    if (repository == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      const contract = JwConfigurationContract.v101S200;
      final alarms = await repository.readAlarm(contract: contract);
      final permission =
          await repository.checkSpO2MeasureEnable(contract: contract);
      final sports =
          await repository.readSupportDeviceSport(contract: contract);
      final status =
          await repository.queryDeviceSportStatus(contract: contract);
      if (!repository.session.isOpen ||
          !identical(
              repository, ref.read(jwDeviceProvider.notifier).repository)) {
        return;
      }
      final label = switch (status.state) { 0 => '空闲', 1 => '运动中', _ => '已暂停' };
      if (mounted) {
        setState(() {
          _report =
              '闹钟：${alarms.records.length}个\n支持运动：${sports.ukTypes.length}种\n运动状态：$label\n血氧测量：${permission.availableReported ? "设备报告可用" : "设备报告不可用"}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jwDeviceProvider);
    final live = state.phase == JwDevicePhase.loggedIn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('设备功能状态'),
      const SizedBox(height: 8),
      OutlinedButton(
          key: const Key('jw-remaining-observe'),
          onPressed:
              live && !state.operationInProgress && !_loading ? _observe : null,
          child: Text(_loading ? '正在读取…' : '读取闹钟、运动与血氧状态')),
      if (live && _report != null)
        ..._report!.split('\n').map((line) => Text(line)),
      if (live && _error != null) Text('读取失败：$_error'),
      if (!live) const Text('协议登录后可读取功能状态'),
    ]);
  }
}
