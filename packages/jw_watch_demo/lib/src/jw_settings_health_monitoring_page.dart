import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_demo_dialogs.dart';
import 'jw_measure_auto_monitor.dart';
import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_widgets.dart';
import 'jw_settings_catalog.dart';

/// 健康与监测：对齐 App 分组/文案；条目始终展示，右侧 tag 标设备/SDK 状态。
class JwHealthMonitoringPage extends StatefulWidget {
  const JwHealthMonitoringPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwHealthMonitoringPage> createState() => _JwHealthMonitoringPageState();
}

class _JwHealthMonitoringPageState extends State<JwHealthMonitoringPage> {
  JWDemoController get controller => widget.controller;

  var _loading = false;
  String? _message;
  Object? _error;
  String? _actingId;

  bool _hrEnabled = false;
  int _hrInterval = 10;
  bool _bpEnabled = false;
  bool _spo2Enabled = false;
  bool _lowSpo2Enabled = false;
  bool _bloodSugarEnabled = false;
  bool _heatStressEnabled = false;
  int _heatStartHour = 8;
  int _heatStartMinute = 0;
  int _heatEndHour = 22;
  int _heatEndMinute = 0;
  bool _sleepAllEnabled = false;
  bool _temperatureEnabled = false;
  bool _pressureEnabled = false;
  bool _highHrAlarmEnabled = false;
  int _highHrAlarmValue = 180;

  List<int> get _hrIntervals => jwDemoHeartRateSupportIntervals(controller);

  JWDeviceFunctionInfo? get _functions => controller.state.functionInfo;

  /// null = 未知（未读到功能位）；false = 明确不支持。
  bool? _deviceSupport(List<JWDeviceFunction> required) {
    final info = _functions;
    if (info == null || required.isEmpty) return null;
    return required.any(info.supports);
  }

  Widget? _statusTag({
    required bool sdkReady,
    required List<JWDeviceFunction> requiredFunctions,
  }) {
    final device = _deviceSupport(requiredFunctions);
    if (device == false) {
      return const JwSettingsStatusChip(
        JwSettingsImplStatus.sdkReady,
        deviceUnsupported: true,
      );
    }
    if (!sdkReady) {
      return const JwSettingsStatusChip(JwSettingsImplStatus.sdkUnsupported);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _loadOne(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    await _loadOne(() async {
      final cfg = await controller.readHeartRateAutoMeasure();
      _hrEnabled = cfg.enabled;
      _hrInterval = jwDemoSnapHeartRateInterval(
        cfg.intervalMinutes <= 0 ? 10 : cfg.intervalMinutes,
        _hrIntervals,
      );
    });
    await _loadOne(() async {
      if (_deviceSupport([JWDeviceFunction.rtkBp3]) == false) return;
      final cfg = await controller.readBloodPressureAutoMeasure();
      _bpEnabled = cfg.enabled;
    });
    await _loadOne(() async {
      final cfg = await controller.readSpO2AutoMeasure();
      _spo2Enabled = cfg.enabled;
    });
    await _loadOne(() async {
      final cfg = await controller.readBloodSugarAutoMeasure();
      _bloodSugarEnabled = cfg.enabled;
    });
    await _loadOne(() async {
      final cfg = await controller.readTemperatureControl();
      _temperatureEnabled = cfg.enabled;
    });
    await _loadOne(() async {
      final cfg = await controller.readHeatStressReminder();
      _heatStressEnabled = cfg.enabled;
      _heatStartHour = cfg.schedule.startHour;
      _heatStartMinute = cfg.schedule.startMinute;
      _heatEndHour = cfg.schedule.endHour;
      _heatEndMinute = cfg.schedule.endMinute;
    });
    await _loadOne(() async {
      // App：rateReminder || highHrv 任一支持即可。
      if (_deviceSupport(const [
            JWDeviceFunction.rateReminder,
            JWDeviceFunction.highHrv,
          ]) ==
          false) {
        return;
      }
      final cfg = await controller.readHighHeartRateReminder();
      _highHrAlarmEnabled = cfg.enabled;
      _highHrAlarmValue = cfg.thresholdBpm;
    });
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// 单项操作：只更新该开关值，不把整页 Switch 置为 disabled（避免全页刷新感）。
  Future<void> _apply({
    required String id,
    required Future<void> Function() op,
    required VoidCallback revert,
  }) async {
    if (_actingId != null) return;
    _actingId = id;
    _error = null;
    _message = null;
    try {
      await op();
    } catch (e) {
      if (!mounted) return;
      revert();
      setState(() => _error = e);
    } finally {
      _actingId = null;
    }
  }

  void _sdkUnsupportedSnack(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title：SDK 未支持')),
    );
  }

  Future<void> _setHr(bool enabled) async {
    final previous = _hrEnabled;
    setState(() => _hrEnabled = enabled);
    await _apply(
      id: 'hr',
      revert: () {
        if (mounted) setState(() => _hrEnabled = previous);
      },
      op: () async {
        await controller.setHeartRateAutoMeasure(
          JWAutoMeasureConfig(
            enabled: enabled,
            intervalMinutes: _hrInterval,
          ),
        );
        if (!enabled && _temperatureEnabled) {
          setState(() => _temperatureEnabled = false);
          final current = await controller.readTemperatureControl();
          await controller.setTemperatureControl(
            JWTemperatureControlSetting(
              enabled: false,
              adjust: current.adjust,
              celsius: current.celsius,
            ),
          );
          if (!mounted) return;
          await JwDemoDialogs.showMessage(
            context,
            detail: '此操作将同时关闭温度自动检测',
            positiveText: '我知道了',
            hideNegative: true,
          );
        }
      },
    );
  }

  Future<void> _pickHrInterval() async {
    final selected = await JwDemoDialogs.showSinglePicker<int>(
      context,
      title: '间隔',
      values: _hrIntervals,
      labelOf: (v) => '$v',
      initial: _hrInterval,
      dataTips: '分钟',
    );
    if (selected == null || selected == _hrInterval || !mounted) return;
    final previous = _hrInterval;
    setState(() {
      _hrInterval = selected;
      _hrEnabled = true;
    });
    await _apply(
      id: 'hr_interval',
      revert: () {
        if (mounted) setState(() => _hrInterval = previous);
      },
      op: () async {
        await controller.setHeartRateAutoMeasure(
          JWAutoMeasureConfig(enabled: true, intervalMinutes: selected),
        );
      },
    );
  }

  Future<void> _setBp(bool enabled) async {
    if (_deviceSupport([JWDeviceFunction.rtkBp3]) == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备不支持血压自动监测')),
      );
      return;
    }
    final previous = _bpEnabled;
    setState(() => _bpEnabled = enabled);
    await _apply(
      id: 'bp',
      revert: () {
        if (mounted) setState(() => _bpEnabled = previous);
      },
      op: () async {
        await controller.setBloodPressureAutoMeasure(
          JWAutoMeasureConfig(enabled: enabled, intervalMinutes: 10),
        );
      },
    );
  }

  Future<void> _setSpO2(bool enabled) async {
    final previous = _spo2Enabled;
    setState(() => _spo2Enabled = enabled);
    await _apply(
      id: 'spo2',
      revert: () {
        if (mounted) setState(() => _spo2Enabled = previous);
      },
      op: () async {
        await controller.setSpO2AutoMeasure(
          JWAutoMeasureConfig(enabled: enabled, intervalMinutes: 1),
        );
      },
    );
  }

  void _setLowSpO2(bool enabled) {
    setState(() => _lowSpo2Enabled = enabled);
    _sdkUnsupportedSnack('低血氧报警');
  }

  Future<void> _setBloodSugar(bool enabled) async {
    final previous = _bloodSugarEnabled;
    setState(() => _bloodSugarEnabled = enabled);
    await _apply(
      id: 'blood_sugar',
      revert: () {
        if (mounted) setState(() => _bloodSugarEnabled = previous);
      },
      op: () async {
        await controller.setBloodSugarAutoMeasure(
          JWBloodSugarAutoMeasureConfig(
            enabled: enabled,
            intervalMinutes: 10,
          ),
        );
      },
    );
  }

  JWHeatStressReminder _heatStressValue({bool? enabled}) =>
      JWHeatStressReminder(
        enabled: enabled ?? _heatStressEnabled,
        schedule: JWTimeRange(
          startHour: _heatStartHour,
          startMinute: _heatStartMinute,
          endHour: _heatEndHour,
          endMinute: _heatEndMinute,
        ),
      );

  Future<void> _setHeatStress(bool enabled) async {
    final previous = _heatStressEnabled;
    setState(() => _heatStressEnabled = enabled);
    await _apply(
      id: 'heat_stress',
      revert: () {
        if (mounted) setState(() => _heatStressEnabled = previous);
      },
      op: () async {
        await controller.setHeatStressReminder(_heatStressValue(enabled: enabled));
      },
    );
  }

  Future<void> _pickHeatStressTime() async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heatStartHour, minute: _heatStartMinute),
      helpText: '开始时间',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heatEndHour, minute: _heatEndMinute),
      helpText: '结束时间',
    );
    if (end == null || !mounted) return;

    final prevStartH = _heatStartHour;
    final prevStartM = _heatStartMinute;
    final prevEndH = _heatEndHour;
    final prevEndM = _heatEndMinute;
    final prevEnabled = _heatStressEnabled;
    setState(() {
      _heatStartHour = start.hour;
      _heatStartMinute = start.minute;
      _heatEndHour = end.hour;
      _heatEndMinute = end.minute;
      _heatStressEnabled = true;
    });
    await _apply(
      id: 'heat_stress_time',
      revert: () {
        if (!mounted) return;
        setState(() {
          _heatStartHour = prevStartH;
          _heatStartMinute = prevStartM;
          _heatEndHour = prevEndH;
          _heatEndMinute = prevEndM;
          _heatStressEnabled = prevEnabled;
        });
      },
      op: () async {
        await controller.setHeatStressReminder(_heatStressValue(enabled: true));
      },
    );
  }

  void _setSleepAll(bool enabled) {
    setState(() => _sleepAllEnabled = enabled);
    _sdkUnsupportedSnack('全天睡眠');
  }

  Future<void> _setTemperature(bool enabled) async {
    final previous = _temperatureEnabled;
    setState(() => _temperatureEnabled = enabled);
    await _apply(
      id: 'temperature',
      revert: () {
        if (mounted) setState(() => _temperatureEnabled = previous);
      },
      op: () async {
        final current = await controller.readTemperatureControl();
        await controller.setTemperatureControl(
          JWTemperatureControlSetting(
            enabled: enabled,
            adjust: current.adjust,
            celsius: current.celsius,
          ),
        );
      },
    );
  }

  Future<void> _setPressure(bool enabled) async {
    final previous = _pressureEnabled;
    setState(() => _pressureEnabled = enabled);
    await _apply(
      id: 'pressure',
      revert: () {
        if (mounted) setState(() => _pressureEnabled = previous);
      },
      op: () async {
        await controller.setPressureAutoMeasure(enabled);
      },
    );
  }

  Future<void> _openHighHrAlarm() async {
    if (_deviceSupport(const [
          JWDeviceFunction.rateReminder,
          JWDeviceFunction.highHrv,
        ]) ==
        false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备不支持高心率警报')),
      );
      return;
    }
    final result = await Navigator.of(context).push<_HighHrAlarmResult>(
      MaterialPageRoute(
        builder: (_) => JwHighHeartRateAlarmPage(
          enabled: _highHrAlarmEnabled,
          maxRate: _highHrAlarmValue,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final previousEnabled = _highHrAlarmEnabled;
    final previousValue = _highHrAlarmValue;
    setState(() {
      _highHrAlarmEnabled = result.enabled;
      _highHrAlarmValue = result.maxRate;
    });
    await _apply(
      id: 'high_hr',
      revert: () {
        if (mounted) {
          setState(() {
            _highHrAlarmEnabled = previousEnabled;
            _highHrAlarmValue = previousValue;
          });
        }
      },
      op: () async {
        await controller.setHighHeartRateReminder(
          JWHighHeartRateReminder(
            enabled: result.enabled,
            thresholdBpm: result.maxRate,
          ),
        );
      },
    );
  }

  String get _highHrSummary =>
      _highHrAlarmEnabled ? '$_highHrAlarmValue 次/分' : '关闭';

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: JwSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
      backgroundColor: JwSettingsAppTheme.background,
      appBar: AppBar(
        title: const Text('健康与监测'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (_loading) const LinearProgressIndicator(),
          const JwSettingsSectionHeader('心脏健康'),
          JwSettingsCard(
            children: [
              _SwitchRow(
                keyName: 'jw.demo.health.hr',
                iconAsset: JwSettingsIcons.heartRate,
                title: '心率自动监测',
                apiCode: JwSettingsApiExamples.heartRateAuto,
                value: _hrEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.rate],
                ),
                onChanged: _setHr,
              ),
              _NavValueRow(
                keyName: 'jw.demo.health.hr_interval',
                indent: true,
                title: '间隔',
                apiCode: JwSettingsApiExamples.heartRateAuto,
                value: '$_hrInterval 分',
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.rate],
                ),
                onTap: _pickHrInterval,
              ),
              _NavValueRow(
                keyName: 'jw.demo.health.high_hr',
                iconAsset: JwSettingsIcons.highHeartRate,
                title: '高心率警报',
                apiCode: JwSettingsApiExamples.highHeartRate,
                value: _highHrSummary,
                // App UKBridge：rateReminder 或 highHrv 任一支持即可。
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [
                    JWDeviceFunction.rateReminder,
                    JWDeviceFunction.highHrv,
                  ],
                ),
                onTap: _openHighHrAlarm,
              ),
              _SwitchRow(
                keyName: 'jw.demo.health.bp',
                iconAsset: JwSettingsIcons.bloodPressure,
                title: '血压自动监测',
                apiCode: JwSettingsApiExamples.bloodPressureAuto,
                value: _bpEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [
                    JWDeviceFunction.rtkBp3,
                    JWDeviceFunction.bpDetection,
                  ],
                ),
                onChanged: _setBp,
              ),
            ],
          ),
          const JwSettingsSectionHeader('血氧'),
          JwSettingsCard(
            children: [
              _SwitchRow(
                keyName: 'jw.demo.health.spo2',
                iconAsset: JwSettingsIcons.spo2,
                title: '血氧自动监测',
                apiCode: JwSettingsApiExamples.spo2Auto,
                value: _spo2Enabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.spo2Continuous],
                ),
                onChanged: _setSpO2,
              ),
              _SwitchRow(
                keyName: 'jw.demo.health.low_spo2',
                iconAsset: JwSettingsIcons.lowSpo2,
                title: '低血氧报警',
                value: _lowSpo2Enabled,
                tag: _statusTag(
                  sdkReady: false,
                  requiredFunctions: const [JWDeviceFunction.hypoxia],
                ),
                onChanged: _setLowSpO2,
              ),
            ],
          ),
          const JwSettingsSectionHeader('血糖'),
          JwSettingsCard(
            children: [
              _SwitchRow(
                keyName: 'jw.demo.health.blood_sugar',
                iconAsset: JwSettingsIcons.bloodSugar,
                title: '血糖自动监测',
                apiCode: JwSettingsApiExamples.bloodSugarAuto,
                value: _bloodSugarEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.bloodSugar],
                ),
                onChanged: _setBloodSugar,
              ),
            ],
          ),
          const JwSettingsSectionHeader('高温健康提醒'),
          JwSettingsCard(
            children: [
              _SwitchRow(
                keyName: 'jw.demo.health.heat_stress',
                iconAsset: JwSettingsIcons.heatStress,
                title: '高温健康提醒',
                apiCode: JwSettingsApiExamples.heatStress,
                value: _heatStressEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.heatStress],
                ),
                onChanged: _setHeatStress,
              ),
              if (_heatStressEnabled)
                _NavValueRow(
                  keyName: 'jw.demo.health.heat_stress_time',
                  indent: true,
                  title: '提醒时间',
                  apiCode: JwSettingsApiExamples.heatStress,
                  value:
                      '${_formatTime(_heatStartHour, _heatStartMinute)} - ${_formatTime(_heatEndHour, _heatEndMinute)}',
                  tag: _statusTag(
                    sdkReady: true,
                    requiredFunctions: const [JWDeviceFunction.heatStress],
                  ),
                  onTap: _pickHeatStressTime,
                ),
            ],
          ),
          const JwSettingsSectionHeader('其他'),
          JwSettingsCard(
            children: [
              _SwitchRow(
                keyName: 'jw.demo.health.sleep_all',
                iconAsset: JwSettingsIcons.sleepAll,
                title: '全天睡眠',
                value: _sleepAllEnabled,
                tag: _statusTag(
                  sdkReady: false,
                  requiredFunctions: const [JWDeviceFunction.sleepAll],
                ),
                onChanged: _setSleepAll,
              ),
              _SwitchRow(
                keyName: 'jw.demo.health.temperature',
                iconAsset: JwSettingsIcons.temperature,
                title: '温度自动监测',
                apiCode: JwSettingsApiExamples.temperatureAuto,
                value: _temperatureEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.temperature],
                ),
                onChanged: _setTemperature,
              ),
              _SwitchRow(
                keyName: 'jw.demo.health.pressure',
                iconAsset: JwSettingsIcons.pressure,
                title: '压力自动监测',
                apiCode: JwSettingsApiExamples.pressureAuto,
                value: _pressureEnabled,
                tag: _statusTag(
                  sdkReady: true,
                  requiredFunctions: const [JWDeviceFunction.pressure],
                ),
                onChanged: _setPressure,
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _message!,
                style: const TextStyle(color: JwSettingsAppTheme.subtitle),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                describeJWDemoError(_error!),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.keyName,
    required this.title,
    required this.value,
    required this.onChanged,
    this.iconAsset,
    this.tag,
    this.apiCode,
  });

  final String keyName;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? iconAsset;
  final Widget? tag;
  final String? apiCode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key(keyName),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 8,
      leading: iconAsset == null
          ? null
          : SizedBox(
              width: 24,
              height: 24,
              child: JwSettingsIcons.image(iconAsset!, width: 22, height: 22),
            ),
      title: Row(
        children: [
          Flexible(
            child: apiCode == null
                ? Text(title, style: JwSettingsAppTheme.reminderTitle)
                : JwSettingsApiTitle(
                    title: title,
                    apiCode: apiCode!,
                    style: JwSettingsAppTheme.reminderTitle,
                  ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            tag!,
          ],
        ],
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _NavValueRow extends StatelessWidget {
  const _NavValueRow({
    required this.keyName,
    required this.title,
    required this.value,
    required this.onTap,
    this.iconAsset,
    this.indent = false,
    this.tag,
    this.apiCode,
  });

  final String keyName;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final String? iconAsset;
  final bool indent;
  final Widget? tag;
  final String? apiCode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key(keyName),
      contentPadding: EdgeInsets.fromLTRB(indent ? 52 : 16, 4, 16, 4),
      leading: indent || iconAsset == null
          ? null
          : SizedBox(
              width: 24,
              height: 24,
              child: JwSettingsIcons.image(iconAsset!, width: 22, height: 22),
            ),
      title: Row(
        children: [
          Flexible(
            child: apiCode == null
                ? Text(
                    title,
                    style: indent
                        ? JwSettingsAppTheme.itemSubTitle
                        : JwSettingsAppTheme.itemTitle,
                  )
                : JwSettingsApiTitle(
                    title: title,
                    apiCode: apiCode!,
                    style: indent
                        ? JwSettingsAppTheme.itemSubTitle
                        : JwSettingsAppTheme.itemTitle,
                  ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            tag!,
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: JwSettingsAppTheme.itemValue),
          const SizedBox(width: 6),
          JwSettingsIcons.image(
            JwSettingsIcons.chevronGray,
            width: 8,
            height: 14,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _HighHrAlarmResult {
  const _HighHrAlarmResult({required this.enabled, required this.maxRate});
  final bool enabled;
  final int maxRate;
}

/// 对齐 App「心率区间及提醒」二级页。
class JwHighHeartRateAlarmPage extends StatefulWidget {
  const JwHighHeartRateAlarmPage({
    super.key,
    required this.enabled,
    required this.maxRate,
  });

  final bool enabled;
  final int maxRate;

  @override
  State<JwHighHeartRateAlarmPage> createState() =>
      _JwHighHeartRateAlarmPageState();
}

class _JwHighHeartRateAlarmPageState extends State<JwHighHeartRateAlarmPage> {
  late bool _enabled = widget.enabled;
  late int _maxRate = widget.maxRate;

  static final _bpmValues = [for (var i = 100; i <= 220; i += 5) i];

  Future<void> _pickMaxRate() async {
    final selected = await JwDemoDialogs.showSinglePicker<int>(
      context,
      title: '最高心率',
      values: _bpmValues,
      labelOf: (v) => '$v',
      initial: _maxRate.clamp(100, 220),
      dataTips: '次/分',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _maxRate = selected;
      _enabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JwSettingsAppTheme.background,
      appBar: AppBar(
        title: const Text('心率区间及提醒'),
        centerTitle: true,
        backgroundColor: JwSettingsAppTheme.card,
        foregroundColor: JwSettingsAppTheme.title,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: JwSettingsAppTheme.title,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: JwSettingsAppTheme.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _HighHrAlarmResult(enabled: _enabled, maxRate: _maxRate),
            ),
            child: const Text('完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          JwSettingsCard(
            children: [
              SwitchListTile(
                key: const Key('jw.demo.health.high_hr.switch'),
                title: const Text('高心率警报'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              ListTile(
                title: const Text('最高心率'),
                trailing: Text(
                  '$_maxRate',
                  style: const TextStyle(color: Color(0xFF818181)),
                ),
                onTap: _pickMaxRate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
