import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_device_function_labels.dart';
import 'jw_measure_event_controller.dart';
import 'jw_measure_presenter.dart';

void openJwMeasureHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWMeasureHubPage(controller: controller),
      ),
    ),
  );
}

class JWMeasureHubPage extends StatefulWidget {
  const JWMeasureHubPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JWMeasureHubPage> createState() => _JWMeasureHubPageState();
}

class _JWMeasureHubPageState extends State<JWMeasureHubPage>
    with _DemoAsyncMixin {
  final _events = JwMeasureEventController();

  JWAutoMeasureConfig? _hrAuto;
  JWAutoMeasureConfig? _spo2Auto;
  JWAutoMeasureConfig? _bpAuto;
  JWBloodSugarAutoMeasureConfig? _gluAuto;
  JWTemperatureControlSetting? _tempControl;

  bool _hrAutoEnabled = false;
  int _hrAutoInterval = 5;
  bool _spo2AutoEnabled = false;
  int _spo2AutoInterval = 5;
  bool _bpAutoEnabled = false;
  int _bpAutoInterval = 5;
  bool _gluAutoEnabled = false;
  int _gluAutoInterval = 5;

  bool _tempShow = false;
  bool _tempAdjust = false;
  bool _tempCelsius = true;

  bool get _ready => widget.controller.state.isReady;

  bool _supports(JWDeviceFunction function) =>
      widget.controller.state.functionInfo?.supports(function) ?? false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMeasureListener);
    _syncMeasureListener();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncMeasureListener);
    _events.dispose();
    super.dispose();
  }

  void _syncMeasureListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = widget.controller.session;
      if (session != null && widget.controller.state.isReady) {
        _events.attach(session);
      } else {
        _events.detach();
      }
    });
  }

  Future<void> _readAutoConfigs() => run(() async {
        JWAutoMeasureConfig? hr;
        JWAutoMeasureConfig? spo2;
        JWAutoMeasureConfig? bp;
        if (_supports(JWDeviceFunction.rate)) {
          hr = await widget.controller.readHeartRateAutoMeasure();
        }
        if (_supports(JWDeviceFunction.spo2Continuous)) {
          spo2 = await widget.controller.readSpO2AutoMeasure();
        }
        if (_supports(JWDeviceFunction.rtkBp3)) {
          bp = await widget.controller.readBloodPressureAutoMeasure();
        }
        JWBloodSugarAutoMeasureConfig? glu;
        JWTemperatureControlSetting? temp;
        if (_supports(JWDeviceFunction.bloodSugar)) {
          glu = await widget.controller.readBloodSugarAutoMeasure();
        }
        if (_supports(JWDeviceFunction.temperature)) {
          temp = await widget.controller.readTemperatureControl();
        }
        if (!mounted) return;
        setState(() {
          _hrAuto = hr;
          _spo2Auto = spo2;
          _bpAuto = bp;
          _gluAuto = glu;
          _tempControl = temp;
          if (hr != null) {
            _hrAutoEnabled = hr.enabled;
            _hrAutoInterval = hr.intervalMinutes;
          }
          if (spo2 != null) {
            _spo2AutoEnabled = spo2.enabled;
            _spo2AutoInterval = spo2.intervalMinutes;
          }
          if (bp != null) {
            _bpAutoEnabled = bp.enabled;
            _bpAutoInterval = bp.intervalMinutes;
          }
          if (glu != null) {
            _gluAutoEnabled = glu.enabled;
            _gluAutoInterval = glu.intervalMinutes;
          }
          if (temp != null) {
            _tempShow = temp.enabled;
            _tempAdjust = temp.adjust;
            _tempCelsius = temp.celsius;
          }
          resultMessage = '已读取自动监测与体温 control。';
        });
      });

  Future<void> _applyHrAuto() => run(() async {
        await widget.controller.setHeartRateAutoMeasure(JWAutoMeasureConfig(
          enabled: _hrAutoEnabled,
          intervalMinutes: _hrAutoInterval,
        ));
        if (mounted) setState(() => resultMessage = '心率自动监测已下发。');
      });

  Future<void> _applySpO2Auto() => run(() async {
        await widget.controller.setSpO2AutoMeasure(JWAutoMeasureConfig(
          enabled: _spo2AutoEnabled,
          intervalMinutes: _spo2AutoInterval,
        ));
        if (mounted) setState(() => resultMessage = '血氧自动监测已下发。');
      });

  Future<void> _applyBpAuto() => run(() async {
        await widget.controller.setBloodPressureAutoMeasure(JWAutoMeasureConfig(
          enabled: _bpAutoEnabled,
          intervalMinutes: _bpAutoInterval,
        ));
        if (mounted) setState(() => resultMessage = '血压自动监测已下发。');
      });

  Future<void> _applyGluAuto() => run(() async {
        await widget.controller.setBloodSugarAutoMeasure(
          JWBloodSugarAutoMeasureConfig(
            enabled: _gluAutoEnabled,
            intervalMinutes: _gluAutoInterval,
          ),
        );
        if (mounted) setState(() => resultMessage = '血糖自动监测已下发。');
      });

  Future<void> _applyTempControl() => run(() async {
        await widget.controller.setTemperatureControl(
          JWTemperatureControlSetting(
            enabled: _tempShow,
            adjust: _tempAdjust,
            celsius: _tempCelsius,
          ),
        );
        if (mounted) setState(() => resultMessage = '体温控制已下发。');
      });

  Future<void> _spot(Future<void> Function() action, String label) => run(
        () async {
          await action();
          _events.note('$label 命令已发送');
          if (mounted) setState(() => resultMessage = '$label 命令已发送');
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncing = widget.controller.isHealthSyncActive;
    return Scaffold(
      key: const Key('jw.demo.measure.hub'),
      appBar: AppBar(title: const Text('健康测量')),
      body: !_ready
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('请先完成登录或首次绑定。测量 API 只在 ready 会话中可用。'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '自动监测读写、体温 control、点测 start/stop/check。'
                  '点测数据经 session.measure + JWMeasureDataListener 推送，不写本地库。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (syncing)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: const ListTile(
                      leading: Icon(Icons.sync_problem_outlined),
                      title: Text('健康数据同步进行中'),
                      subtitle: Text('此时无法开始新的点测（SDK 会拒绝）。'),
                    ),
                  ),
                ListenableBuilder(
                  listenable: _events,
                  builder: (context, _) {
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          _events.isAttached
                              ? Icons.sensors
                              : Icons.sensors_off_outlined,
                        ),
                        title: const Text('实时 listener'),
                        subtitle: Text(
                          _events.isAttached
                              ? '已监听 · 日志 ${_events.log.length} 条'
                              : '未附着',
                        ),
                        trailing: TextButton(
                          onPressed: _events.log.isEmpty
                              ? null
                              : () {
                                  _events.clearLog();
                                },
                          child: const Text('清空日志'),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('jw.demo.measure.read_auto'),
                  onPressed: busy ? null : _readAutoConfigs,
                  icon: const Icon(Icons.refresh),
                  label: const Text('读取自动监测 / 体温 control'),
                ),
                ...buildAsyncFeedback(context),
                const SizedBox(height: 16),
                Text('自动监测', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_hrAuto != null)
                  Text('设备当前 · 心率：${jwAutoMeasureConfigLabel(_hrAuto!)}'),
                if (_spo2Auto != null)
                  Text('设备当前 · 血氧：${jwAutoMeasureConfigLabel(_spo2Auto!)}'),
                if (_bpAuto != null)
                  Text('设备当前 · 血压：${jwAutoMeasureConfigLabel(_bpAuto!)}'),
                if (_gluAuto != null)
                  Text(
                      '设备当前 · 血糖：${jwBloodSugarAutoConfigLabel(_gluAuto!)}'),
                if (_tempControl != null)
                  Text(
                      '设备当前 · 体温 control：${jwTemperatureControlLabel(_tempControl!)}'),
                const SizedBox(height: 8),
                if (_supports(JWDeviceFunction.rate))
                  _AutoMeasureCard(
                    title: jwDeviceFunctionLabel(JWDeviceFunction.rate),
                    enabled: _hrAutoEnabled,
                    interval: _hrAutoInterval,
                    busy: busy,
                    onEnabled: (v) => setState(() => _hrAutoEnabled = v),
                    onInterval: (v) => setState(() => _hrAutoInterval = v),
                    onApply: _applyHrAuto,
                  ),
                if (_supports(JWDeviceFunction.spo2Continuous))
                  _AutoMeasureCard(
                    title: jwDeviceFunctionLabel(JWDeviceFunction.spo2Continuous),
                    enabled: _spo2AutoEnabled,
                    interval: _spo2AutoInterval,
                    busy: busy,
                    onEnabled: (v) => setState(() => _spo2AutoEnabled = v),
                    onInterval: (v) => setState(() => _spo2AutoInterval = v),
                    onApply: _applySpO2Auto,
                  ),
                if (_supports(JWDeviceFunction.rtkBp3))
                  _AutoMeasureCard(
                    title: jwDeviceFunctionLabel(JWDeviceFunction.rtkBp3),
                    enabled: _bpAutoEnabled,
                    interval: _bpAutoInterval,
                    busy: busy,
                    onEnabled: (v) => setState(() => _bpAutoEnabled = v),
                    onInterval: (v) => setState(() => _bpAutoInterval = v),
                    onApply: _applyBpAuto,
                  ),
                if (_supports(JWDeviceFunction.bloodSugar))
                  _AutoMeasureCard(
                    title: '血糖连续监测',
                    enabled: _gluAutoEnabled,
                    interval: _gluAutoInterval,
                    busy: busy,
                    onEnabled: (v) => setState(() => _gluAutoEnabled = v),
                    onInterval: (v) => setState(() => _gluAutoInterval = v),
                    onApply: _applyGluAuto,
                  ),
                if (_supports(JWDeviceFunction.temperature)) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '体温 control（0x23/0x24 · set 0x08/0x22）',
                            style: theme.textTheme.titleSmall,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('手环显示体温'),
                            value: _tempShow,
                            onChanged:
                                busy ? null : (v) => setState(() => _tempShow = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('补偿'),
                            value: _tempAdjust,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => _tempAdjust = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('摄氏单位'),
                            value: _tempCelsius,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => _tempCelsius = v),
                          ),
                          FilledButton(
                            onPressed: busy ? null : _applyTempControl,
                            child: const Text('下发体温 control'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_supports(JWDeviceFunction.pressure))
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            jwDeviceFunctionLabel(JWDeviceFunction.pressure),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text('连续监测开关（0x4f/0x07）'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          await widget.controller
                                              .setPressureAutoMeasure(true);
                                          if (mounted) {
                                            setState(() => resultMessage =
                                                '压力自动监测：开');
                                          }
                                        }),
                                child: const Text('开'),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          await widget.controller
                                              .setPressureAutoMeasure(false);
                                          if (mounted) {
                                            setState(() => resultMessage =
                                                '压力自动监测：关');
                                          }
                                        }),
                                child: const Text('关'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('体脂监测', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        const Text('DEVICE_MEASURE_SET 0x52/0x05'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        await widget.controller
                                            .setBodyFatMonitoring(true);
                                        if (mounted) {
                                          setState(
                                              () => resultMessage = '体脂监测：开');
                                        }
                                      }),
                              child: const Text('开'),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        await widget.controller
                                            .setBodyFatMonitoring(false);
                                        if (mounted) {
                                          setState(
                                              () => resultMessage = '体脂监测：关');
                                        }
                                      }),
                              child: const Text('关'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('点测', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_supports(JWDeviceFunction.rate))
                  _SpotMeasureRow(
                    title: '心率',
                    busy: busy || syncing,
                    onStart: () => _spot(
                      widget.controller.startHeartRateSpotMeasure,
                      '心率点测开始',
                    ),
                    onStop: () => _spot(
                      widget.controller.stopHeartRateSpotMeasure,
                      '心率点测停止',
                    ),
                  ),
                if (_supports(JWDeviceFunction.bpDetection))
                  _SpotMeasureRow(
                    title: '血压',
                    busy: busy || syncing,
                    onStart: () => _spot(
                      widget.controller.startBloodPressureSpotMeasure,
                      '血压点测开始',
                    ),
                    onStop: () => _spot(
                      widget.controller.stopBloodPressureSpotMeasure,
                      '血压点测停止',
                    ),
                  ),
                if (_supports(JWDeviceFunction.spo2Measure))
                  _SpotMeasureRow(
                    title: '血氧',
                    busy: busy || syncing,
                    onStart: () => _spot(
                      widget.controller.startSpO2SpotMeasure,
                      '血氧点测开始',
                    ),
                    onStop: () => _spot(
                      widget.controller.stopSpO2SpotMeasure,
                      '血氧点测停止',
                    ),
                    onCheck: () => _spot(
                      widget.controller.checkSpO2SpotMeasure,
                      '血氧点测 check',
                    ),
                  ),
                if (_supports(JWDeviceFunction.temperature))
                  _SpotMeasureRow(
                    title: '体温',
                    busy: busy || syncing,
                    onStart: () => _spot(
                      widget.controller.startTemperatureSpotMeasure,
                      '体温点测开始',
                    ),
                    onStop: () => _spot(
                      widget.controller.stopTemperatureSpotMeasure,
                      '体温点测停止',
                    ),
                    onCheck: () => _spot(
                      widget.controller.checkTemperatureSpotMeasure,
                      '体温点测 check',
                    ),
                  ),
                if (_supports(JWDeviceFunction.bloodSugar))
                  _SpotMeasureRow(
                    title: '血糖',
                    busy: busy || syncing,
                    onStart: () => _spot(
                      widget.controller.startBloodGlucoseSpotMeasure,
                      '血糖点测开始',
                    ),
                    onStop: () => _spot(
                      widget.controller.stopBloodGlucoseSpotMeasure,
                      '血糖点测停止',
                    ),
                  ),
                const SizedBox(height: 16),
                Text('点测事件', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: _events,
                  builder: (context, _) {
                    if (_events.log.isEmpty) {
                      return Text(
                        '在手表上完成测量后，listener 回调会显示在这里。',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(_events.log.reversed.join('\n\n')),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _AutoMeasureCard extends StatelessWidget {
  const _AutoMeasureCard({
    required this.title,
    required this.enabled,
    required this.interval,
    required this.busy,
    required this.onEnabled,
    required this.onInterval,
    required this.onApply,
  });

  final String title;
  final bool enabled;
  final int interval;
  final bool busy;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<int> onInterval;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用'),
              value: enabled,
              onChanged: busy ? null : onEnabled,
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: interval.clamp(1, 60).toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: '$interval 分钟',
                    onChanged: busy
                        ? null
                        : (v) => onInterval(v.round()),
                  ),
                ),
                Text('$interval 分'),
              ],
            ),
            FilledButton(onPressed: busy ? null : onApply, child: const Text('下发')),
          ],
        ),
      ),
    );
  }
}

class _SpotMeasureRow extends StatelessWidget {
  const _SpotMeasureRow({
    required this.title,
    required this.busy,
    required this.onStart,
    required this.onStop,
    this.onCheck,
  });

  final String title;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : onStart,
                  child: const Text('开始'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onStop,
                  child: const Text('停止'),
                ),
                if (onCheck != null)
                  OutlinedButton(
                    onPressed: busy ? null : onCheck,
                    child: const Text('Check'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

mixin _DemoAsyncMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;
  Object? error;
  String? resultMessage;

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      resultMessage = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> buildAsyncFeedback(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (resultMessage != null) ...[
        const SizedBox(height: 12),
        Text(resultMessage!, style: theme.textTheme.bodyMedium),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          describeJWDemoError(error!),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
    ];
  }
}
