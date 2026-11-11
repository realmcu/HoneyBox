import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_controller.dart';
import 'ws_settings_api_sheet.dart';
import 'ws_settings_app_widgets.dart';
import 'compat/ws_demo_compat.dart';
import 'ws_settings_app_theme.dart';

/// 设备语言二级页（读后写 + 读回）。
class WsLanguageSettingsPage extends StatefulWidget {
  const WsLanguageSettingsPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsLanguageSettingsPage> createState() => _JwLanguageSettingsPageState();
}

class _JwLanguageSettingsPageState extends State<WsLanguageSettingsPage> {
  WSLanguage? _language;
  bool _busy = false;
  Object? _error;
  String? _result;

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
        final language = await widget.controller.readLanguage();
        if (!mounted) return;
        setState(() {
          _language = language;
          _result = '已读取当前语言。';
        });
      });

  void _select(WSLanguage next) {
    _run(() async {
      await widget.controller.setLanguage(next);
      if (!mounted) return;
      setState(() {
        _language = next;
        _result = '语言已写入并读回验证。';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
      backgroundColor: WsSettingsAppTheme.background,
      appBar: AppBar(
        title: const WsSettingsApiTitle(
          title: '设备语言',
          apiCode: WsSettingsApiExamples.language,
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _read,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WsSettingsCard(
            children: [
              for (var i = 0; i < WSLanguage.values.length; i++)
                _ChoiceRow(
                  key: Key(
                      'jw.demo.settings.language.${WSLanguage.values[i].name}'),
                  title: _languageName(WSLanguage.values[i]),
                  selected: _language == WSLanguage.values[i],
                  enabled: !_busy,
                  showDivider: i != WSLanguage.values.length - 1,
                  onTap: () => _select(WSLanguage.values[i]),
                ),
            ],
          ),
          ..._feedback(),
        ],
      ),
      ),
    );
  }

  List<Widget> _feedback() => [
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_result != null) ...[
          const SizedBox(height: 12),
          Text(_result!,
              style: const TextStyle(color: WsSettingsAppTheme.subtitle)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            describeWSDemoError(_error!),
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ];
}

/// 对齐 App `UnitSettingActivity`：公英制 + 温度单位 + 时制。
class WsUnitSettingsPage extends StatefulWidget {
  const WsUnitSettingsPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsUnitSettingsPage> createState() => _JwUnitSettingsPageState();
}

class _JwUnitSettingsPageState extends State<WsUnitSettingsPage> {
  WSUnitSystem? _unitSystem;
  WSHourSystem? _hourSystem;
  WSTemperatureControlSetting? _temperature;
  WSDateFormat _dateFormat = WSDateFormat.monthDay;
  bool _busy = false;
  Object? _error;
  String? _result;

  bool get _temperatureCapable =>
      widget.controller.functionInfo
          ?.supports(WSDeviceFunction.temperature) ??
      false;

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
        final unit = await widget.controller.readUnitSystem();
        final hour = await widget.controller.readHourSystem();
        final dateFormat = await widget.controller.readDateFormat();
        WSTemperatureControlSetting? temperature;
        if (_temperatureCapable) {
          temperature = await widget.controller.readTemperatureControl();
        }
        if (!mounted) return;
        setState(() {
          _unitSystem = unit;
          _hourSystem = hour;
          _dateFormat = dateFormat;
          _temperature = temperature;
          _result = '已读取单位设置。';
        });
      });

  void _selectUnit(WSUnitSystem next) {
    _run(() async {
      await widget.controller.setUnitSystem(next);
      if (!mounted) return;
      setState(() {
        _unitSystem = next;
        _result = '公英制已写入并读回验证。';
      });
    });
  }

  void _selectHour(WSHourSystem next) {
    _run(() async {
      await widget.controller.setHourSystem(next);
      if (!mounted) return;
      setState(() {
        _hourSystem = next;
        _result = '时制已写入并读回验证。';
      });
    });
  }

  void _selectCelsius(bool celsius) {
    final current = _temperature;
    if (current == null) return;
    _run(() async {
      final next = WSTemperatureControlSetting(
        enabled: current.enabled,
        adjust: current.adjust,
        celsius: celsius,
      );
      await widget.controller.setTemperatureControl(next);
      final actual = await widget.controller.readTemperatureControl();
      if (!mounted) return;
      setState(() {
        _temperature = actual;
        _result = '温度单位已写入并读回验证。';
      });
    });
  }

  void _selectDateFormat(WSDateFormat next) {
    _run(() async {
      await widget.controller.setDateFormat(next);
      if (!mounted) return;
      setState(() {
        _dateFormat = next;
        _result = '表盘日期格式已下发。';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
      backgroundColor: WsSettingsAppTheme.background,
      appBar: AppBar(
        title: const Text('单位设置'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _read,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WsSettingsSectionHeader(
            '公英制',
            apiCode: WsSettingsApiExamples.unitSystem,
          ),
          WsSettingsCard(
            children: [
              _ChoiceRow(
                key: const Key('jw.demo.settings.unit_system.metric'),
                title: '公制',
                selected: _unitSystem == WSUnitSystem.metric,
                enabled: !_busy,
                showDivider: true,
                onTap: () => _selectUnit(WSUnitSystem.metric),
              ),
              _ChoiceRow(
                key: const Key('jw.demo.settings.unit_system.imperial'),
                title: '英制',
                selected: _unitSystem == WSUnitSystem.imperial,
                enabled: !_busy,
                showDivider: false,
                onTap: () => _selectUnit(WSUnitSystem.imperial),
              ),
            ],
          ),
          const WsSettingsSectionHeader(
            '温度单位',
            apiCode: WsSettingsApiExamples.temperatureUnit,
          ),
          WsSettingsCard(
            children: [
              if (!_temperatureCapable)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '当前设备不支持温度单位设置。',
                    style: TextStyle(
                      fontSize: 14,
                      color: WsSettingsAppTheme.subtitle,
                    ),
                  ),
                )
              else ...[
                _ChoiceRow(
                  key: const Key('jw.demo.settings.temp_unit.celsius'),
                  title: '摄氏度(°C)',
                  selected: _temperature?.celsius == true,
                  enabled: !_busy && _temperature != null,
                  showDivider: true,
                  onTap: () => _selectCelsius(true),
                ),
                _ChoiceRow(
                  key: const Key('jw.demo.settings.temp_unit.fahrenheit'),
                  title: '华氏度(°F)',
                  selected: _temperature?.celsius == false,
                  enabled: !_busy && _temperature != null,
                  showDivider: false,
                  onTap: () => _selectCelsius(false),
                ),
              ],
            ],
          ),
          const WsSettingsSectionHeader(
            '时制',
            apiCode: WsSettingsApiExamples.hourSystem,
          ),
          WsSettingsCard(
            children: [
              _ChoiceRow(
                key: const Key('jw.demo.settings.hour_system.h24'),
                title: '24 小时制',
                selected: _hourSystem == WSHourSystem.h24,
                enabled: !_busy,
                showDivider: true,
                onTap: () => _selectHour(WSHourSystem.h24),
              ),
              _ChoiceRow(
                key: const Key('jw.demo.settings.hour_system.h12'),
                title: '12 小时制',
                selected: _hourSystem == WSHourSystem.h12,
                enabled: !_busy,
                showDivider: false,
                onTap: () => _selectHour(WSHourSystem.h12),
              ),
            ],
          ),
          const WsSettingsSectionHeader(
            '表盘日期格式',
            apiCode: WsSettingsApiExamples.dateFormat,
          ),
          WsSettingsCard(
            children: [
              _ChoiceRow(
                key: const Key('jw.demo.settings.date_format.month_day'),
                title: 'MM-DD',
                selected: _dateFormat == WSDateFormat.monthDay,
                enabled: !_busy,
                showDivider: true,
                onTap: () => _selectDateFormat(WSDateFormat.monthDay),
              ),
              _ChoiceRow(
                key: const Key('jw.demo.settings.date_format.day_month'),
                title: 'DD-MM',
                selected: _dateFormat == WSDateFormat.dayMonth,
                enabled: !_busy,
                showDivider: false,
                onTap: () => _selectDateFormat(WSDateFormat.dayMonth),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(_result!,
                style: const TextStyle(color: WsSettingsAppTheme.subtitle)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              describeWSDemoError(_error!),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// 对齐 App `activity_screen_display.xml` 信息架构与排版。
class WsScreenDisplayPage extends StatefulWidget {
  const WsScreenDisplayPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsScreenDisplayPage> createState() => _JwScreenDisplayPageState();
}

class _JwScreenDisplayPageState extends State<WsScreenDisplayPage> {
  int _autoOffSeconds = 10;
  int _brightness = 60;
  bool _turnWrist = false;
  bool _busy = false;
  Object? _error;
  String? _result;

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

  Future<void> _pickAutoOff() async {
    final next = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: WsSettingsAppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('自动熄屏', style: WsSettingsAppTheme.reminderTitle),
              ),
            ),
            for (final seconds in const [3, 5, 10, 15, 20, 30])
              ListTile(
                title: Text('$seconds 秒'),
                trailing: seconds == _autoOffSeconds
                    ? const Icon(Icons.check, color: WsSettingsAppTheme.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, seconds),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (next == null || next == _autoOffSeconds) return;
    _run(() async {
      await widget.controller.setScreenLightDuration(next);
      if (!mounted) return;
      setState(() {
        _autoOffSeconds = next;
        _result = '自动熄屏已下发。';
      });
    });
  }

  void _setBrightness(int value) {
    _run(() async {
      await widget.controller.setScreenBrightness(value);
      if (!mounted) return;
      setState(() {
        _brightness = value;
        _result = '亮度已下发。';
      });
    });
  }

  void _setTurnWrist(bool value) {
    _run(() async {
      await widget.controller.setTurnWristToWake(value);
      if (!mounted) return;
      setState(() {
        _turnWrist = value;
        _result = '转腕亮屏已下发。';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // App ScreenDisplay 页背景是 bg_color_default #F6F6F6。
    const pageBg = Color(0xFFF6F6F6);
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: WsSettingsAppTheme.toolbar,
          title: const WsSettingsApiTitle(
            title: '屏幕与显示',
            apiCode: WsSettingsApiExamples.screenDisplay,
            style: TextStyle(
              color: WsSettingsAppTheme.title,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const _ScreenSectionTitle('屏幕'),
            _ScreenNavRow(
              keyName: 'jw.demo.settings.auto_screen_off',
              iconAsset: WsSettingsIcons.autoScreenOff,
              title: '自动熄屏',
              apiCode: WsSettingsApiExamples.autoScreenOff,
              value: '$_autoOffSeconds 秒',
              marginTop: 12,
              onTap: _busy ? null : _pickAutoOff,
            ),
            // 自动锁屏：App 按能力位展示；ws_watch_sdk 暂无公开读写 API，JW Demo 不展示。
            const _ScreenSectionTitle('手势唤醒'),
            _ScreenSwitchRow(
              keyName: 'jw.demo.settings.turn_wrist',
              iconAsset: WsSettingsIcons.turnWrist,
              title: '转腕亮屏',
              apiCode: WsSettingsApiExamples.turnWrist,
              value: _turnWrist,
              marginTop: 12,
              enabled: !_busy,
              onChanged: _busy ? null : _setTurnWrist,
            ),
            const SizedBox(height: 12),
            Material(
              color: WsSettingsAppTheme.card,
              borderRadius:
                  BorderRadius.circular(WsSettingsAppTheme.itemRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WsSettingsApiTitle(
                      title: '亮度调节',
                      apiCode: WsSettingsApiExamples.screenBrightness,
                      style: WsSettingsAppTheme.reminderTitle,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 61,
                      child: Row(
                        children: [
                          WsSettingsIcons.image(
                            WsSettingsIcons.brightnessDark,
                            width: 22,
                            height: 22,
                            fallback: Icons.brightness_low,
                          ),
                          Expanded(
                            child: Slider(
                              value: _brightness.toDouble().clamp(20, 100),
                              min: 20,
                              max: 100,
                              divisions: 4,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                        () => _brightness = v.round(),
                                      ),
                              onChangeEnd: _busy
                                  ? null
                                  : (v) => _setBrightness(v.round()),
                            ),
                          ),
                          WsSettingsIcons.image(
                            WsSettingsIcons.brightnessLight,
                            width: 22,
                            height: 22,
                            fallback: Icons.brightness_high,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 15),
              child: Text(
                '提高屏幕亮度和转腕灵敏度、亮屏时间加长都会增加电量消耗，导致设备使用时间变短。建议使用默认设置。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: WsSettingsAppTheme.section,
                ),
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
                style: const TextStyle(color: WsSettingsAppTheme.subtitle),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                describeWSDemoError(_error!),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScreenSectionTitle extends StatelessWidget {
  const _ScreenSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(title, style: WsSettingsAppTheme.sectionTitle),
    );
  }
}

class _ScreenNavRow extends StatelessWidget {
  const _ScreenNavRow({
    required this.keyName,
    required this.iconAsset,
    required this.title,
    required this.value,
    required this.marginTop,
    this.apiCode,
    this.onTap,
  });

  final String keyName;
  final String iconAsset;
  final String title;
  final String value;
  final double marginTop;
  final String? apiCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: marginTop),
      child: Material(
        key: Key(keyName),
        color: WsSettingsAppTheme.card,
        borderRadius: BorderRadius.circular(WsSettingsAppTheme.itemRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  WsSettingsIcons.image(
                    iconAsset,
                    width: 21,
                    height: 21,
                    fallback: Icons.timer_outlined,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: apiCode == null
                        ? Text(title, style: WsSettingsAppTheme.reminderTitle)
                        : WsSettingsApiTitle(
                            title: title,
                            apiCode: apiCode!,
                            style: WsSettingsAppTheme.reminderTitle,
                          ),
                  ),
                  Text(value, style: WsSettingsAppTheme.itemValue),
                  const SizedBox(width: 6),
                  WsSettingsIcons.image(
                    WsSettingsIcons.chevronGray,
                    width: 8,
                    height: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenSwitchRow extends StatelessWidget {
  const _ScreenSwitchRow({
    required this.keyName,
    required this.iconAsset,
    required this.title,
    required this.value,
    required this.marginTop,
    required this.enabled,
    this.apiCode,
    this.tag,
    this.onChanged,
  });

  final String keyName;
  final String iconAsset;
  final String title;
  final bool value;
  final double marginTop;
  final bool enabled;
  final String? apiCode;
  final Widget? tag;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: marginTop),
      child: Material(
        key: Key(keyName),
        color: WsSettingsAppTheme.card,
        borderRadius: BorderRadius.circular(WsSettingsAppTheme.itemRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                WsSettingsIcons.image(
                  iconAsset,
                  width: 22,
                  height: 19,
                  fallback: Icons.screen_rotation_alt_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: apiCode == null
                            ? Text(
                                title,
                                style: WsSettingsAppTheme.reminderTitle,
                              )
                            : WsSettingsApiTitle(
                                title: title,
                                apiCode: apiCode!,
                                style: WsSettingsAppTheme.reminderTitle,
                              ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        tag!,
                      ],
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.enabled,
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          enabled: enabled,
          title: Text(title),
          trailing: selected
              ? const Icon(Icons.check, color: WsSettingsAppTheme.accent)
              : null,
          onTap: enabled ? onTap : null,
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            color: WsSettingsAppTheme.divider,
          ),
      ],
    );
  }
}

String _languageName(WSLanguage value) => switch (value) {
      WSLanguage.english => 'English',
      WSLanguage.simplifiedChinese => '简体中文',
      WSLanguage.traditionalChinese => '繁體中文',
      WSLanguage.polish => 'Polski',
      WSLanguage.german => 'Deutsch',
      WSLanguage.russian => 'Русский',
      WSLanguage.french => 'Français',
      WSLanguage.korean => '한국어',
      WSLanguage.mongolian => 'Монгол',
      WSLanguage.portuguese => 'Português',
      WSLanguage.japanese => '日本語',
      WSLanguage.swedish => 'Svenska',
      WSLanguage.thai => 'ไทย',
      WSLanguage.turkish => 'Türkçe',
      WSLanguage.spanish => 'Español',
      WSLanguage.italian => 'Italiano',
      WSLanguage.vietnamese => 'Tiếng Việt',
    };
