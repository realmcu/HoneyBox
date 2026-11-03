import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'debug/debug_scope.dart';
import 'demo_raw_sheet.dart';

import 'm2_simulation_lab_page.dart';
import 'm3_connection_page.dart';
import 'm4_settings_page.dart';
import 'm5_history_page.dart';

/// 嵌入宿主 App 使用的入口页面，例如 HoneyBox。
///
/// 页面持有一个 [WSWatch] 实例，离开页面时释放。
class WSWatchDemoHome extends StatefulWidget {
  const WSWatchDemoHome({super.key, this.config = const WSConfig()});

  final WSConfig config;

  @override
  State<WSWatchDemoHome> createState() => _WSWatchDemoHomeState();
}

class _WSWatchDemoHomeState extends State<WSWatchDemoHome> {
  late final WSWatch _watch = WSWatch(config: widget.config);

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
      appBar: AppBar(title: const Text('WS Watch')),
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
                  title: const Text('连接状态'),
                  trailing: Text(state.name, style: theme.textTheme.bodyLarge),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('M2 模拟实验室'),
              subtitle: const Text('内存设备 · 语言读写 · 帧日志（非正式连接）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const M2SimulationLabPage(),
                  ),
                );
              },
            ),
          ),
          Card(
              child: ListTile(
            leading: const Icon(Icons.watch_outlined),
            title: const Text('M3 扫描与连接'),
            subtitle: const Text('Simulator · 登录/绑定 · 初始化 · ready'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (context) => M3ConnectionPage(
                    config: WSConfig(
                        simulationEnabled: true,
                        autoReconnect: widget.config.autoReconnect,
                        phoneSystem: widget.config.phoneSystem,
                        databasePath: widget.config.databasePath,
                        link: widget.config.link,
                        session: widget.config.session,
                        connectTimeouts: widget.config.connectTimeouts,
                        logger: widget.config.logger,
                        logLevel: widget.config.logLevel)))),
          )),
          Card(
              child: ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('M4 设置'),
            subtitle: const Text('时间 · 语言 · 显示格式 · 并发修改'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => M4SettingsPage(
                    config: WSConfig(
                        simulationEnabled: true,
                        databasePath: widget.config.databasePath,
                        link: widget.config.link,
                        session: widget.config.session,
                        phoneSystem: widget.config.phoneSystem,
                        connectTimeouts: widget.config.connectTimeouts,
                        logger: widget.config.logger,
                        logLevel: widget.config.logLevel,
                        autoReconnect: widget.config.autoReconnect)))),
          )),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('M5 历史数据'),
                  subtitle: const Text('活动桶 · 心率 · 同步进度 · SQLite 查询与删除'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => M5HistoryPage(
                              config: WSConfig(
                                  simulationEnabled: true,
                                  databasePath: widget.config.databasePath,
                                  phoneSystem: widget.config.phoneSystem,
                                  link: widget.config.link,
                                  session: widget.config.session,
                                  sync: widget.config.sync,
                                  connectTimeouts:
                                      widget.config.connectTimeouts,
                                  logger: widget.config.logger,
                                  logLevel: widget.config.logLevel)))))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Raw 调试'),
                  subtitle: const Text('右下角按钮 · L2 hex 发送 · 可选协议表带入'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => showDemoRawDebugSheet(context,
                      watch: _watch,
                      capture: DemoDebugScope.of(context)))),
          const SizedBox(height: 8),
          Text(
            'M2–M5 各页验收；ready 后点右下角 Raw 按钮发 L2 hex。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
