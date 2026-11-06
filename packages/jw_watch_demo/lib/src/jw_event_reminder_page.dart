import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_demo_dialogs.dart';
import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_widgets.dart';

/// 对齐 App `EventReminderActivity`：久坐提醒卡片式展开；
/// Demo 将勿扰模式一并放入本页（UI 同样参照久坐卡片）。
/// 喝水 / 吃药为老能力，当前产品设备不支持，Demo 不展示。
class JwEventReminderPage extends StatefulWidget {
  const JwEventReminderPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwEventReminderPage> createState() => _JwEventReminderPageState();
}

class _JwEventReminderPageState extends State<JwEventReminderPage> {
  JWSedentaryReminder? _sedentary;
  JWDoNotDisturb? _dnd;
  bool _busy = false;
  Object? _error;
  String? _result;

  bool get _supportsSedentary =>
      widget.controller.state.functionInfo
          ?.supports(JWDeviceFunction.longSitReminder) ??
      true;

  bool get _supportsDnd =>
      widget.controller.state.functionInfo
          ?.supports(JWDeviceFunction.disturb) ??
      true;

  static final _intervalMinutes = [for (var i = 30; i <= 240; i++) i];

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _run(Future<void> Function() op) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read() => _run(() async {
        JWSedentaryReminder? sedentary;
        JWDoNotDisturb? dnd;
        if (_supportsSedentary) {
          sedentary = await widget.controller.readSedentaryReminder();
        }
        if (_supportsDnd) {
          dnd = await widget.controller.readDoNotDisturb();
        }
        if (!mounted) return;
        setState(() {
          _sedentary = sedentary;
          _dnd = dnd;
          _result = '已读取事件提醒。';
        });
      });

  Future<void> _saveSedentary(JWSedentaryReminder value) async {
    final previous = _sedentary;
    setState(() => _sedentary = value);
    await _run(() async {
      try {
        final verified = await widget.controller.setSedentaryReminder(value);
        if (!mounted) return;
        setState(() {
          _sedentary = verified.value;
          _result = '久坐提醒已写入并读回。';
        });
      } catch (_) {
        if (mounted) setState(() => _sedentary = previous);
        rethrow;
      }
    });
  }

  Future<void> _saveDnd(JWDoNotDisturb value) async {
    final previous = _dnd;
    setState(() => _dnd = value);
    await _run(() async {
      try {
        final verified = await widget.controller.setDoNotDisturb(value);
        if (!mounted) return;
        setState(() {
          _dnd = verified.value;
          _result = '勿扰模式已写入并读回。';
        });
      } catch (_) {
        if (mounted) setState(() => _dnd = previous);
        rethrow;
      }
    });
  }

  Future<void> _pickSedentaryHours() async {
    final current = _sedentary;
    if (current == null || _busy) return;
    // JW 协议久坐仅小时；UI 与 App / 勿扰一致走时分双列，分钟展示为 00。
    // 未设置时默认 09:00 - 18:00。
    final useDefault = current.startHour == 0 && current.endHour == 0;
    final picked = await JwDemoDialogs.showSelectTime(
      context,
      startHour: useDefault ? 9 : current.startHour,
      startMinute: 0,
      endHour: useDefault ? 18 : current.endHour,
      endMinute: 0,
    );
    if (picked == null || !mounted) return;
    await _saveSedentary(JWSedentaryReminder(
      enabled: current.enabled,
      thresholdMinutes: current.thresholdMinutes,
      notifyHour: current.notifyHour,
      startHour: picked.startHour,
      endHour: picked.endHour,
      repeatDays: current.repeatDays,
    ));
  }

  Future<void> _pickSedentaryInterval() async {
    final current = _sedentary;
    if (current == null || _busy) return;
    final picked = await JwDemoDialogs.showSinglePicker<int>(
      context,
      title: '提醒间隔',
      values: _intervalMinutes,
      labelOf: (v) => '$v',
      initial: current.thresholdMinutes.clamp(30, 240),
      dataTips: '分钟',
    );
    if (picked == null || !mounted) return;
    await _saveSedentary(JWSedentaryReminder(
      enabled: current.enabled,
      thresholdMinutes: picked,
      notifyHour: current.notifyHour,
      startHour: current.startHour,
      endHour: current.endHour,
      repeatDays: current.repeatDays,
    ));
  }

  Future<void> _pickDndRange() async {
    final current = _dnd;
    if (current == null || _busy) return;
    final schedule = current.schedule;
    final picked = await JwDemoDialogs.showSelectTime(
      context,
      startHour: schedule.startHour,
      startMinute: schedule.startMinute,
      endHour: schedule.endHour,
      endMinute: schedule.endMinute,
    );
    if (picked == null || !mounted) return;
    await _saveDnd(JWDoNotDisturb(
      enabled: current.enabled,
      schedule: JWTimeRange(
        startHour: picked.startHour,
        startMinute: picked.startMinute,
        endHour: picked.endHour,
        endMinute: picked.endMinute,
      ),
    ));
  }

  String _hhmm(int hour, [int minute = 0]) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sedentary = _sedentary;
    final dnd = _dnd;
    return Theme(
      data: JwSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: JwSettingsAppTheme.background,
        appBar: AppBar(
          title: const Text('事件提醒'),
          actions: [
            IconButton(
              key: const Key('jw.demo.settings.event.api'),
              tooltip: '公开 API',
              onPressed: () => unawaited(
                JwSettingsApiTitle.show(
                  context,
                  title: '事件提醒',
                  apiCode: JwSettingsApiExamples.eventRemind,
                ),
              ),
              icon: const Icon(Icons.code),
            ),
            IconButton(
              onPressed: _busy ? null : _read,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_supportsSedentary)
              _ReminderExpandCard(
                key: const Key('jw.demo.settings.event.sedentary'),
                iconAsset: JwSettingsIcons.longSit,
                // App `activity_event_reminder` 久坐图标 19x24。
                iconWidth: 19,
                iconHeight: 24,
                title: '久坐提醒',
                enabled: sedentary?.enabled ?? false,
                busy: _busy || sedentary == null,
                onChanged: sedentary == null
                    ? null
                    : (value) {
                        final useDefault =
                            sedentary.startHour == 0 && sedentary.endHour == 0;
                        _saveSedentary(JWSedentaryReminder(
                          enabled: value,
                          thresholdMinutes: sedentary.thresholdMinutes,
                          notifyHour: sedentary.notifyHour,
                          startHour: useDefault && value
                              ? 9
                              : sedentary.startHour,
                          endHour:
                              useDefault && value ? 18 : sedentary.endHour,
                          repeatDays: sedentary.repeatDays,
                        ));
                      },
                details: sedentary == null || !sedentary.enabled
                    ? const []
                    : [
                        _DetailRow(
                          label: '提醒时间',
                          value:
                              '${_hhmm(sedentary.startHour)} - ${_hhmm(sedentary.endHour)}',
                          onTap: _busy ? null : _pickSedentaryHours,
                        ),
                        _DetailRow(
                          label: '间隔',
                          value: '${sedentary.thresholdMinutes} 分钟',
                          onTap: _busy ? null : _pickSedentaryInterval,
                        ),
                      ],
              ),
            if (_supportsDnd) ...[
              const SizedBox(height: 12),
              _ReminderExpandCard(
                key: const Key('jw.demo.settings.event.dnd'),
                iconAsset: JwSettingsIcons.doNotDisturb,
                title: '勿扰模式',
                enabled: dnd?.enabled ?? false,
                busy: _busy || dnd == null,
                onChanged: dnd == null
                    ? null
                    : (value) => _saveDnd(JWDoNotDisturb(
                          enabled: value,
                          schedule: dnd.schedule,
                        )),
                details: dnd == null || !dnd.enabled
                    ? const []
                    : [
                        _DetailRow(
                          label: '提醒时间',
                          value:
                              '${_hhmm(dnd.schedule.startHour, dnd.schedule.startMinute)} - ${_hhmm(dnd.schedule.endHour, dnd.schedule.endMinute)}',
                          onTap: _busy ? null : _pickDndRange,
                        ),
                      ],
              ),
            ],
            if (!_supportsSedentary && !_supportsDnd)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  '当前设备不支持久坐提醒与勿扰模式。',
                  style: TextStyle(color: JwSettingsAppTheme.subtitle),
                ),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: const TextStyle(color: JwSettingsAppTheme.subtitle),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                describeJWDemoError(_error!),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderExpandCard extends StatelessWidget {
  const _ReminderExpandCard({
    super.key,
    required this.iconAsset,
    this.iconWidth = 22,
    this.iconHeight = 22,
    required this.title,
    required this.enabled,
    required this.busy,
    required this.onChanged,
    required this.details,
  });

  final String iconAsset;
  final double iconWidth;
  final double iconHeight;
  final String title;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool>? onChanged;
  final List<_DetailRow> details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JwSettingsAppTheme.card,
      borderRadius: BorderRadius.circular(JwSettingsAppTheme.itemRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  JwSettingsIcons.image(
                    iconAsset,
                    width: iconWidth,
                    height: iconHeight,
                    fallback: Icons.event_note_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: JwSettingsAppTheme.itemTitle),
                  ),
                  Switch(
                    value: enabled,
                    // 忙时不切 disabled，避免整页开关样式抖动；回调内忽略。
                    onChanged: onChanged == null
                        ? null
                        : (value) {
                            if (busy) return;
                            onChanged!(value);
                          },
                  ),
                ],
              ),
            ),
          ),
          ...details,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        child: Row(
          children: [
            Text(label, style: JwSettingsAppTheme.itemSubTitle),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: JwSettingsAppTheme.subtitle,
              ),
            ),
            const SizedBox(width: 8),
            JwSettingsIcons.image(
              JwSettingsIcons.chevronGray,
              width: 8,
              height: 14,
              fallback: Icons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }
}
