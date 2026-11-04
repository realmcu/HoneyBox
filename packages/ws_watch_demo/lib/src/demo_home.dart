import 'package:flutter/material.dart';
import 'package:watch_lab_ui/watch_lab_ui.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'debug/debug_scope.dart';
import 'demo_raw_sheet.dart';

import 'm2_simulation_lab_page.dart';
import 'm3_connection_page.dart';
import 'm4_settings_page.dart';
import 'm5_history_page.dart';

/// WS Watch Lab home — embedded in HoneyBox [WatchLabAppRoot] WS tab or standalone app.
class WSWatchDemoHome extends StatefulWidget {
  const WSWatchDemoHome({
    super.key,
    this.config = const WSConfig(),
    this.showAppBar = true,
  });

  final WSConfig config;
  final bool showAppBar;

  @override
  State<WSWatchDemoHome> createState() => _WSWatchDemoHomeState();
}

class _WSWatchDemoHomeState extends State<WSWatchDemoHome> {
  late final WSWatch _watch = WSWatch(config: widget.config);

  WSConfig get _pageConfig => WSConfig(
        simulationEnabled: true,
        autoReconnect: widget.config.autoReconnect,
        phoneSystem: widget.config.phoneSystem,
        databasePath: widget.config.databasePath,
        link: widget.config.link,
        session: widget.config.session,
        sync: widget.config.sync,
        connectTimeouts: widget.config.connectTimeouts,
        logger: widget.config.logger,
        logLevel: widget.config.logLevel,
      );

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DemoDebugScaffold(
      watch: _watch,
      appBar: widget.showAppBar ? AppBar(title: const Text('WS Watch Lab')) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('SDK 版本'),
              trailing:
                  Text(wsWatchSdkVersion, style: theme.textTheme.bodyLarge),
            ),
          ),
          Card(
            child: StreamBuilder<WSConnectionChange>(
              stream: _watch.stateChanges,
              builder: (context, snapshot) {
                final state = snapshot.data?.current ?? _watch.state;
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('SDK 连接状态'),
                  trailing: Text(state.name, style: theme.textTheme.bodyLarge),
                );
              },
            ),
          ),
          LabCapabilityTile(
            icon: Icons.settings_input_antenna,
            title: '传输诊断',
            subtitle: 'BLE 真机 · WS UART / JW profile · 原始字节',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransportDiagnosticsPage(
                  profileMode: TransportProfileMode.wsUartOnly,
                  title: 'WS 传输诊断',
                ),
              ),
            ),
          ),
          LabCapabilityTile(
            icon: Icons.science_outlined,
            title: '模拟设备实验室',
            subtitle: '内存 WS 设备 · 语言 · 帧日志',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const M2SimulationLabPage(),
              ),
            ),
          ),
          LabCapabilityTile(
            icon: Icons.watch_outlined,
            title: '连接与会话',
            subtitle: 'Simulator · 登录/绑定 · 初始化 · ready',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    M3ConnectionPage(config: _pageConfig),
              ),
            ),
          ),
          LabCapabilityTile(
            icon: Icons.tune,
            title: '设置',
            subtitle: '时间 · 语言 · 显示格式',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => M4SettingsPage(config: _pageConfig),
              ),
            ),
          ),
          LabCapabilityTile(
            icon: Icons.history,
            title: '同步与存储',
            subtitle: '活动 · 心率 · 同步进度 · SQLite',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => M5HistoryPage(config: _pageConfig),
              ),
            ),
          ),
          LabCapabilityTile(
            icon: Icons.bug_report_outlined,
            title: 'Raw / L2 调试',
            subtitle: '右下角 FAB · hex 发送 · 协议表',
            onTap: () => showDemoRawDebugSheet(
              context,
              watch: _watch,
              capture: DemoDebugScope.of(context),
            ),
          ),
          const LabHomeHint(
            text: '按能力层验收 WS SDK；ready 后可用右下角 Raw 发 L2。',
          ),
        ],
      ),
    );
  }
}
