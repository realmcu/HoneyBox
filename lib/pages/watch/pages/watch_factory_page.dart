import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/ble_provider.dart';
import '../../../providers/watch_bind_provider.dart';
import '../../../services/watch_factory_protocol.dart';
import '../../../theme/app_theme.dart';

enum _FactoryItemState { idle, waiting, done, timeout, failed }

class _FactoryItem {
  const _FactoryItem(
    this.requestKey,
    this.responseKey,
    this.title,
    this.icon, [
    this.requestValue = const [],
  ]
  );

  final int requestKey;
  final int responseKey;
  final String title;
  final IconData icon;
  final List<int> requestValue;
}

class _FactoryResult {
  const _FactoryResult(this.state, [this.text = '']);

  final _FactoryItemState state;
  final String text;
}

class WatchFactoryPage extends ConsumerStatefulWidget {
  const WatchFactoryPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  final String deviceName;
  final String deviceId;

  @override
  ConsumerState<WatchFactoryPage> createState() => _WatchFactoryPageState();
}

class _WatchFactoryPageState extends ConsumerState<WatchFactoryPage> {
  static const _items = <_FactoryItem>[
    _FactoryItem(0x03, 0x04, '电池电压', Icons.battery_std_outlined),
    _FactoryItem(0x20, 0x21, 'Patch 版本', Icons.memory_outlined),
    _FactoryItem(0x2D, 0x2E, 'SN', Icons.numbers_outlined),
    _FactoryItem(0x4C, 0x4D, 'PID', Icons.qr_code_2_outlined),
    _FactoryItem(0x3D, 0x3E, '默认功能', Icons.tune_outlined),
    _FactoryItem(0x50, 0x51, '产测结果', Icons.fact_check_outlined),
    _FactoryItem(0x55, 0x56, 'DVT 项数', Icons.science_outlined),
    _FactoryItem(0x58, 0x59, '资源 OTA', Icons.system_update_alt_outlined),
    _FactoryItem(0x5A, 0x5B, 'DebugShow', Icons.terminal_outlined),
    _FactoryItem(0xF7, 0xF8, 'HISTORY 地址', Icons.storage_outlined),
  ];

  static const _motorItem = _FactoryItem(0x29, -1, '震动测试', Icons.vibration);
  static const _voicePromptItem = _FactoryItem(
    0x2A,
    0x2B,
    'VP 测试',
    Icons.volume_up_outlined,
    [0x00, 0x00],
  );

  final Map<int, _FactoryResult> _results = {};
  StreamSubscription<Uint8List>? _commandSub;
  Completer<void>? _requestDone;
  Timer? _requestTimer;
  int? _waitingResponseKey;
  bool _runningAll = false;
  bool _motorRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ble = ref.read(bleManagerProvider);
      _commandSub = ble.commandNotifications.listen(_onCommand);
    });
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    _commandSub?.cancel();
    super.dispose();
  }

  bool get _ready =>
      ref.read(watchBindProvider).phase == WatchBindPhase.success &&
      ref.read(bleManagerProvider).commandAvailable;

  void _onCommand(Uint8List frame) {
    final response = WatchFactoryProtocol.parseResponse(frame);
    if (response == null || response.key != _waitingResponseKey) return;
    _showResult(response.key, response.value);
  }

  void _showResult(int responseKey, Uint8List value) {
    if (!mounted) return;
    final known = _items.any((test) => test.responseKey == responseKey) ||
        responseKey == _voicePromptItem.responseKey;
    if (!known) return;
    final text = switch (responseKey) {
      0x04 => WatchFactoryProtocol.decodeBatteryMillivolts(value),
      0x21 => WatchFactoryProtocol.decodePatchVersion(value),
      0x2E || 0x4D => WatchFactoryProtocol.decodeText(value),
      0x2B => value.length == 1 && value[0] != 0 ? '播放成功' : 'VP 播放失败',
      _ => WatchFactoryProtocol.hex(value),
    };
    setState(() {
      _results[responseKey] =
          _FactoryResult(_FactoryItemState.done, text.isEmpty ? 'OK' : text);
      _waitingResponseKey = null;
    });
    _requestTimer?.cancel();
    final done = _requestDone;
    _requestDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _request(_FactoryItem item) async {
    if (!_ready) {
      _showMessage('请先完成设备绑定并建立命令通道');
      return;
    }
    if (_requestDone != null) return;

    _requestTimer?.cancel();
    _waitingResponseKey = item.responseKey;
    final done = Completer<void>();
    _requestDone = done;
    setState(() {
      _results[item.responseKey] =
          const _FactoryResult(_FactoryItemState.waiting);
    });

    final sequence = ref
        .read(bleManagerProvider)
        .sendCommand(WatchFactoryProtocol.buildCommand(
          item.requestKey,
          item.requestValue,
        ));
    if (sequence == null) {
      _requestDone = null;
      _waitingResponseKey = null;
      setState(() {
        _results[item.responseKey] =
            const _FactoryResult(_FactoryItemState.failed, '发送失败');
      });
      return;
    }

    _requestTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _waitingResponseKey != item.responseKey) return;
      setState(() {
        _results[item.responseKey] =
            const _FactoryResult(_FactoryItemState.timeout, '无响应');
        _waitingResponseKey = null;
      });
      final done = _requestDone;
      _requestDone = null;
      if (done != null && !done.isCompleted) done.complete();
    });
    await done.future;
  }

  Future<void> _runAll() async {
    if (_runningAll) return;
    setState(() => _runningAll = true);
    try {
      for (final item in _items) {
        if (!mounted) break;
        await _request(item);
      }
    } finally {
      if (mounted) setState(() => _runningAll = false);
    }
  }

  Future<void> _testMotor() async {
    if (_motorRunning) return;
    if (!_ready) {
      _showMessage('请先完成设备绑定并建立命令通道');
      return;
    }

    final ble = ref.read(bleManagerProvider);
    final started = ble.sendCommand(
      WatchFactoryProtocol.buildCommand(0x29, const [0x01]),
    );
    if (started == null) {
      _showMessage('马达命令发送失败');
      return;
    }

    setState(() => _motorRunning = true);
    setState(() {
      _results[-1] = const _FactoryResult(_FactoryItemState.waiting, '震动中…');
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    ble.sendCommand(
      WatchFactoryProtocol.buildCommand(0x29, const [0x00]),
    );
    if (mounted) {
      setState(() {
        _results[-1] = const _FactoryResult(_FactoryItemState.done, '已触发');
        _motorRunning = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        ref.watch(watchBindProvider).phase == WatchBindPhase.success &&
            ref.watch(bleManagerProvider).commandAvailable;
    return Scaffold(
      appBar: AppBar(title: const Text('工厂测试')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _FactoryHeader(
                  deviceName: widget.deviceName,
                  ready: ready,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('watch-factory-run-all'),
                  onPressed: ready && !_runningAll ? _runAll : null,
                  icon: _runningAll
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_play),
                  label: Text(_runningAll ? '正在检测…' : '运行只读自检'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 3 : 2;
                    final gridItems = [
                      ..._items.take(4),
                      _motorItem,
                      _voicePromptItem,
                      ..._items.skip(4),
                    ];
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gridItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.45,
                      ),
                      itemBuilder: (context, index) {
                        final item = gridItems[index];
                        final isMotor = item.responseKey == -1;
                        return _FactoryTile(
                          item: item,
                          result: _results[item.responseKey] ??
                              const _FactoryResult(_FactoryItemState.idle),
                          enabled: ready &&
                              (isMotor ? !_motorRunning : !_runningAll),
                          onTap: isMotor ? _testMotor : () => _request(item),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  '读取 CMD 0x06，单次响应超时 2 秒。震动和 VP 测试需单项触发；写配置、恢复出厂等有副作用项目不在批量自检中执行。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FactoryHeader extends StatelessWidget {
  const _FactoryHeader({required this.deviceName, required this.ready});

  final String deviceName;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.precision_manufacturing_outlined,
              color: ready ? AppTheme.watchAccent : cs.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  ready ? '命令通道已就绪' : '请先完成设备绑定',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ready ? AppTheme.watchAccent : cs.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryTile extends StatelessWidget {
  const _FactoryTile({
    required this.item,
    required this.result,
    required this.enabled,
    required this.onTap,
  });

  final _FactoryItem item;
  final _FactoryResult result;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = switch (result.state) {
      _FactoryItemState.idle => '未执行',
      _FactoryItemState.waiting => result.text.isEmpty ? '读取中…' : result.text,
      _FactoryItemState.done => result.text,
      _FactoryItemState.timeout => '无响应',
      _FactoryItemState.failed => result.text,
    };
    final statusColor = switch (result.state) {
      _FactoryItemState.done => AppTheme.watchAccent,
      _FactoryItemState.timeout || _FactoryItemState.failed => cs.error,
      _ => cs.outline,
    };
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 22, color: cs.primary),
              const Spacer(),
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
