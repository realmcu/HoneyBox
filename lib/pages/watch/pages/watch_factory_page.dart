import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/ble_provider.dart';
import '../../../providers/watch_bind_provider.dart';
import '../../../services/watch_factory_protocol.dart';
import '../../../services/watch_record_protocol.dart';
import '../../../services/watch_record_file.dart';
import '../../../theme/app_theme.dart';

enum _FactoryItemState { idle, waiting, done, timeout, failed }

class _FactoryItem {
  const _FactoryItem(
    this.requestKey,
    this.responseKey,
    this.title,
    this.icon, [
    this.requestValue = const [],
  ]);

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
    this.recordFileWriterFactory,
  });

  final String deviceName;
  final String deviceId;
  final Future<WatchRecordFileWriter> Function(String deviceId)?
      recordFileWriterFactory;

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
  bool _recordRequesting = false;
  bool _recording = false;
  DateTime? _recordStopAt;
  WatchRecordFileWriter? _recordFile;
  String? _recordSavedPath;
  int _recordDataPackets = 0;
  int _recordDataBytes = 0;
  _FactoryResult _recordResult = const _FactoryResult(_FactoryItemState.idle);

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
    final file = _recordFile;
    _recordFile = null;
    if (file != null) unawaited(file.abort());
    super.dispose();
  }

  bool get _ready =>
      ref.read(watchBindProvider).phase == WatchBindPhase.success &&
      ref.read(bleManagerProvider).commandAvailable;

  void _onCommand(Uint8List frame) {
    final recordResponse = WatchRecordProtocol.parseResponse(frame);
    if (recordResponse != null) {
      if (recordResponse.key == WatchRecordProtocol.dataKey) {
        _onRecordData(recordResponse);
      } else {
        _onRecordResponse(recordResponse);
      }
      return;
    }
    final response = WatchFactoryProtocol.parseResponse(frame);
    if (response == null || response.key != _waitingResponseKey) return;
    _showResult(response.key, response.value);
  }

  void _onRecordData(WatchRecordResponse response) {
    if (!_recording) return;
    final data = WatchRecordProtocol.parseData(response);
    if (data == null || !mounted) return;
    final file = _recordFile;
    if (file != null) unawaited(file.append(data.frames));
    setState(() {
      _recordDataPackets++;
      _recordDataBytes += data.byteLength;
    });
  }

  void _onRecordResponse(WatchRecordResponse response) {
    if (response.key != WatchRecordProtocol.startKey &&
        response.key != WatchRecordProtocol.stopKey) {
      return;
    }
    final stopped = response.key == WatchRecordProtocol.stopKey;
    final text = stopped
        ? WatchRecordProtocol.decodeStop(response.value)
        : WatchRecordProtocol.decodeStart(response.value);
    if (!mounted) return;

    if (!stopped) {
      _requestTimer?.cancel();
      setState(() {
        _recordRequesting = false;
        _recording = true;
        _recordStopAt = null;
        _recordResult = _FactoryResult(_FactoryItemState.done, text);
      });
      final done = _requestDone;
      _requestDone = null;
      if (done != null && !done.isCompleted) done.complete();
      return;
    }

    final stopAt = _recordStopAt ?? DateTime.now();
    final failed = response.value.isNotEmpty && response.value[0] != 0x00;
    _requestTimer?.cancel();
    setState(() {
      _recordRequesting = false;
      _recording = false;
      _recordResult = _FactoryResult(
        failed ? _FactoryItemState.failed : _FactoryItemState.done,
        text,
      );
    });
    final done = _requestDone;
    _requestDone = null;
    if (done != null && !done.isCompleted) done.complete();
    unawaited(_finishRecordFile(stopAt, failed ? text : null));
  }

  Future<void> _finishRecordFile(DateTime stoppedAt, String? error) async {
    final writer = _recordFile;
    _recordFile = null;
    if (writer == null) return;
    try {
      final file = await writer.finish(stoppedAt);
      if (!mounted) return;
      setState(() {
        _recordSavedPath = file?.path;
        if (error != null) {
          _recordResult = _FactoryResult(_FactoryItemState.failed, error);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recordResult = _FactoryResult(
          _FactoryItemState.failed,
          '录音文件保存失败：$e',
        );
      });
    }
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

  Future<void> _requestRecord() async {
    if (!_ready) {
      _showMessage('请先完成设备绑定并建立命令通道');
      return;
    }
    if (_requestDone != null || _recordRequesting || _recording) return;

    _requestTimer?.cancel();
    WatchRecordFileWriter? writer;
    try {
      writer = widget.recordFileWriterFactory != null
          ? await widget.recordFileWriterFactory!(widget.deviceId)
          : await WatchRecordFileWriter.createDefault(
              deviceId: widget.deviceId,
            );
      await writer.start(
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
        startedAt: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordRequesting = false;
          _recordResult = _FactoryResult(
            _FactoryItemState.failed,
            '无法创建录音文件：$e',
          );
        });
      }
      await writer?.abort();
      return;
    }

    final done = Completer<void>();
    _requestDone = done;
    _recordFile = writer;
    setState(() {
      _recordRequesting = true;
      _recording = false;
      _recordStopAt = null;
      _recordSavedPath = null;
      _recordDataPackets = 0;
      _recordDataBytes = 0;
      _recordResult =
          const _FactoryResult(_FactoryItemState.waiting, '等待手表启动…');
    });

    final sequence = ref
        .read(bleManagerProvider)
        .sendCommand(WatchRecordProtocol.buildRequest());
    if (sequence == null) {
      _requestDone = null;
      setState(() {
        _recordRequesting = false;
        _recordResult =
            const _FactoryResult(_FactoryItemState.failed, '录音请求发送失败');
      });
      unawaited(_finishRecordFile(DateTime.now(), '录音请求发送失败'));
      return;
    }

    _requestTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_recordRequesting) return;
      setState(() {
        _recordRequesting = false;
        _recordResult = const _FactoryResult(_FactoryItemState.timeout, '无响应');
      });
      final done = _requestDone;
      _requestDone = null;
      if (done != null && !done.isCompleted) done.complete();
      unawaited(_finishRecordFile(DateTime.now(), '录音启动无响应'));
    });
    await done.future;
  }

  Future<void> _stopRecord() async {
    if (!_recording || _recordRequesting || !_ready) return;
    final stopAt = DateTime.now();
    _recordStopAt = stopAt;
    setState(() {
      _recordRequesting = true;
      _recordResult =
          const _FactoryResult(_FactoryItemState.waiting, '正在停止录音…');
    });
    final sequence = ref
        .read(bleManagerProvider)
        .sendCommand(WatchRecordProtocol.buildCancelRequest());
    if (sequence == null) {
      setState(() {
        _recordRequesting = false;
        _recording = false;
      });
      await _finishRecordFile(stopAt, '停止命令发送失败');
      return;
    }

    _requestTimer?.cancel();
    _requestTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_recordRequesting) return;
      setState(() {
        _recordRequesting = false;
        _recording = false;
      });
      unawaited(_finishRecordFile(stopAt, '未收到手表停止确认'));
    });
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('watch-factory-record-start'),
                        onPressed: ready &&
                                !_recordRequesting &&
                                !_recording &&
                                !_runningAll
                            ? _requestRecord
                            : null,
                        icon: _recordRequesting && !_recording
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic_none_outlined),
                        label: const Text('开始录音'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('watch-factory-record-stop'),
                        onPressed: ready && _recording && !_recordRequesting
                            ? _stopRecord
                            : null,
                        icon: _recordRequesting && _recording
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.stop_circle_outlined),
                        label: const Text('停止录音'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_recordResult.state != _FactoryItemState.idle) ...[
                  const SizedBox(height: 8),
                  Text(
                    _recordResult.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: switch (_recordResult.state) {
                            _FactoryItemState.done => AppTheme.watchAccent,
                            _FactoryItemState.timeout ||
                            _FactoryItemState.failed =>
                              Theme.of(context).colorScheme.error,
                            _ => Theme.of(context).colorScheme.outline,
                          },
                    ),
                  ),
                  if (_recordDataPackets > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '已接收 PCM $_recordDataPackets 包 / '
                      '$_recordDataBytes 字节',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.watchAccent,
                          ),
                    ),
                  ],
                  if (_recordSavedPath != null) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      '已保存：$_recordSavedPath',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
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
