import 'package:flutter/material.dart';

import 'jw_feature_catalog.dart';

/// T4.0 navigation shell. T4.1 injects one SDK-owned session into it.
class JWWatchLabHome extends StatefulWidget {
  const JWWatchLabHome({super.key});

  @override
  State<JWWatchLabHome> createState() => _JWWatchLabHomeState();
}

class _JWWatchLabHomeState extends State<JWWatchLabHome> {
  var _selectedIndex = 0;

  void _showFeature(JWFeatureCatalogEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(entry.subtitle),
            const SizedBox(height: 16),
            Text('公开 API 示例', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SelectableText(entry.example,
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 16),
            Text(
              '该模块将在对应 SDK 能力完成后显示当前设备支持状态、'
              '参数表单、操作结果和事件流。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('T4.1 将把扫描、连接、登录/绑定与能力读取接入 jw_watch_sdk。'),
      ),
    );
  }

  void _showDeveloperTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('开发者工具', style: TextStyle(fontSize: 20)),
            SizedBox(height: 8),
            Text('诊断 Console 会作为 HoneyBox 的可选模块装配。'),
            SizedBox(height: 4),
            Text('普通 Demo 不直接写 BLE 字节、读取帧或与 SDK 会话竞争连接。'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(onConnect: _showConnectionInfo),
      _FeaturesPage(onFeatureTap: _showFeature),
      const _ScenariosPage(),
      const _DevicePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('JW SDK Demo'),
        actions: [
          IconButton(
            key: const Key('jw.demo.developer_tools'),
            onPressed: _showDeveloperTools,
            icon: const Icon(Icons.developer_mode_outlined),
            tooltip: '开发者工具',
          ),
        ],
      ),
      body: Column(
        children: [
          const _SessionStatusStrip(),
          Expanded(child: IndexedStack(index: _selectedIndex, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            key: Key('jw.demo.tab.home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            key: Key('jw.demo.tab.features'),
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: '功能',
          ),
          NavigationDestination(
            key: Key('jw.demo.tab.scenarios'),
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '场景',
          ),
          NavigationDestination(
            key: Key('jw.demo.tab.device'),
            icon: Icon(Icons.watch_outlined),
            selectedIcon: Icon(Icons.watch),
            label: '设备',
          ),
        ],
      ),
    );
  }
}

class _SessionStatusStrip extends StatelessWidget {
  const _SessionStatusStrip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('jw.demo.session_status'),
      width: double.infinity,
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled_outlined,
              size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text('尚未连接设备', style: Theme.of(context).textTheme.titleSmall),
          ),
          Text('T4.1 接入', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.home'),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('从第一个功能开始',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('完成连接、登录和能力读取后，即可体验当前设备支持的 SDK 功能。'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('连接设备'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('首次接入', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _GuideTile('1', '初始化 SDK', '配置运行环境、权限和日志策略。'),
          const _GuideTile('2', '扫描、连接并登录', '选择设备并完成登录或首次绑定。'),
          const _GuideTile('3', '读取设备能力', '按当前型号和固件显示可用功能。'),
        ],
      );
}

class _GuideTile extends StatelessWidget {
  const _GuideTile(this.number, this.title, this.detail);
  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(number)),
          title: Text(title),
          subtitle: Text(detail),
        ),
      );
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.onFeatureTap});
  final ValueChanged<JWFeatureCatalogEntry> onFeatureTap;

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.features'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('功能中心', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('每个模块提供 API 用法；T4.1 起将依据真实设备能力开放操作。'),
          const SizedBox(height: 16),
          for (final entry in jwFeatureCatalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  key: Key('jw.demo.feature.${entry.id}'),
                  leading: Icon(entry.icon),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onFeatureTap(entry),
                ),
              ),
            ),
        ],
      );
}

class _ScenariosPage extends StatelessWidget {
  const _ScenariosPage();

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.scenarios'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('场景示例', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('场景只在对应 SDK 流程已真实交付后开放执行。'),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.link_outlined),
              title: Text('首次接入设备'),
              subtitle: Text('初始化 → 扫描 → 连接 → 登录/绑定 → 读取能力'),
              trailing: Chip(label: Text('T4.1')),
            ),
          ),
        ],
      );
}

class _DevicePage extends StatelessWidget {
  const _DevicePage();

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.device'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('当前设备', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.watch_off_outlined),
              title: Text('尚未连接设备'),
              subtitle: Text('连接后显示设备信息、身份、固件、能力和会话状态。'),
            ),
          ),
          const SizedBox(height: 20),
          Text('事件', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('暂无会话事件'),
              subtitle: Text('T4.1 将记录连接、登录、能力读取和设备主动事件。'),
            ),
          ),
        ],
      );
}
