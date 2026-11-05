import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_content_sheet.dart';
import 'jw_demo_controller.dart';
import 'jw_device_pages.dart';
import 'jw_feature_catalog.dart';
import 'jw_history_pages.dart';
import 'jw_settings_pages.dart';

/// T4.0 navigation shell. T4.1 injects one SDK-owned session into it.
class JWWatchLabHome extends StatefulWidget {
  const JWWatchLabHome({super.key});

  @override
  State<JWWatchLabHome> createState() => _JWWatchLabHomeState();
}

class _JWWatchLabHomeState extends State<JWWatchLabHome> {
  var _selectedIndex = 0;
  late final JWDemoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JWDemoController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showFeature(JWFeatureCatalogEntry entry) {
    if (entry.id == 'settings') {
      openJwSettingsHub(context, _controller);
      return;
    }
    if (entry.id == 'device') {
      openJwDeviceHub(context, _controller);
      return;
    }
    if (entry.id == 'history') {
      openJwHistoryHub(context, _controller);
      return;
    }
    unawaited(
      JwDemoContentSheet.show(
        context,
        title: entry.title,
        subtitle: '公开 API 示例',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.subtitle),
            const SizedBox(height: 16),
            SelectableText(
              entry.example,
              style: JwDemoContentSheet.apiMonospaceStyle,
            ),
            const SizedBox(height: 16),
            Text(
              '该模块将在对应 SDK 能力完成后显示当前设备支持状态、'
              '参数表单、操作结果和事件流。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _openConnectionPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ConnectionPage(
          controller: _controller,
          onConnected: () {
            if (!mounted) return;
            setState(() => _selectedIndex = 0);
          },
        ),
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final page = switch (_selectedIndex) {
          0 =>
            _HomePage(controller: _controller, onConnect: _openConnectionPage),
          1 => _FeaturesPage(
              state: _controller.state,
              onFeatureTap: _showFeature,
            ),
          2 => const _ScenariosPage(),
          _ => _DevicePage(
              state: _controller.state,
              onDisconnect: _controller.disconnect,
            ),
        };
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
              _SessionStatusStrip(
                state: _controller.state,
                onTap: _openConnectionPage,
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: page,
                ),
              ),
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
      },
    );
  }
}

class _SessionStatusStrip extends StatelessWidget {
  const _SessionStatusStrip({required this.state, required this.onTap});

  final JWSessionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected = state.isConnected;
    final label = connected
        ? '${state.device?.name ?? 'JW 设备'} · '
            '${state.isReady ? '已登录' : '已连接'}'
        : state.phase == JWSessionPhase.connecting ||
                state.phase == JWSessionPhase.initializing ||
                state.phase == JWSessionPhase.loggingIn
            ? '正在连接 JW 设备…'
            : '尚未连接设备';
    return InkWell(
      key: const Key('jw.demo.session_status'),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: colors.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(connected ? '设备' : '连接',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.controller, required this.onConnect});
  final JWDemoController controller;
  final VoidCallback onConnect;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late final TextEditingController _userIdController;

  JWDemoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (controller.userId.isEmpty) {
      controller.rememberUserId('123456');
    }
    _userIdController = TextEditingController(text: controller.userId);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  String _readUserId() {
    final value = _userIdController.text.trim();
    if (value.isNotEmpty) {
      controller.rememberUserId(value);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        key: const Key('jw.demo.page.home'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'JW SDK Demo 引导你完成初始化、连接、登录与能力识别。'
            '按下面步骤操作即可；点击每一步可查看公开 API 示例。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Text('首次接入', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _GuideTile(
            '1',
            '初始化 SDK',
            controller.isInitialized ? '已完成' : '初始化后才可扫描和连接设备。',
            keyName: 'jw.demo.guide.initialize',
            actionLabel: controller.isInitialized ? '已初始化' : '初始化',
            onAction: controller.isInitialized ? null : controller.initialize,
            completed: controller.isInitialized,
            code: 'final watch = JWWatch();\nawait watch.initialize();',
          ),
          _GuideTile(
            '2',
            '连接设备',
            !controller.isInitialized
                ? '请先初始化 SDK。'
                : controller.state.isConnected
                    ? '已连接 ${controller.state.device?.name ?? 'JW 设备'}。'
                    : '扫描并连接设备；连接不等同于登录。',
            keyName: 'jw.demo.guide.connect',
            actionLabel: controller.state.isConnected ? '已连接' : '连接设备',
            onAction: controller.state.isConnected
                ? null
                : () async {
                    widget.onConnect();
                  },
            completed: controller.state.isConnected,
            code: '''await watch.startScan();
final session = watch.createSession(device.deviceMac);
await session.connect();''',
          ),
          _GuideTile(
            '3',
            '登录或首次绑定',
            _authenticationDetail(controller.state),
            keyName: 'jw.demo.guide.authenticate',
            actionLabel: _authenticationActionLabel(controller.state),
            onAction: _authenticationAction(controller, _readUserId),
            completed: controller.state.isReady,
            code: '''await session.login(userId);
// If login is rejected:
await session.bindFirstTime(userId, confirmed: true);
// After login succeeds:
await session.unbind(confirmed: true);''',
            detailPanel: _AuthenticationDetailPanel(
              userIdController: _userIdController,
              enabled: controller.state.isConnected,
              onUserIdChanged: controller.rememberUserId,
              error: controller.error,
              sessionLog: controller.sessionLog,
            ),
            loading: controller.state.phase == JWSessionPhase.loggingIn,
          ),
          _GuideTile(
            '4',
            '读取设备信息',
            controller.state.device == null
                ? '可选：读取名称、序列号、固件与硬件（电量单独读取）。'
                : '已读取当前设备的基础信息。',
            keyName: 'jw.demo.guide.device_info',
            actionLabel: '读取',
            onAction:
                controller.state.isConnected ? controller.readDeviceInfo : null,
            completed: controller.state.device != null,
            code: 'await session.readDeviceInfo();',
            detailPanel: controller.state.device != null
                ? JwDeviceInfoPanel(state: controller.state)
                : null,
          ),
          _GuideTile(
            '5',
            '读取设备功能',
            controller.state.functionInfo == null
                ? '读取型号支持的完整功能位列表。'
                : '已读取 ${controller.state.functionInfo!.supported.length} 项设备功能。',
            keyName: 'jw.demo.guide.device_features',
            actionLabel: '读取',
            onAction: controller.state.isConnected
                ? controller.readDeviceFeatures
                : null,
            completed: controller.state.functionInfo != null,
            code: '''await session.readDeviceFeatures();
final functions = session.state.functionInfo;
final supportsHeartRate = functions?.supports(JWDeviceFunction.rate);''',
            detailPanel: controller.state.functionInfo == null
                ? null
                : JwDeviceFunctionPanel(
                    functions: controller.state.functionInfo!),
          ),
        ],
      ),
    );
  }
}

class _AuthenticationDetailPanel extends StatelessWidget {
  const _AuthenticationDetailPanel({
    required this.userIdController,
    required this.enabled,
    required this.onUserIdChanged,
    required this.error,
    required this.sessionLog,
  });

  final TextEditingController userIdController;
  final bool enabled;
  final ValueChanged<String> onUserIdChanged;
  final Object? error;
  final List<String> sessionLog;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('jw.demo.user_id_input'),
          controller: userIdController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: onUserIdChanged,
          decoration: const InputDecoration(
            labelText: 'userID',
            helperText: '默认 123456；可改成其他 userID 测试登录失败或首次绑定。',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (error != null && enabled) ...[
          const SizedBox(height: 8),
          Text(
            describeJWDemoError(error!),
            style: TextStyle(color: errorColor),
          ),
        ],
        if (sessionLog.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SessionLogPanel(entries: sessionLog),
        ],
      ],
    );
  }
}

String _authenticationDetail(JWSessionState state) => switch (state.phase) {
      JWSessionPhase.ready =>
        '已登录，可使用需要认证的 SDK 功能。如需更换绑定，可在此解绑（设备会断开连接并清空设备数据）。',
      JWSessionPhase.readOnly => '已解绑，请重新登录或首次绑定。',
      JWSessionPhase.loggingIn => '正在登录，请等待设备回应。',
      JWSessionPhase.loginRejected => '设备拒绝当前身份登录，请确认后首次绑定。',
      _ when state.isConnected => '连接后请登录；仅在登录被拒绝时执行首次绑定。',
      _ => '请先连接设备。',
    };

String _authenticationActionLabel(JWSessionState state) =>
    switch (state.phase) {
      JWSessionPhase.ready => '解绑',
      JWSessionPhase.loggingIn => '正在登录…',
      JWSessionPhase.loginRejected => '首次绑定',
      _ when state.isConnected => '登录',
      _ => '登录',
    };

Future<void> Function()? _authenticationAction(
  JWDemoController controller,
  String Function() readUserId,
) {
  if (controller.state.phase == JWSessionPhase.loggingIn) return null;
  if (controller.state.phase == JWSessionPhase.loginRejected) {
    return () async {
      final userId = readUserId();
      if (userId.isEmpty) return;
      await controller.bindFirstTime(userId, confirmed: true);
    };
  }
  if (controller.state.phase == JWSessionPhase.ready) {
    return () async {
      await controller.unbind(confirmed: true);
    };
  }
  return controller.state.isConnected
      ? () async {
          final userId = readUserId();
          if (userId.isEmpty) return;
          await controller.login(userId);
        }
      : null;
}

class _GuideTile extends StatelessWidget {
  const _GuideTile(
    this.number,
    this.title,
    this.detail, {
    required this.keyName,
    required this.actionLabel,
    this.onAction,
    required this.completed,
    required this.code,
    this.detailPanel,
    this.loading = false,
  });
  final String number;
  final String title;
  final String detail;
  final String keyName;
  final String actionLabel;
  final Future<void> Function()? onAction;
  final bool completed;
  final String code;
  final Widget? detailPanel;
  final bool loading;

  static ButtonStyle _compactFilledStyle(BuildContext context) =>
      FilledButton.styleFrom(
        minimumSize: const Size(72, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );

  static ButtonStyle _compactOutlinedStyle(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(72, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final action = completed
        ? FilledButton(
            key: Key(keyName),
            style: _compactFilledStyle(context),
            onPressed: onAction == null ? null : () => unawaited(onAction!()),
            child: Text(actionLabel),
          )
        : OutlinedButton(
            key: Key(keyName),
            style: _compactOutlinedStyle(context),
            onPressed: onAction == null ? null : () => unawaited(onAction!()),
            child: Text(actionLabel),
          );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => unawaited(
              JwDemoContentSheet.showApiExample(
                context,
                stepTitle: title,
                code: code,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          completed ? colors.primary : colors.primaryContainer,
                      foregroundColor: completed
                          ? colors.onPrimary
                          : colors.onPrimaryContainer,
                      child: Text(number),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(detail, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    action,
                  ],
                ),
              ),
            ),
          ),
          if (detailPanel != null) ...[
            const Divider(height: 1),
            Padding(
              key: Key('$keyName.details'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: detailPanel!,
            ),
          ],
          if (loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _SessionLogPanel extends StatelessWidget {
  const _SessionLogPanel({required this.entries});
  final List<String> entries;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(entry),
            ),
        ],
      );
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.state, required this.onFeatureTap});
  final JWSessionState state;
  final ValueChanged<JWFeatureCatalogEntry> onFeatureTap;

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.features'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('功能中心', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(state.features.isEmpty
              ? '连接设备后，将显示当前型号报告的能力状态。'
              : '以下状态来自当前已连接设备的能力报告。'),
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
                  trailing: _FeatureAvailability(
                    entry: entry,
                    supports: [
                      for (final feature in entry.features)
                        state.features[feature],
                    ],
                  ),
                  onTap: () => onFeatureTap(entry),
                ),
              ),
            ),
        ],
      );
}

class _FeatureAvailability extends StatelessWidget {
  const _FeatureAvailability({
    required this.entry,
    required this.supports,
  });

  final JWFeatureCatalogEntry entry;
  final List<JWFeatureSupport?> supports;

  static const _demoReadyIds = {'device', 'settings', 'history'};

  @override
  Widget build(BuildContext context) {
    if (_demoReadyIds.contains(entry.id)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('可用', style: Theme.of(context).textTheme.labelSmall),
          const Icon(Icons.chevron_right),
        ],
      );
    }
    final values = supports.whereType<JWFeatureSupport>().toList();
    final label = values.isEmpty
        ? '连接后识别'
        : values.any((value) => value.isSupported)
            ? '部分支持'
            : '不支持';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const Icon(Icons.chevron_right),
      ],
    );
  }
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
  const _DevicePage({required this.state, required this.onDisconnect});

  final JWSessionState state;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('jw.demo.page.device'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('当前设备', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(state.isConnected
                  ? Icons.watch_outlined
                  : Icons.watch_off_outlined),
              title: Text(state.device?.name ??
                  (state.phase == JWSessionPhase.idle ? '尚未连接设备' : 'JW 设备')),
              subtitle: Text(state.device == null
                  ? '连接后显示设备信息、身份、固件、能力和会话状态。'
                  : '序列号 ${state.device?.serialNumber ?? '未知'}\n'
                      '固件 ${state.device?.firmware ?? '未知'} · '
                      '硬件 ${state.device?.hardware ?? '未知'} · '
                      '电量 ${state.device?.battery?.toString() ?? '未知'}%'),
              isThreeLine: state.device != null,
              trailing: state.phase != JWSessionPhase.idle &&
                      state.phase != JWSessionPhase.disconnected
                  ? TextButton(
                      onPressed: onDisconnect,
                      child: const Text('断开'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text('事件', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(state.error == null ? '暂无会话事件' : '最近会话错误'),
              subtitle: Text(state.error == null
                  ? '连接、登录和设备信息读取的结果会显示在首页引导中。'
                  : describeJWDemoError(state.error!)),
            ),
          ),
        ],
      );
}

class _ConnectionPage extends StatefulWidget {
  const _ConnectionPage({
    required this.controller,
    required this.onConnected,
  });

  final JWDemoController controller;
  final VoidCallback onConnected;

  @override
  State<_ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<_ConnectionPage> {
  JWDemoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.resetConnectionScanUi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.autoStartScanOnConnectionPage());
    });
  }

  @override
  void dispose() {
    unawaited(controller.stopScan());
    super.dispose();
  }

  Future<void> _finishConnect(JWScanDevice device) async {
    final connected = await controller.connect(device);
    if (!mounted || !connected) return;
    widget.onConnected();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接设备')),
      body: ListenableBuilder(
        listenable: Listenable.merge([controller, controller.scanListenable]),
        builder: (context, _) {
          if (controller.isConnecting) {
            return _ConnectionInProgressView(
              device: controller.connectingDevice,
            );
          }

          final devices = controller.devices;
          return CustomScrollView(
            key: const Key('jw.demo.connection_page'),
            slivers: [
              SliverToBoxAdapter(
                child: _ConnectionScanHeader(controller: controller),
              ),
              if (controller.state.isConnected)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      '已连接 ${controller.state.device?.name ?? 'JW 设备'}。',
                    ),
                  ),
                )
              else if (devices.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Text(
                      controller.isScanning
                          ? '正在扫描附近的 JW 设备…'
                          : '已具备权限时将自动扫描；否则请点击下方「扫描」并授权',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList.separated(
                    itemCount: devices.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _ScanDeviceTile(
                        device: device,
                        onConnect: () => _finishConnect(device),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionInProgressView extends StatelessWidget {
  const _ConnectionInProgressView({required this.device});

  final JWScanDevice? device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = device?.name;
    final label = name == null || name.isEmpty ? 'JW 设备' : name;
    final id = device?.deviceMac;
    return Center(
      key: const Key('jw.demo.connection_in_progress'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('正在连接', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.titleMedium),
            if (id != null) ...[
              const SizedBox(height: 4),
              Text(
                id,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '请保持设备靠近手机。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionScanHeader extends StatelessWidget {
  const _ConnectionScanHeader({required this.controller});

  final JWDemoController controller;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final sheetError = controller.sheetError.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('扫描结果仅包含 JW 服务或已知广播特征的设备。'),
          const SizedBox(height: 12),
          if (!controller.isInitialized) ...[
            Text(
              '请先在首页完成 SDK 初始化。',
              style: TextStyle(color: errorColor),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const Key('jw.demo.scan'),
            onPressed: !controller.isInitialized || controller.isConnecting
                ? null
                : controller.state.isConnected
                    ? () => unawaited(controller.disconnect())
                    : controller.isScanning
                        ? () => unawaited(controller.stopScan())
                        : () => unawaited(controller.startScan()),
            icon: Icon(
              controller.state.isConnected
                  ? Icons.bluetooth_disabled
                  : controller.isScanning
                      ? Icons.stop
                      : Icons.search,
            ),
            label: Text(
              controller.state.isConnected
                  ? '断开连接'
                  : controller.isScanning
                      ? '停止'
                      : '扫描',
            ),
          ),
          if (controller.state.isConnected) ...[
            const SizedBox(height: 12),
            Text('已连接 ${controller.state.device?.name ?? 'JW 设备'}'),
          ],
          if (sheetError != null) ...[
            const SizedBox(height: 12),
            Text(describeJWDemoError(sheetError),
                style: TextStyle(color: errorColor)),
          ] else if (controller.error != null &&
              controller.error != sheetError) ...[
            const SizedBox(height: 12),
            Text(
              describeJWDemoError(controller.error!),
              style: TextStyle(color: errorColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanDeviceTile extends StatelessWidget {
  const _ScanDeviceTile({
    required this.device,
    required this.onConnect,
  });

  final JWScanDevice device;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    final title = device.name.isEmpty ? '未命名 JW 设备' : device.name;
    final theme = Theme.of(context);
    return Padding(
      key: Key('jw.demo.device.${device.deviceMac}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${device.deviceMac} · RSSI ${device.rssi}',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => unawaited(onConnect()),
              child: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }
}
