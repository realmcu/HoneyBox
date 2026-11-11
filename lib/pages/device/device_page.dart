import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../services/device_type_store.dart';
import '../../theme/app_theme.dart';
import '../shared/app_drawer.dart';
import '../shared/disconnect_dialog.dart';
import 'device_features.dart';
import 'widgets/action_card.dart';

class DevicePage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const DevicePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends ConsumerState<DevicePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// 当前设备类型。**先用默认值把界面画出来**,读盘回来再刷一次 —— 绑定记忆在
  /// 文件里,而文件是异步读的,等它读完再出第一帧只会让连接后空着一下。
  ///
  /// 这个字段也是「类型已经被决定过」的标志:读盘回来之前用户手快切了类型的话,
  /// 迟到的读盘结果不能把它盖回去(见 [_loadDeviceType])。
  DeviceType _type = DeviceType.demo;
  bool _typeResolved = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadDeviceType();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// 把上次给这台设备选的类型取回来。没绑过就是 [DeviceType.demo]。
  ///
  /// 读盘失败/拿不到目录时 [DeviceTypeBindingStore] 自己兜默认值,这里不必再兜。
  Future<void> _loadDeviceType() async {
    var type = DeviceType.demo;
    try {
      type = await DeviceTypeBindingStore.typeFor(widget.deviceId);
    } catch (_) {
      // 绑定记忆是便利而不是前提:读不出来就按默认类型列卡片。
    }
    // 用户在读盘期间已经自己切过了 —— 以他切的为准,不要把旧记忆盖回来。
    if (!mounted || _typeResolved) return;
    setState(() {
      _type = type;
      _typeResolved = true;
    });
  }

  /// 切到另一种设备类型,并**立刻**记到这台设备名下(下次连它就是这一类)。
  void _setDeviceType(DeviceType type) {
    if (type == _type && _typeResolved) return;
    setState(() {
      _type = type;
      _typeResolved = true;
    });
    // 不 await:存盘是尽力而为的,界面上类型已经切好了,不该为一次文件写卡住。
    DeviceTypeBindingStore.bind(widget.deviceId, type);
  }

  /// 点顶部设备栏 —— 弹类型选择。
  Future<void> _pickDeviceType() async {
    final picked = await showModalBottomSheet<DeviceType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _DeviceTypeSheet(selected: _type),
    );
    if (picked == null) return;
    _setDeviceType(picked);
  }

  void _onDisconnectTap() async {
    // 复用共享确认对话框(EBadgeAppRoot 的返回键拦截也走同一份 UI)。
    final confirmed = await showDisconnectConfirmDialog(context);
    if (!confirmed || !mounted) return;
    // Clearing the connection makes the root gate fall back to the scanner
    // automatically.
    ref.read(bleNotifierProvider.notifier).disconnect();
  }

  void _open(String route) {
    Navigator.pushNamed(
      context,
      route,
      arguments: {
        'deviceName': widget.deviceName,
        'deviceId': widget.deviceId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final features = deviceFeaturesFor(_type);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      drawer: const AppDrawer(),
      // Let a rightward swipe from the left half of the screen open the drawer.
      drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.5,
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: Text(widget.deviceName),
        actions: [
          TextButton.icon(
            onPressed: _onDisconnectTap,
            // Red icon flags the destructive action; the label stays white.
            icon: Icon(Icons.link_off, size: 18, color: cs.error),
            label: const Text('断开'),
            style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        // 左右内边距不再包在整块上,而是下放到各段自己身上 —— 中间那条分隔线要
        // 通到屏幕两侧,包在 padding 里就只能画到内容宽度。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  // 设备栏(「WiFi 配网」左侧这一整块)可点:切换设备类型。
                  // 用 InkWell 而不是把整行包起来 —— 右侧的配网按钮是独立动作,
                  // 落在它的矩形里就该走它自己。
                  Expanded(
                    child: InkWell(
                      onTap: _pickDeviceType,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.bluetooth_connected,
                                  color: cs.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 第一行就是那个下拉按钮的标签 —— 直接显示**当前
                                  // 类型名**,旁边挂一个箭头。写「设备类型」再加一行
                                  // 值等于让人先读标签、再读一次值。
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _type.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleSmall
                                              ?.copyWith(color: cs.secondary),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.expand_more,
                                          size: 18,
                                          color: AppTheme.textSecondary),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.deviceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 配网按钮不随类型变:它配的是设备的 Wi-Fi,与列哪些功能无关。
                  OutlinedButton.icon(
                    onPressed: () => _open('/wifi'),
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('WiFi 配网'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            // 设备栏与功能网格之间的分隔线。通到屏幕两侧,所以直接摆在 Column 里
            // —— 左右内边距已经下放到上下两段自己身上,这里不再需要抵消。
            Divider(height: 1, thickness: 1, color: cs.outline),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: features.isEmpty
                    ? const _NoFeatureHint()
                    // 只有一张卡时,GridView 按宽高比把这张卡拉满两列的宽度,
                    // 手机上就是一块约 300 px 高的大方块 —— 看着像页面坏了。
                    // 这种情形仍旧用同一个 GridView(尺寸、留白都和两张时一致),
                    // 只是把行高钉成一张卡的原始高度。
                    : features.length == 1
                        ? GridView(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: _kCardHeight,
                            ),
                            children: features.map(_buildCard).toList(),
                          )
                        : GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.25,
                            physics: const BouncingScrollPhysics(),
                            children: features.map(_buildCard).toList(),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(DeviceFeature feature) => ActionCard(
        icon: feature.icon,
        title: feature.title,
        onTap: () => _open(feature.route),
      );
}

/// 网格里一张卡的标称高度。
///
/// 两列网格用的是宽高比形式(1.25),卡片高度随屏宽变;单张卡时换成定高,所以
/// 这里取一个典型手机宽度(360 dp)下那个宽高比算出来的高度 —— 两种排法的卡片
/// 看起来一样大,切换类型时网格不会「跳」一下。
const double _kCardHeight = (360 - 32 - 12) / 2 / 1.25;

/// 某类设备目前一张卡片都没有时的说明。
///
/// 现在两类设备都至少有一张卡,所以这条分支是给「将来新加的类型还没配功能」留的
/// —— 空白的网格看起来就是页面坏了,而不是「这一类设备还没东西可做」。
class _NoFeatureHint extends StatelessWidget {
  const _NoFeatureHint();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Text(
        '该设备类型暂无可用功能',
        style: tt.bodyMedium?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

/// 设备类型选择面板。
class _DeviceTypeSheet extends StatelessWidget {
  const _DeviceTypeSheet({required this.selected});

  final DeviceType selected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '设备类型',
              textAlign: TextAlign.center,
              style: tt.titleMedium,
            ),
          ),
          for (final type in DeviceType.values)
            ListTile(
              leading: Icon(
                type == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: type == selected
                    ? Theme.of(context).colorScheme.primary
                    : AppTheme.textSecondary,
              ),
              title: Text(type.label, style: tt.bodyLarge),
              subtitle: Text(
                _describe(type),
                style: tt.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              onTap: () => Navigator.of(context).pop(type),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 类型的一句话说明 —— 直接说「会列出什么」,而不是产品线代号。
  static String _describe(DeviceType type) {
    final titles = deviceFeaturesFor(type).map((f) => f.title).join(' · ');
    return titles.isEmpty ? '暂无功能' : titles;
  }
}
