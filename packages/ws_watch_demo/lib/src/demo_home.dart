import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'm2_simulation_lab_page.dart';

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
          const SizedBox(height: 8),
          Text(
            '扫描与正式连接将在 M3 加入；完整调试工具在 M6。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
