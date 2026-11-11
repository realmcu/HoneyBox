import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_data_home_page.dart';
import 'ws_demo_content_sheet.dart';
import 'ws_demo_controller.dart';
import 'ws_demo_last_device_store.dart';
import 'ws_device_pages.dart';
import 'ws_settings_home_page.dart';
import 'compat/ws_demo_compat.dart';

/// JW SDK Demo shell: 首页 / 数据 / 设置；数据与设置 Tab 需会话 `ready`。
class WSWatchLabHome extends StatefulWidget {
  const WSWatchLabHome({super.key});

  @override
  State<WSWatchLabHome> createState() => _JWWatchLabHomeState();
}

class _JWWatchLabHomeState extends State<WSWatchLabHome> {
  static const _tabHome = 0;
  static const _tabData = 1;
  static const _tabSettings = 2;

  var _selectedIndex = _tabHome;
  late final WSDemoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WSDemoController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _sessionReady => _controller.state.isReady;

  void _openConnectionPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ConnectionPage(
          controller: _controller,
          onConnected: () {
            if (!mounted) return;
            setState(() => _selectedIndex = _tabHome);
          },
        ),
      ),
    );
  }

  void _showDeveloperTools() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('开发者工具', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Logcat / Android Studio 过滤：',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 6),
            Text('WSWatchSDK — WIRE / API 协议（与 JW 同级）'),
            Text('WsWatchDemo · WsDemoSync — Demo 同步摘要'),
            SizedBox(height: 8),
            Text('模拟器同样走 L1 帧通道，可对照 Honey cmd/key 与 hex。'),
          ],
        ),
      ),
    );
  }

  bool get _tabsUnlocked => _controller.isInitialized && _sessionReady;

  void _onTabSelected(int index) {
    if (index != _tabHome && !_tabsUnlocked) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildTabBody() {
    if (_selectedIndex != _tabHome && !_tabsUnlocked) {
      return _HomePage(
        controller: _controller,
        onConnect: _openConnectionPage,
      );
    }
    return switch (_selectedIndex) {
      _tabHome => _HomePage(
          controller: _controller,
          onConnect: _openConnectionPage,
        ),
      _tabData => WsDataHomePage(controller: _controller),
      _tabSettings => WsSettingsHomePage(controller: _controller),
      _ => _HomePage(
          controller: _controller,
          onConnect: _openConnectionPage,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('WS SDK Demo'),
            actions: [
              IconButton(
                key: const Key('jw.demo.developer_tools'),
                onPressed: _showDeveloperTools,
                icon: const Icon(Icons.developer_mode_outlined),
                tooltip: '开发者工具',
              ),
            ],
          ),
          body: KeyedSubtree(
            key: ValueKey<String>(
              '$_selectedIndex-${_tabsUnlocked ? 'ready' : 'locked'}',
            ),
            child: _buildTabBody(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onTabSelected,
            destinations: [
              const NavigationDestination(
                key: Key('jw.demo.tab.home'),
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                key: const Key('jw.demo.tab.data'),
                icon: Icon(
                  Icons.insights_outlined,
                  color: _tabsUnlocked
                      ? null
                      : Theme.of(context).disabledColor,
                ),
                selectedIcon: Icon(
                  Icons.insights,
                  color: _tabsUnlocked
                      ? null
                      : Theme.of(context).disabledColor,
                ),
                label: '数据',
                enabled: _tabsUnlocked,
              ),
              NavigationDestination(
                key: const Key('jw.demo.tab.settings'),
                icon: Icon(
                  Icons.tune_outlined,
                  color: _tabsUnlocked
                      ? null
                      : Theme.of(context).disabledColor,
                ),
                selectedIcon: Icon(
                  Icons.tune,
                  color: _tabsUnlocked
                      ? null
                      : Theme.of(context).disabledColor,
                ),
                label: '设置',
                enabled: _tabsUnlocked,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.controller, required this.onConnect});
  final WSDemoController controller;
  final VoidCallback onConnect;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late final TextEditingController _userIdController;
  var _quickConnecting = false;

  WSDemoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (controller.userId.isEmpty) {
      controller.rememberUserId('123456');
    }
    unawaited(controller.loadLastDevice());
    _userIdController = TextEditingController(text: controller.userId);
  }

  Future<void> _quickConnectLast() async {
    if (_quickConnecting ||
        !controller.isInitialized ||
        controller.state.isConnected ||
        controller.isConnecting) {
      return;
    }
    setState(() => _quickConnecting = true);
    try {
      final ok = await controller.connectLastDevice();
      if (!mounted) return;
      if (!ok) {
        final message = controller.error == null
            ? '连接失败，请确认手表在附近后重试。'
            : describeWSDemoError(controller.error!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeWSDemoError(error))),
      );
    } finally {
      if (mounted) setState(() => _quickConnecting = false);
    }
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
            '首页完成初始化、连接与登录后，数据与设置 Tab 才会解锁。'
            '按下面步骤操作；点击每一步可查看公开 API 示例。',
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
            code: 'final watch = WSWatch();\nawait watch.initialize();',
          ),
          _GuideTile(
            '2',
            '连接设备',
            !controller.isInitialized
                ? '请先初始化 SDK。'
                : controller.state.isConnected
                    ? '已连接 ${controller.state.device?.name ?? controller.lastDevice?.name ?? 'JW 设备'}。'
                    : controller.lastDevice != null
                        ? '可连接最近设备，或扫描新设备。'
                        : '扫描并连接设备；连接不等同于登录。',
            keyName: 'jw.demo.guide.connect',
            showTrailingAction:
                !controller.isInitialized || controller.state.isConnected,
            actionLabel: controller.state.isConnected
                ? '已连接'
                : '等待',
            onAction: null,
            completed: controller.state.isConnected,
            code: '''await watch.startScan();
final session = watch.createSession(device.deviceMac);
await session.connect();''',
            detailPanel: controller.isInitialized
                ? _ConnectDeviceStepPanel(
                    lastDevice: controller.lastDevice,
                    connected: controller.state.isConnected,
                    connecting: controller.isConnecting || _quickConnecting,
                    connectedName: controller.state.device?.name,
                    connectedMac: controller.state.device?.deviceMac,
                    onConnectLast: _quickConnectLast,
                    onScan: widget.onConnect,
                  )
                : null,
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
            loading: controller.state.phase == WSSessionPhase.loggingIn,
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
                ? WsDeviceInfoPanel(state: controller.state)
                : null,
          ),
          _GuideTile(
            '5',
            '读取设备功能',
            controller.functionInfo == null
                ? '读取型号支持的完整功能位列表。'
                : '已读取 ${controller.functionInfo!.supported.length} 项设备功能。',
            keyName: 'jw.demo.guide.device_features',
            actionLabel: '读取',
            onAction: controller.state.isConnected
                ? controller.readDeviceFeatures
                : null,
            completed: controller.functionInfo != null,
            code: '''await session.readDeviceFeatures();
final functions = session.state.functionInfo;
final supportsHeartRate = functions?.supports(WSDeviceFunction.rate);''',
            detailPanel: controller.functionInfo == null
                ? null
                : WsDeviceFunctionPanel(
                    functions: controller.functionInfo!),
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
            describeWSDemoError(error!),
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

String _authenticationDetail(WSSessionState state) => switch (state.phase) {
      WSSessionPhase.ready =>
        '已登录，可使用需要认证的 SDK 功能。如需更换绑定，可在此解绑（设备会断开连接并清空设备数据）。',
      WSSessionPhase.loggingIn => '正在登录，请等待设备回应。',
      WSSessionPhase.loginRejected => '设备拒绝当前身份登录，请确认后首次绑定。',
      _ when state.isConnected => '连接后请登录；仅在登录被拒绝时执行首次绑定。',
      _ => '请先连接设备。',
    };

String _authenticationActionLabel(WSSessionState state) =>
    switch (state.phase) {
      WSSessionPhase.ready => '解绑',
      WSSessionPhase.loggingIn => '正在登录…',
      WSSessionPhase.loginRejected => '首次绑定',
      _ when state.isConnected => '登录',
      _ => '登录',
    };

Future<void> Function()? _authenticationAction(
  WSDemoController controller,
  String Function() readUserId,
) {
  if (controller.state.phase == WSSessionPhase.loggingIn) return null;
  if (controller.state.phase == WSSessionPhase.loginRejected) {
    return () async {
      final userId = readUserId();
      if (userId.isEmpty) return;
      await controller.bindFirstTime(userId, confirmed: true);
    };
  }
  if (controller.state.phase == WSSessionPhase.ready) {
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
    this.showTrailingAction = true,
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
  final bool showTrailingAction;

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
              WsDemoContentSheet.showApiExample(
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
                    if (showTrailingAction) ...[
                      const SizedBox(width: 8),
                      action,
                    ],
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

class _ConnectDeviceStepPanel extends StatelessWidget {
  const _ConnectDeviceStepPanel({
    required this.lastDevice,
    required this.connected,
    required this.connecting,
    required this.connectedName,
    required this.connectedMac,
    required this.onConnectLast,
    required this.onScan,
  });

  final WsDemoLastDevice? lastDevice;
  final bool connected;
  final bool connecting;
  final String? connectedName;
  final String? connectedMac;
  final Future<void> Function() onConnectLast;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (connected) {
      final name = connectedName ?? lastDevice?.name ?? 'JW 设备';
      final mac = connectedMac ?? lastDevice?.deviceMac;
      return Column(
        key: const Key('jw.demo.connect_device.connected'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleSmall),
          if (mac != null) ...[
            const SizedBox(height: 4),
            Text(
              mac,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    final canAct = !connecting;
    final canConnectLast = lastDevice != null && canAct;

    return Column(
      key: const Key('jw.demo.connect_device.disconnected'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastDevice != null) ...[
          Text('最近连接的设备', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(lastDevice!.name, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            lastDevice!.deviceMac,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('jw.demo.last_device.connect'),
                  onPressed:
                      canConnectLast ? () => unawaited(onConnectLast()) : null,
                  child: Text(connecting ? '连接中…' : '连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('jw.demo.last_device.scan'),
                  onPressed: canAct ? onScan : null,
                  child: const Text('扫描'),
                ),
              ),
            ],
          ),
        ] else ...[
          Text(
            '暂无最近设备记录，请扫描附近设备。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('jw.demo.last_device.scan'),
            onPressed: canAct ? onScan : null,
            child: const Text('扫描'),
          ),
        ],
      ],
    );
  }
}

class _ConnectionPage extends StatefulWidget {
  const _ConnectionPage({
    required this.controller,
    required this.onConnected,
  });

  final WSDemoController controller;
  final VoidCallback onConnected;

  @override
  State<_ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<_ConnectionPage> {
  WSDemoController get controller => widget.controller;

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

  Future<void> _finishConnect(WSScanDevice device) async {
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

  final WSScanDevice? device;

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

  final WSDemoController controller;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final sheetError = controller.sheetError.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前为 Honey 模拟器模式：列表仅含「WS Watch Simulator」，不扫描周围真机 BLE。',
          ),
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
            Text(describeWSDemoError(sheetError),
                style: TextStyle(color: errorColor)),
          ] else if (controller.error != null &&
              controller.error != sheetError) ...[
            const SizedBox(height: 12),
            Text(
              describeWSDemoError(controller.error!),
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

  final WSScanDevice device;
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
