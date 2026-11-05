import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_content_sheet.dart';
import 'jw_demo_controller.dart';

/// Opens the settings hub as a full-screen route (not a bottom sheet).
void openJwSettingsHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWSettingsHubPage(controller: controller),
      ),
    ),
  );
}

/// Hub: simple controls inline; complex areas open dedicated sub-pages.
class JWSettingsHubPage extends StatefulWidget {
  const JWSettingsHubPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JWSettingsHubPage> createState() => _JWSettingsHubPageState();
}

class _JWSettingsHubPageState extends State<JWSettingsHubPage>
    with _DemoAsyncMixin {
  JWLanguage? _language;
  JWHourSystem? _hourSystem;
  JWUnitSystem? _unitSystem;

  bool get _available => widget.controller.state.isReady;

  @override
  void initState() {
    super.initState();
    if (_available) {
      unawaited(_readBasics());
    }
  }

  Future<void> _readBasics() => run(() async {
        final language = await widget.controller.readLanguage();
        final hourSystem = await widget.controller.readHourSystem();
        final unitSystem = await widget.controller.readUnitSystem();
        if (!mounted) return;
        setState(() {
          _language = language;
          _hourSystem = hourSystem;
          _unitSystem = unitSystem;
          resultMessage = '已读取基础设置。';
        });
      });

  void _openDisplay() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWDisplaySettingsPage(controller: widget.controller),
      ),
    ));
  }

  void _openReminders() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWRemindersSettingsPage(controller: widget.controller),
      ),
    ));
  }

  void _openAlarms() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWAlarmsSettingsPage(controller: widget.controller),
      ),
    ));
  }

  void _openProfileGoals() {
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWProfileGoalsPage(controller: widget.controller),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('用户与设备设置')),
      body: !_available
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('请先完成登录或首次绑定。设置功能只在已认证会话中可用。'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '简单项可直接在本页修改；复杂项进入下级页面。点标题可查看公开 API。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('jw.demo.settings.read'),
                  onPressed: busy ? null : _readBasics,
                  icon: const Icon(Icons.refresh),
                  label: const Text('读取基础设置'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SettingsApiTitle(
                          title: '设备语言',
                          apiCode:
                              'final language = await session.readLanguage();\nawait session.setLanguageVerified(JWLanguage.simplifiedChinese);',
                        ),
                        DropdownButtonFormField<JWLanguage>(
                          key: const Key('jw.demo.settings.language'),
                          value: _language,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '当前语言',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('先读取，或直接选择写入'),
                          items: [
                            for (final value in JWLanguage.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_languageName(value)),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  run(() async {
                                    await widget.controller.setLanguage(value);
                                    if (mounted) {
                                      setState(() {
                                        _language = value;
                                        resultMessage = '语言已读回验证。';
                                      });
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        _SettingsApiTitle(
                          title: '时间制式',
                          apiCode:
                              'await session.setHourSystemVerified(JWHourSystem.h24);',
                        ),
                        DropdownButtonFormField<JWHourSystem>(
                          key: const Key('jw.demo.settings.hour_system'),
                          value: _hourSystem,
                          decoration: const InputDecoration(
                            labelText: '12 / 24 小时',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: JWHourSystem.h24,
                              child: Text('24 小时制'),
                            ),
                            DropdownMenuItem(
                              value: JWHourSystem.h12,
                              child: Text('12 小时制'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  run(() async {
                                    await widget.controller.setHourSystem(value);
                                    if (mounted) {
                                      setState(() {
                                        _hourSystem = value;
                                        resultMessage = '时间制式已读回验证。';
                                      });
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        _SettingsApiTitle(
                          title: '单位制',
                          apiCode:
                              'await session.setUnitSystemVerified(JWUnitSystem.metric);',
                        ),
                        DropdownButtonFormField<JWUnitSystem>(
                          key: const Key('jw.demo.settings.unit_system'),
                          value: _unitSystem,
                          decoration: const InputDecoration(
                            labelText: '公制 / 英制',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: JWUnitSystem.metric,
                              child: Text('公制'),
                            ),
                            DropdownMenuItem(
                              value: JWUnitSystem.imperial,
                              child: Text('英制'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  run(() async {
                                    await widget.controller.setUnitSystem(value);
                                    if (mounted) {
                                      setState(() {
                                        _unitSystem = value;
                                        resultMessage = '单位制已读回验证。';
                                      });
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        _SettingsApiTitle(
                          title: '同步当前时间',
                          apiCode: 'await session.setTime(DateTime.now());',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('jw.demo.settings.sync_time'),
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                      await widget.controller.syncTime();
                                      if (mounted) {
                                        setState(() => resultMessage =
                                            '当前时间已提交给设备，协议不支持读回确认。');
                                      }
                                    }),
                            icon: const Icon(Icons.schedule),
                            label: const Text('同步当前时间'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsNavTile(
                  keyName: 'jw.demo.settings.display',
                  title: '显示设置',
                  subtitle: '日期格式、亮屏、亮度、主页与抬腕亮屏',
                  apiCode: 'await session.setScreenBrightness(80);',
                  onOpen: _openDisplay,
                ),
                _SettingsNavTile(
                  keyName: 'jw.demo.settings.reminders',
                  title: '提醒与勿扰',
                  subtitle: '勿扰时段、久坐提醒',
                  apiCode: '''final dnd = await session.readDoNotDisturb();
await session.setDoNotDisturbVerified(dnd);''',
                  onOpen: _openReminders,
                ),
                _SettingsNavTile(
                  keyName: 'jw.demo.settings.alarms',
                  title: '闹钟',
                  subtitle: '按设备能力读取/整表写入（标准或标签闹钟）',
                  apiCode:
                      'await session.setAlarms(alarms); // replaces full table',
                  onOpen: _openAlarms,
                ),
                _SettingsNavTile(
                  keyName: 'jw.demo.settings.profile_goals',
                  title: '用户资料与目标',
                  subtitle: '身高、体重、年龄与每日目标',
                  apiCode: '''await session.setUserProfile(profile);
await session.setGoals(const JWGoals(steps: 8000, sleepMinutes: 480, calories: 400));''',
                  onOpen: _openProfileGoals,
                ),
                ...buildAsyncFeedback(context),
              ],
            ),
    );
  }
}

class JWDisplaySettingsPage extends StatefulWidget {
  const JWDisplaySettingsPage({super.key, required this.controller});
  final JWDemoController controller;

  @override
  State<JWDisplaySettingsPage> createState() => _JWDisplaySettingsPageState();
}

class _JWDisplaySettingsPageState extends State<JWDisplaySettingsPage>
    with _DemoAsyncMixin {
  // Values prepared for the next command, not inferred device state. Stable
  // JW firmware ACKs these writes but does not always support their reads.
  JWDateFormat _dateFormat = JWDateFormat.monthDay;
  int _screenLightDuration = 10;
  int _screenBrightness = 60;
  int _homePage = 0;
  bool _turnWristToWake = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _SettingsApiTitle(
            title: '显示设置',
            apiCode: '''await session.setScreenBrightness(80);
await session.setTurnWristToWake(true);''',
            compact: true,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择后立即下发。设备不会稳定提供以下设置的当前值读取接口，因此页面显示的是准备下发的值。'),
            const SizedBox(height: 16),
            DropdownButtonFormField<JWDateFormat>(
              value: _dateFormat,
              decoration: const InputDecoration(labelText: '日期格式'),
              items: const [
                DropdownMenuItem(
                  value: JWDateFormat.monthDay,
                  child: Text('月/日'),
                ),
                DropdownMenuItem(
                  value: JWDateFormat.dayMonth,
                  child: Text('日/月'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      run(() async {
                        await widget.controller.setDateFormat(value);
                        if (mounted) {
                          setState(() {
                            _dateFormat = value;
                            resultMessage = '日期格式已下发。';
                          });
                        }
                      });
                    },
            ),
            DropdownButtonFormField<int>(
              value: _screenLightDuration,
              decoration: const InputDecoration(labelText: '亮屏时长'),
              items: [
                for (final seconds in [3, 5, 10, 15, 20, 30])
                  DropdownMenuItem(value: seconds, child: Text('$seconds 秒')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      run(() async {
                        await widget.controller.setScreenLightDuration(value);
                        if (mounted) {
                          setState(() {
                            _screenLightDuration = value;
                            resultMessage = '亮屏时长已下发。';
                          });
                        }
                      });
                    },
            ),
            DropdownButtonFormField<int>(
              value: _screenBrightness,
              decoration: const InputDecoration(labelText: '屏幕亮度'),
              items: [
                for (final value in [20, 40, 60, 80, 100])
                  DropdownMenuItem(value: value, child: Text('$value%')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      run(() async {
                        await widget.controller.setScreenBrightness(value);
                        if (mounted) {
                          setState(() {
                            _screenBrightness = value;
                            resultMessage = '屏幕亮度已下发。';
                          });
                        }
                      });
                    },
            ),
            DropdownButtonFormField<int>(
              value: _homePage,
              decoration: const InputDecoration(labelText: '设备主页索引'),
              items: [
                for (final value in [0, 1, 2, 3, 4, 5])
                  DropdownMenuItem(value: value, child: Text('主页 $value')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      run(() async {
                        await widget.controller.setHomePage(value);
                        if (mounted) {
                          setState(() {
                            _homePage = value;
                            resultMessage = '设备主页已下发。';
                          });
                        }
                      });
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('抬腕亮屏'),
              value: _turnWristToWake,
              onChanged: busy
                  ? null
                  : (value) => run(() async {
                        await widget.controller.setTurnWristToWake(value);
                        if (mounted) {
                          setState(() {
                            _turnWristToWake = value;
                            resultMessage = '抬腕亮屏已下发。';
                          });
                        }
                      }),
            ),
            ...buildAsyncFeedback(context),
          ],
        ),
      );
}

class JWRemindersSettingsPage extends StatefulWidget {
  const JWRemindersSettingsPage({super.key, required this.controller});
  final JWDemoController controller;

  @override
  State<JWRemindersSettingsPage> createState() =>
      _JWRemindersSettingsPageState();
}

class _JWRemindersSettingsPageState extends State<JWRemindersSettingsPage>
    with _DemoAsyncMixin {
  JWDoNotDisturb? _doNotDisturb;
  JWSedentaryReminder? _sedentaryReminder;

  Future<void> _read() => run(() async {
        final dnd = await widget.controller.readDoNotDisturb();
        final sedentary = await widget.controller.readSedentaryReminder();
        if (!mounted) return;
        setState(() {
          _doNotDisturb = dnd;
          _sedentaryReminder = sedentary;
          resultMessage = '已读取提醒设置。';
        });
      });

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  Widget build(BuildContext context) {
    final dnd = _doNotDisturb;
    final sedentary = _sedentaryReminder;
    return Scaffold(
      appBar: AppBar(
        title: _SettingsApiTitle(
          title: '提醒与勿扰',
          apiCode: 'await session.setSedentaryReminderVerified(reminder);',
          compact: true,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : _read,
            icon: const Icon(Icons.refresh),
            label: const Text('重新读取'),
          ),
          const SizedBox(height: 16),
          if (dnd != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('勿扰 ${_timeRangeLabel(dnd.schedule)}'),
              value: dnd.enabled,
              onChanged: busy
                  ? null
                  : (enabled) => run(() async {
                        final value = JWDoNotDisturb(
                          enabled: enabled,
                          schedule: dnd.schedule,
                        );
                        await widget.controller.setDoNotDisturb(value);
                        if (mounted) setState(() => _doNotDisturb = value);
                      }),
            ),
          ],
          if (sedentary != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('久坐提醒（${sedentary.thresholdMinutes} 分钟）'),
              subtitle: Text(
                  '${sedentary.startHour}:00–${sedentary.endHour}:00'),
              value: sedentary.enabled,
              onChanged: busy
                  ? null
                  : (enabled) => run(() async {
                        final current = sedentary;
                        final value = JWSedentaryReminder(
                          enabled: enabled,
                          thresholdMinutes: current.thresholdMinutes,
                          notifyHour: current.notifyHour,
                          startHour: current.startHour,
                          endHour: current.endHour,
                          repeatDays: current.repeatDays,
                        );
                        await widget.controller.setSedentaryReminder(value);
                        if (mounted) {
                          setState(() => _sedentaryReminder = value);
                        }
                      }),
            ),
          ],
          if (dnd == null && sedentary == null && !busy)
            const Text('暂无数据，请先读取。'),
          ...buildAsyncFeedback(context),
        ],
      ),
    );
  }
}

class JWAlarmsSettingsPage extends StatefulWidget {
  const JWAlarmsSettingsPage({super.key, required this.controller});
  final JWDemoController controller;

  @override
  State<JWAlarmsSettingsPage> createState() => _JWAlarmsSettingsPageState();
}

class _JWAlarmsSettingsPageState extends State<JWAlarmsSettingsPage>
    with _DemoAsyncMixin {
  List<JWAlarm> _alarms = const [];
  Set<int> _deviceAlarmIds = const {};

  bool get _labeledAlarms =>
      widget.controller.state.functionInfo?.supports(JWDeviceFunction.alarm2) ??
      false;

  Future<void> _read() => run(() async {
        final alarms = await widget.controller.readAlarms();
        if (!mounted) return;
        setState(() {
          _alarms = List<JWAlarm>.from(alarms);
          _deviceAlarmIds = alarms.map((alarm) => alarm.id).toSet();
          resultMessage = '已读取 ${alarms.length} 个闹钟'
              '${_labeledAlarms ? '（标签闹钟协议）' : '（标准闹钟协议）'}。';
        });
      });

  Future<void> _save() => run(() async {
        await widget.controller.setAlarms(
          _alarms,
          previousAlarmIds: _deviceAlarmIds,
        );
        if (!mounted) return;
        setState(() {
          _deviceAlarmIds = _alarms.map((alarm) => alarm.id).toSet();
          resultMessage = '闹钟表已整表下发。';
        });
      });

  JWAlarm _copyAlarm(
    JWAlarm alarm, {
    DateTime? time,
    int? repeatDays,
    bool? enabled,
    String? label,
  }) =>
      JWAlarm(
        id: alarm.id,
        time: time ?? alarm.time,
        repeatDays: repeatDays ?? alarm.repeatDays,
        enabled: enabled ?? alarm.enabled,
        label: label ?? alarm.label,
      );

  void _replaceAlarm(int index, JWAlarm alarm) {
    setState(() {
      _alarms = List<JWAlarm>.from(_alarms)..[index] = alarm;
    });
  }

  Future<void> _pickTime(int index) async {
    final alarm = _alarms[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(alarm.time),
    );
    if (picked == null || !mounted) return;
    final local = alarm.time.toLocal();
    final updated = DateTime(
      local.year,
      local.month,
      local.day,
      picked.hour,
      picked.minute,
    );
    _replaceAlarm(index, _copyAlarm(alarm, time: updated));
  }

  void _toggleDay(int index, int bit) {
    final alarm = _alarms[index];
    final mask = 1 << bit;
    _replaceAlarm(index, _copyAlarm(alarm, repeatDays: alarm.repeatDays ^ mask));
  }

  void _toggleEnabled(int index, bool enabled) {
    _replaceAlarm(index, _copyAlarm(_alarms[index], enabled: enabled));
  }

  void _removeAt(int index) {
    setState(() {
      _alarms = List<JWAlarm>.from(_alarms)..removeAt(index);
    });
  }

  void _addAlarm() {
    final used = _alarms.map((alarm) => alarm.id).toSet();
    final id = [for (var i = 0; i <= 7; i++) i].firstWhere(
      (value) => !used.contains(value),
      orElse: () => -1,
    );
    if (id < 0) {
      setState(() => error = StateError('最多 8 个闹钟槽位（id 0–7）'));
      return;
    }
    final now = DateTime.now();
    setState(() {
      _alarms = [
        ..._alarms,
        JWAlarm(
          id: id,
          time: DateTime(now.year, now.month, now.day, 7, 0),
          repeatDays: 0,
          enabled: true,
        ),
      ];
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return Scaffold(
      appBar: AppBar(
        title: _SettingsApiTitle(
          title: '闹钟',
          apiCode:
              'final alarms = await session.readAlarms();\nawait session.setAlarms(alarms);',
          compact: true,
        ),
        actions: [
          IconButton(
            tooltip: '从设备读取',
            onPressed: busy ? null : _read,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAlarm,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_alarm),
        label: const Text('添加闹钟'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text(
            '整表提交：修改后需点「保存闹钟表」才会下发到手表。重复日 bit 0–6 为周一至周日；'
            '未勾选 repeat 为单次闹钟。标签闹钟协议需打开「启用」才会响铃；'
            '重复闹钟下发时日期字段会使用当天日历（与 Android 一致）。',
          ),
          const SizedBox(height: 12),
          if (_alarms.isEmpty && !busy)
            const Text('当前无闹钟，可添加或先从设备读取。'),
          for (var index = 0; index < _alarms.length; index++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '槽位 ${_alarms[index].id} · '
                            '${TimeOfDay.fromDateTime(_alarms[index].time).format(context)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: '改时间',
                          onPressed: busy ? null : () => _pickTime(index),
                          icon: const Icon(Icons.schedule),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: busy ? null : () => _removeAt(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (_labeledAlarms)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用'),
                        subtitle: !_alarms[index].enabled
                            ? const Text('关闭时手表不会响铃')
                            : null,
                        value: _alarms[index].enabled,
                        onChanged: busy
                            ? null
                            : (value) => _toggleEnabled(index, value),
                      ),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (var bit = 0; bit < 7; bit++)
                          FilterChip(
                            label: Text('周${dayLabels[bit]}'),
                            selected: (_alarms[index].repeatDays & (1 << bit)) != 0,
                            onSelected: busy
                                ? null
                                : (_) => _toggleDay(index, bit),
                          ),
                      ],
                    ),
                    if (_labeledAlarms && _alarms[index].label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('标签：${_alarms[index].label}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: busy || _alarms.isEmpty ? null : _save,
            child: const Text('保存闹钟表'),
          ),
          ...buildAsyncFeedback(context),
        ],
      ),
    );
  }
}

class JWProfileGoalsPage extends StatefulWidget {
  const JWProfileGoalsPage({super.key, required this.controller});
  final JWDemoController controller;

  @override
  State<JWProfileGoalsPage> createState() => _JWProfileGoalsPageState();
}

class _JWProfileGoalsPageState extends State<JWProfileGoalsPage>
    with _DemoAsyncMixin {
  final _age = TextEditingController(text: '30');
  final _height = TextEditingController(text: '170');
  final _weight = TextEditingController(text: '65');
  final _steps = TextEditingController(text: '8000');
  final _sleep = TextEditingController(text: '480');
  final _calories = TextEditingController(text: '400');
  bool _isMale = true;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _steps.dispose();
    _sleep.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final age = int.tryParse(_age.text);
    final height = double.tryParse(_height.text);
    final weight = double.tryParse(_weight.text);
    final steps = int.tryParse(_steps.text);
    final sleep = int.tryParse(_sleep.text);
    final calories = int.tryParse(_calories.text);
    if (age == null ||
        height == null ||
        weight == null ||
        steps == null ||
        sleep == null ||
        calories == null) {
      setState(() => error = const FormatException('请填写有效数字'));
      return;
    }
    await run(() async {
      await widget.controller.setUserProfile(JWUserProfile(
        isMale: _isMale,
        age: age,
        heightCentimeters: height,
        weightKilograms: weight,
      ));
      await widget.controller.setGoals(
        JWGoals(steps: steps, sleepMinutes: sleep, calories: calories),
      );
      if (mounted) {
        setState(() => resultMessage = '用户资料与目标已下发。');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _SettingsApiTitle(
            title: '用户资料与目标',
            apiCode: 'await session.setUserProfile(profile);\nawait session.setGoals(goals);',
            compact: true,
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          children: [
            const Text('填写后可直接设置用户资料与每日目标。'),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('男性'),
              value: _isMale,
              onChanged: busy ? null : (value) => setState(() => _isMale = value),
            ),
            _numberField(_age, '年龄'),
            _numberField(_height, '身高（cm）', decimal: true),
            _numberField(_weight, '体重（kg）', decimal: true),
            _numberField(_steps, '步数目标'),
            _numberField(_sleep, '睡眠目标（分钟）'),
            _numberField(_calories, '卡路里目标'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? '正在提交…' : '提交'),
            ),
            ...buildAsyncFeedback(context),
          ],
        ),
      );

  Widget _numberField(TextEditingController controller, String label,
          {bool decimal = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          enabled: !busy,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.title,
    required this.subtitle,
    required this.apiCode,
    required this.onOpen,
    this.keyName,
  });

  final String title;
  final String subtitle;
  final String apiCode;
  final VoidCallback onOpen;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: keyName != null ? Key(keyName!) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsApiTitle(title: title, apiCode: apiCode),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsApiTitle extends StatelessWidget {
  const _SettingsApiTitle({
    required this.title,
    required this.apiCode,
    this.compact = false,
  });

  final String title;
  final String apiCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = (compact ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
        ?.copyWith(color: colors.primary);
    return InkWell(
      onTap: () => unawaited(
        JwDemoContentSheet.showApiExample(
          context,
          stepTitle: title,
          code: apiCode,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$title · API', style: style),
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

String _timeRangeLabel(JWTimeRange range) =>
    '${range.startHour.toString().padLeft(2, '0')}:${range.startMinute.toString().padLeft(2, '0')}'
    '–${range.endHour.toString().padLeft(2, '0')}:${range.endMinute.toString().padLeft(2, '0')}';

String _languageName(JWLanguage value) => switch (value) {
      JWLanguage.english => 'English',
      JWLanguage.simplifiedChinese => '简体中文',
      JWLanguage.traditionalChinese => '繁體中文',
      JWLanguage.polish => 'Polski',
      JWLanguage.german => 'Deutsch',
      JWLanguage.russian => 'Русский',
      JWLanguage.french => 'Français',
      JWLanguage.korean => '한국어',
      JWLanguage.mongolian => 'Монгол',
      JWLanguage.portuguese => 'Português',
      JWLanguage.japanese => '日本語',
      JWLanguage.swedish => 'Svenska',
      JWLanguage.thai => 'ไทย',
      JWLanguage.turkish => 'Türkçe',
      JWLanguage.spanish => 'Español',
      JWLanguage.italian => 'Italiano',
      JWLanguage.vietnamese => 'Tiếng Việt',
    };
