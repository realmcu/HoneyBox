import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'm2_simulation_lab_page.dart';
import 'm3_connection_page.dart';

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
    return Scaffold(
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
          const SizedBox(height: 8),
          Text(
            'M2 实验室与 M3 连接验收可独立使用；完整调试工具在 M6。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
