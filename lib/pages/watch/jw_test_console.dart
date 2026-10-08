import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/jw_device_provider.dart';
import '../../services/jw/jw_device_repository.dart';
import 'jw_history_page.dart';
import 'jw_test_console_catalog.dart';
import 'jw_test_console_controller.dart';
import 'jw_test_console_forms.dart';

class JwSdkTestConsole extends ConsumerWidget {
  final String deviceId;
  const JwSdkTestConsole({super.key, required this.deviceId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(jwDeviceProvider);
    final repository = ref.watch(jwDeviceProvider.notifier).repository;
    if (repository == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('SDK 手动测试')),
          body: const Center(child: Text('设备会话不可用，请重新连接。')));
    }
    return _SessionConsole(
        key: ObjectKey(repository), repository: repository, deviceId: deviceId);
  }
}

class _SessionConsole extends StatefulWidget {
  final JwDeviceRepository repository;
  final String deviceId;
  const _SessionConsole(
      {super.key, required this.repository, required this.deviceId});
  @override
  State<_SessionConsole> createState() => _SessionConsoleState();
}

class _SessionConsoleState extends State<_SessionConsole> {
  late final JwTestConsoleController _controller;
  final _drafts = <String, Map<String, String>>{};
  int _category = 0;
  @override
  void initState() {
    super.initState();
    _controller = JwTestConsoleController(widget.repository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _browseHistory() {
    final String key;
    try {
      key = widget.repository.historyDeviceKey;
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('历史归属不可用：$error')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/jw-history-records'),
        builder: (_) => JwHistoryRecordsPage(deviceKey: key)));
  }

  Future<void> _resetCursor() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('重置全部设备历史读取游标？'),
                content: const SingleChildScrollView(
                    child: Text(
                        '只重置设备读取位置，保留手机已保存记录并继续去重。仅能重读设备仍保留的数据，已经覆盖或删除的数据不能恢复。此操作作用于全部类型；成功 ACK 只证明提交，之后需手动再次同步。')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('重置全部游标'))
                ]));
    if (!mounted || confirmed != true) return;
    await _controller.run('history-reset', {});
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final c = _controller, state = c.state, info = state.info;
        return Scaffold(
            appBar: AppBar(title: const Text('SDK 手动测试')),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              Text(
                  '本会话：${info?.name ?? widget.repository.platformDeviceKey ?? '未知设备'} · ${state.phase.name}'),
              Text(
                  '缓存设备信息：${info?.firmware ?? '未知固件'} / ${info?.hardware ?? '未知硬件'}，电量 ${info?.battery ?? '未读取'}%；以下按钮按项新读取。'),
              if (state.capabilities != null)
                Text(
                    '功能位 ${state.capabilities!.rawHex} · 工厂开关 ${state.capabilities!.factorySwitchRaw}'),
              if (state.operationError != null)
                Text('本次操作失败：${state.operationError}。若命令已发出，应用状态未确认，请重新连接后核对。',
                    key: const Key('jw-console-session-error')),
              if (c.active != null || state.operationInProgress)
                const LinearProgressIndicator(),
              const SizedBox(height: 12),
              InputDecorator(
                  decoration: const InputDecoration(
                      labelText: '测试分类', border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                          key: const Key('jw-console-category'),
                          isExpanded: true,
                          value: _category,
                          items: [
                            for (var i = 0; i < jwConsoleCategories.length; i++)
                              DropdownMenuItem(
                                  value: i, child: Text(jwConsoleCategories[i]))
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          }))),
              const SizedBox(height: 12),
              if (_category == 1) ...[
                Text(state.lastHeartRate == null
                    ? '等待有效实时心率通知'
                    : '${state.lastHeartRate!.bpm} BPM（typed 实时心率）'),
                const Text('血氧 / 温度：只显示命令或模式结果；实际数值请查看保存的历史记录。'),
              ],
              if (_category == 4)
                Text(
                    '实际支持 UK 类型缓存：${widget.repository.getCachedSupportedUkSportTypes()?.join(', ') ?? '尚未读取'}；未知代码按数字显示。'),
              for (final op in jwConsoleOperations
                  .where((op) => op.category == _category && _category != 7))
                JwConsoleOperationCard(
                    key: ValueKey(op.id),
                    operation: op,
                    controller: c,
                    draft: _drafts.putIfAbsent(op.id, () => {})),
              if (_category == 7) ...[
                const Text('设备同步按完整轮次执行；类型 / 日期仅用于浏览本地已保存记录。'),
                JwHistoryOverview(
                    state: state,
                    onSync: () => c.run('history-sync', {}),
                    onCancel: () => widget.repository.cancelHistory(),
                    onBrowse: _browseHistory),
                const SizedBox(height: 12),
                OutlinedButton(
                    key: const Key('jw-console-history-reset'),
                    onPressed: c.disabledReason('history-reset') == null
                        ? _resetCursor
                        : null,
                    child: const Text('重置全部设备历史读取游标')),
                Text(c.disabledReason('history-reset') ??
                    '保留手机记录；重置后需手动再次同步，不能恢复已覆盖的数据。'),
                for (final id in ['history-sync', 'history-reset'])
                  if (c.results[id] != null)
                    SelectableText(
                        '${c.results[id]!.success ? '结果' : '失败'}：${c.results[id]!.message}',
                        key: Key('jw-console-result-$id')),
              ],
              const Divider(height: 28),
              ExpansionTile(
                  title: Text('本会话诊断日志（${c.logs.length}/80）'),
                  children: [
                    for (final line in c.logs.reversed)
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: SelectableText(line))
                  ]),
            ]));
      });
}
