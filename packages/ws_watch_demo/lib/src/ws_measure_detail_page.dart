import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_async_mixin.dart';
import 'compat/ws_demo_compat.dart';
import 'ws_demo_controller.dart';
import 'ws_demo_log.dart';
import 'ws_measure_auto_monitor.dart';
import 'ws_measure_module.dart';
import 'ws_measure_spot_panel.dart';
import 'ws_scoped_measure_listener.dart';

class WSMeasureDetailPage extends StatefulWidget {
  const WSMeasureDetailPage({
    super.key,
    required this.controller,
    required this.kind,
  });

  final WSDemoController controller;
  final WSMeasureModuleKind kind;

  @override
  State<WSMeasureDetailPage> createState() => _JWMeasureDetailPageState();
}

class _JWMeasureDetailPageState extends State<WSMeasureDetailPage>
    with WsDemoAsyncMixin {
  late final WsScopedMeasureListener _events;

  bool _autoEnabled = false;
  int _intervalMinutes = 10;
  List<int> _hrIntervals = kJwDemoFallbackHeartRateIntervals;

  bool _tempAdjust = false;
  bool _tempCelsius = true;

  bool _spotMeasuring = false;
  bool _spotBusy = false;
  Object? _spotError;

  WSWatchSession? _attachedSession;

  WSMeasureModuleKind get kind => widget.kind;

  bool get _syncing => widget.controller.isHealthSyncActive;

  @override
  void initState() {
    super.initState();
    _events = WsScopedMeasureListener(kind);
    _events.onHeartRateSpotEndedByDevice = () {
      if (mounted && _spotMeasuring) {
        setState(() => _spotMeasuring = false);
      }
    };
    // Spot values arrive ~1 Hz; rebuild immediately so UI tracks WIRE/API logs.
    _events.addListener(_onMeasureEvents);
    widget.controller.addListener(_syncSession);
    _hrIntervals = kJwDemoFallbackHeartRateIntervals;
    _intervalMinutes = jwDemoDefaultAutoIntervalMinutes(kind);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSession();
      _refreshAutoConfig();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSession);
    _events.removeListener(_onMeasureEvents);
    if (_spotMeasuring) {
      unawaited(_stopSpotSilently());
    }
    _events.dispose();
    super.dispose();
  }

  void _onMeasureEvents() {
    if (mounted) setState(() {});
  }

  void _syncSession() {
    final session = widget.controller.session;
    final ready = widget.controller.state.isReady;
    if (ready && session != null) {
      if (!identical(_attachedSession, session)) {
        _attachedSession = session;
        WsDemoLog.info('measure page session ready kind=$kind');
        _events.attach(session);
      }
    } else {
      if (_attachedSession != null) {
        WsDemoLog.info('measure page session lost kind=$kind');
      }
      _attachedSession = null;
      _events.detach();
    }
  }

  Future<void> _refreshAutoConfig() => run(() async {
        switch (kind) {
          case WSMeasureModuleKind.heartRate:
            final options =
                await widget.controller.readHeartRateIntervalOptions();
            if (options.isNotEmpty) {
              _hrIntervals = options;
            }
            final cfg = await widget.controller.readHeartRateAutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = jwDemoSnapHeartRateInterval(
              cfg.intervalMinutes,
              _hrIntervals,
            );
          case WSMeasureModuleKind.bloodOxygen:
            final cfg = await widget.controller.readSpO2AutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case WSMeasureModuleKind.bloodPressure:
            final cfg = await widget.controller.readBloodPressureAutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case WSMeasureModuleKind.bloodGlucose:
            final cfg = await widget.controller.readBloodSugarAutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case WSMeasureModuleKind.temperature:
            final cfg = await widget.controller.readTemperatureControl();
            _autoEnabled = cfg.enabled;
            _tempAdjust = cfg.adjust;
            _tempCelsius = cfg.celsius;
          case WSMeasureModuleKind.pressure:
            _autoEnabled = false;
        }
        resultMessage = '已读取设备当前配置';
      });

  void _onAutoChanged(bool value) {
    unawaited(run(() async {
      _autoEnabled = value;
      await _pushAutoConfig();
      resultMessage = value ? '已开启' : '已关闭';
    }));
  }

  void _onIntervalSelected(int minutes) {
    unawaited(run(() async {
      _intervalMinutes = minutes;
      if (_autoEnabled) {
        await _pushAutoConfig();
      }
      resultMessage = '间隔已设为 $minutes 分钟';
    }));
  }

  Future<void> _pushAutoConfig() async {
    switch (kind) {
      case WSMeasureModuleKind.heartRate:
        await widget.controller.setHeartRateAutoMeasure(
          WSAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes,
          ),
        );
      case WSMeasureModuleKind.bloodOxygen:
        await widget.controller.setSpO2AutoMeasure(
          WSAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case WSMeasureModuleKind.bloodPressure:
        await widget.controller.setBloodPressureAutoMeasure(
          WSAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case WSMeasureModuleKind.bloodGlucose:
        await widget.controller.setBloodSugarAutoMeasure(
          WSBloodSugarAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case WSMeasureModuleKind.temperature:
        await widget.controller.setTemperatureControl(
          WSTemperatureControlSetting(
            enabled: _autoEnabled,
            adjust: _tempAdjust,
            celsius: _tempCelsius,
          ),
        );
      case WSMeasureModuleKind.pressure:
        await widget.controller.setPressureAutoMeasure(_autoEnabled);
    }
  }

  Future<void> _runSpot(Future<void> Function() action) async {
    if (_spotBusy || !mounted) return;
    setState(() {
      _spotBusy = true;
      _spotError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _spotError = e);
    } finally {
      if (mounted) setState(() => _spotBusy = false);
    }
  }

  Future<void> _toggleSpot() {
    if (_spotMeasuring) {
      return _runSpot(() async {
        await _stopSpot();
        if (mounted) setState(() => _spotMeasuring = false);
      });
    }
    return _runSpot(() async {
      await _startSpot();
      if (mounted) setState(() => _spotMeasuring = true);
    });
  }

  Future<void> _startSpot() async {
    WsDemoLog.info('spot START kind=$kind');
    switch (kind) {
      case WSMeasureModuleKind.heartRate:
        await widget.controller.startHeartRateMeasure();
      case WSMeasureModuleKind.bloodOxygen:
        await widget.controller.startSpO2SpotMeasure();
      case WSMeasureModuleKind.bloodPressure:
        await widget.controller.startBloodPressureSpotMeasure();
      case WSMeasureModuleKind.temperature:
        await widget.controller.startTemperatureSpotMeasure();
      case WSMeasureModuleKind.bloodGlucose:
        await widget.controller.startBloodGlucoseSpotMeasure();
      case WSMeasureModuleKind.pressure:
        break;
    }
  }

  Future<void> _stopSpot() async {
    WsDemoLog.info('spot STOP kind=$kind');
    switch (kind) {
      case WSMeasureModuleKind.heartRate:
        await widget.controller.stopHeartRateMeasure();
      case WSMeasureModuleKind.bloodOxygen:
        await widget.controller.stopSpO2SpotMeasure();
      case WSMeasureModuleKind.bloodPressure:
        await widget.controller.stopBloodPressureSpotMeasure();
      case WSMeasureModuleKind.temperature:
        await widget.controller.stopTemperatureSpotMeasure();
      case WSMeasureModuleKind.bloodGlucose:
        await widget.controller.stopBloodGlucoseSpotMeasure();
      case WSMeasureModuleKind.pressure:
        break;
    }
  }

  Future<void> _stopSpotSilently() async {
    try {
      await _stopSpot();
    } catch (_) {}
    _spotMeasuring = false;
  }

  Future<void> _checkSpot() => _runSpot(() async {
        switch (kind) {
          case WSMeasureModuleKind.bloodOxygen:
            await widget.controller.checkSpO2SpotMeasure();
          case WSMeasureModuleKind.temperature:
            await widget.controller.checkTemperatureSpotMeasure();
          default:
            break;
        }
      });

  Future<void> _applyTempOptions() => run(() async {
        await widget.controller.setTemperatureControl(
          WSTemperatureControlSetting(
            enabled: _autoEnabled,
            adjust: _tempAdjust,
            celsius: _tempCelsius,
          ),
        );
        resultMessage = '显示选项已下发';
      });

  String get _spotStatus {
    if (_syncing && !_spotMeasuring) {
      return '健康数据同步中，暂无法开始新的点测';
    }
    if (_spotMeasuring && _events.spotValue == null) {
      return '测量中，请保持佩戴…';
    }
    if (_events.lastEventLine != null) {
      return _events.lastEventLine!;
    }
    if (_spotMeasuring) {
      return '测量中，请保持佩戴…';
    }
    return '点击开始测量';
  }

  String? get _spotDisplayValue {
    final raw = _events.spotValue;
    if (raw == null) return null;
    if (kind == WSMeasureModuleKind.bloodGlucose) return raw;
    if (kind == WSMeasureModuleKind.bloodPressure) return raw;
    if (kind == WSMeasureModuleKind.bloodOxygen && raw.startsWith('SpO₂ ')) {
      return raw.substring(5);
    }
    return raw.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = kind.accentColor(theme.colorScheme);
    final info = widget.controller.functionInfo;
    final showAuto = kind.autoMonitorAvailable(info);

    final showHrIntervals = kind == WSMeasureModuleKind.heartRate &&
        _autoEnabled &&
        _hrIntervals.length > 1;

    return Scaffold(
      key: kind.detailPageKey,
      appBar: AppBar(title: Text(kind.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncing)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.sync_problem_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('健康数据同步进行中'),
                          SizedBox(height: 4),
                          Text('同步期间 SDK 会拒绝新的点测开始。'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showAuto) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kind.autoMonitorLabel,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kind.autoMonitorHint,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoEnabled,
                          onChanged: busy ? null : _onAutoChanged,
                        ),
                      ],
                    ),
                    if (showHrIntervals) ...[
                      const SizedBox(height: 12),
                      Text('监测间隔', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final minutes in _hrIntervals)
                            ChoiceChip(
                              label: Text('$minutes 分钟'),
                              selected: _intervalMinutes == minutes,
                              onSelected: busy
                                  ? null
                                  : (_) => _onIntervalSelected(minutes),
                            ),
                        ],
                      ),
                    ] else if (_autoEnabled &&
                        kind != WSMeasureModuleKind.temperature &&
                        kind != WSMeasureModuleKind.pressure) ...[
                      const SizedBox(height: 8),
                      Text(
                        kind == WSMeasureModuleKind.heartRate
                            ? '当前间隔：${_intervalMinutes > 0 ? '$_intervalMinutes 分钟' : '设备默认'}'
                            : '设备读回间隔：${_intervalMinutes > 0 ? '$_intervalMinutes 分钟' : '未设置'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (kind == WSMeasureModuleKind.temperature) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('显示选项', style: theme.textTheme.titleSmall),
                    Row(
                      children: [
                        Switch(
                          value: _tempAdjust,
                          onChanged: busy ? null : (v) => setState(() => _tempAdjust = v),
                        ),
                        const Expanded(child: Text('温度补偿')),
                      ],
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _tempCelsius,
                          onChanged: busy ? null : (v) => setState(() => _tempCelsius = v),
                        ),
                        const Expanded(child: Text('摄氏单位')),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: busy ? null : _applyTempOptions,
                      child: const Text('应用显示选项'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (kind.supportsSpotMeasure) ...[
            WsMeasureSpotPanel(
              accent: accent,
              valueText: _spotDisplayValue,
              placeholderUnit: kind.spotUnitPlaceholder(widget.controller),
              statusText: _spotStatus,
              measuring: _spotMeasuring,
              busy: _spotBusy,
              blockStart: _syncing,
              onToggle: _toggleSpot,
              onCheck: kind.spotHasCheck ? _checkSpot : null,
            ),
            if (_spotError != null) ...[
              const SizedBox(height: 8),
              Text(
                describeWSDemoError(_spotError!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Text('测量记录', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_events.log.isEmpty)
              Text('暂无回调', style: theme.textTheme.bodySmall)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _events.log.reversed.take(8).join('\n\n'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '该指标仅支持自动监测，无点测入口。',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ...buildAsyncFeedback(context),
        ],
      ),
    );
  }
}
