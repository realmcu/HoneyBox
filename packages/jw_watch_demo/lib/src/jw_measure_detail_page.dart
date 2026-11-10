import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_async_mixin.dart';
import 'jw_demo_controller.dart';
import 'jw_demo_log.dart';
import 'jw_measure_auto_monitor.dart';
import 'jw_measure_module.dart';
import 'jw_measure_spot_panel.dart';
import 'jw_scoped_measure_listener.dart';

class JWMeasureDetailPage extends StatefulWidget {
  const JWMeasureDetailPage({
    super.key,
    required this.controller,
    required this.kind,
  });

  final JWDemoController controller;
  final JWMeasureModuleKind kind;

  @override
  State<JWMeasureDetailPage> createState() => _JWMeasureDetailPageState();
}

class _JWMeasureDetailPageState extends State<JWMeasureDetailPage>
    with JwDemoAsyncMixin {
  late final JwScopedMeasureListener _events;

  bool _autoEnabled = false;
  int _intervalMinutes = 10;
  List<int> _hrIntervals = kJwDemoFallbackHeartRateIntervals;

  bool _tempAdjust = false;
  bool _tempCelsius = true;

  bool _spotMeasuring = false;
  bool _spotBusy = false;
  Object? _spotError;

  JWWatchSession? _attachedSession;

  JWMeasureModuleKind get kind => widget.kind;

  bool get _syncing => widget.controller.isHealthSyncActive;

  @override
  void initState() {
    super.initState();
    _events = JwScopedMeasureListener(kind);
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
        JwDemoLog.info('measure page session ready kind=$kind');
        _events.attach(session);
      }
    } else {
      if (_attachedSession != null) {
        JwDemoLog.info('measure page session lost kind=$kind');
      }
      _attachedSession = null;
      _events.detach();
    }
  }

  Future<void> _refreshAutoConfig() => run(() async {
        switch (kind) {
          case JWMeasureModuleKind.heartRate:
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
          case JWMeasureModuleKind.bloodOxygen:
            final cfg = await widget.controller.readSpO2AutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case JWMeasureModuleKind.bloodPressure:
            final cfg = await widget.controller.readBloodPressureAutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case JWMeasureModuleKind.bloodGlucose:
            final cfg = await widget.controller.readBloodSugarAutoMeasure();
            _autoEnabled = cfg.enabled;
            _intervalMinutes = cfg.intervalMinutes > 0
                ? cfg.intervalMinutes
                : jwDemoDefaultAutoIntervalMinutes(kind);
          case JWMeasureModuleKind.temperature:
            final cfg = await widget.controller.readTemperatureControl();
            _autoEnabled = cfg.enabled;
            _tempAdjust = cfg.adjust;
            _tempCelsius = cfg.celsius;
          case JWMeasureModuleKind.pressure:
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
      case JWMeasureModuleKind.heartRate:
        await widget.controller.setHeartRateAutoMeasure(
          JWAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes,
          ),
        );
      case JWMeasureModuleKind.bloodOxygen:
        await widget.controller.setSpO2AutoMeasure(
          JWAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case JWMeasureModuleKind.bloodPressure:
        await widget.controller.setBloodPressureAutoMeasure(
          JWAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case JWMeasureModuleKind.bloodGlucose:
        await widget.controller.setBloodSugarAutoMeasure(
          JWBloodSugarAutoMeasureConfig(
            enabled: _autoEnabled,
            intervalMinutes: _intervalMinutes.clamp(1, 255),
          ),
        );
      case JWMeasureModuleKind.temperature:
        await widget.controller.setTemperatureControl(
          JWTemperatureControlSetting(
            enabled: _autoEnabled,
            adjust: _tempAdjust,
            celsius: _tempCelsius,
          ),
        );
      case JWMeasureModuleKind.pressure:
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
    JwDemoLog.info('spot START kind=$kind');
    switch (kind) {
      case JWMeasureModuleKind.heartRate:
        await widget.controller.startHeartRateMeasure();
      case JWMeasureModuleKind.bloodOxygen:
        await widget.controller.startSpO2SpotMeasure();
      case JWMeasureModuleKind.bloodPressure:
        await widget.controller.startBloodPressureSpotMeasure();
      case JWMeasureModuleKind.temperature:
        await widget.controller.startTemperatureSpotMeasure();
      case JWMeasureModuleKind.bloodGlucose:
        await widget.controller.startBloodGlucoseSpotMeasure();
      case JWMeasureModuleKind.pressure:
        break;
    }
  }

  Future<void> _stopSpot() async {
    JwDemoLog.info('spot STOP kind=$kind');
    switch (kind) {
      case JWMeasureModuleKind.heartRate:
        await widget.controller.stopHeartRateMeasure();
      case JWMeasureModuleKind.bloodOxygen:
        await widget.controller.stopSpO2SpotMeasure();
      case JWMeasureModuleKind.bloodPressure:
        await widget.controller.stopBloodPressureSpotMeasure();
      case JWMeasureModuleKind.temperature:
        await widget.controller.stopTemperatureSpotMeasure();
      case JWMeasureModuleKind.bloodGlucose:
        await widget.controller.stopBloodGlucoseSpotMeasure();
      case JWMeasureModuleKind.pressure:
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
          case JWMeasureModuleKind.bloodOxygen:
            await widget.controller.checkSpO2SpotMeasure();
          case JWMeasureModuleKind.temperature:
            await widget.controller.checkTemperatureSpotMeasure();
          default:
            break;
        }
      });

  Future<void> _applyTempOptions() => run(() async {
        await widget.controller.setTemperatureControl(
          JWTemperatureControlSetting(
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
    if (kind == JWMeasureModuleKind.bloodGlucose) return raw;
    if (kind == JWMeasureModuleKind.bloodPressure) return raw;
    if (kind == JWMeasureModuleKind.bloodOxygen && raw.startsWith('SpO₂ ')) {
      return raw.substring(5);
    }
    return raw.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = kind.accentColor(theme.colorScheme);
    final info = widget.controller.state.functionInfo;
    final showAuto = kind.autoMonitorAvailable(info);

    final showHrIntervals = kind == JWMeasureModuleKind.heartRate &&
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
                        kind != JWMeasureModuleKind.temperature &&
                        kind != JWMeasureModuleKind.pressure) ...[
                      const SizedBox(height: 8),
                      Text(
                        kind == JWMeasureModuleKind.heartRate
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
          if (kind == JWMeasureModuleKind.temperature) ...[
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
            JwMeasureSpotPanel(
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
                describeJWDemoError(_spotError!),
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
