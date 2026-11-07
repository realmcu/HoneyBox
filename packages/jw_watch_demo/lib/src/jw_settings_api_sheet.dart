import 'dart:async';

import 'package:flutter/material.dart';

import 'jw_demo_content_sheet.dart';
import 'jw_settings_app_theme.dart';

/// 点击标题弹出公开 API 示例；外观与普通标题一致（不变色、无 API 字样）。
class JwSettingsApiTitle extends StatelessWidget {
  const JwSettingsApiTitle({
    super.key,
    required this.title,
    required this.apiCode,
    this.style,
  });

  final String title;
  final String apiCode;
  final TextStyle? style;

  static Future<void> show(BuildContext context,
      {required String title, required String apiCode}) {
    return JwDemoContentSheet.showApiExample(
      context,
      stepTitle: title,
      code: apiCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? JwSettingsAppTheme.itemTitle;
    // Material+InkWell：AppBar title / ListTile 内也能稳定点到。
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => unawaited(show(context, title: title, apiCode: apiCode)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(title, style: textStyle),
        ),
      ),
    );
  }
}

/// 设置主页 / 二级页已实现项的公开 API 示例文案。
abstract final class JwSettingsApiExamples {
  static const alarm = '''
final alarms = await session.readAlarms();
await session.setAlarms(alarms); // replaces full table
''';

  static const doNotDisturb = '''
final dnd = await session.readDoNotDisturb();
await session.setDoNotDisturbVerified(dnd);
''';

  static const eventRemind = '''
final sit = await session.readSedentaryReminder();
await session.setSedentaryReminderVerified(sit);

final dnd = await session.readDoNotDisturb();
await session.setDoNotDisturbVerified(dnd);
''';

  static const language = '''
final language = await session.readLanguage();
await session.setLanguageVerified(JWLanguage.simplifiedChinese);
''';

  static const unitSystem = '''
final unit = await session.readUnitSystem();
await session.setUnitSystemVerified(JWUnitSystem.metric);
''';

  static const hourSystem = '''
final hour = await session.readHourSystem();
await session.setHourSystemVerified(JWHourSystem.h24);
''';

  static const temperatureUnit = '''
final cfg = await session.measure.readTemperatureControl();
await session.measure.setTemperatureControl(
  JWTemperatureControlSetting(
    enabled: cfg.enabled,
    adjust: cfg.adjust,
    celsius: true, // false = °F
  ),
);
''';

  static const screenDisplay = '''
await session.setScreenLightDuration(10); // 自动熄屏（秒）
await session.setScreenBrightness(80);
await session.setTurnWristToWake(true); // 转腕亮屏
''';

  static const autoScreenOff = '''
await session.setScreenLightDuration(10); // 秒
''';

  static const screenBrightness = '''
await session.setScreenBrightness(80); // 0–100
''';

  static const turnWrist = '''
await session.setTurnWristToWake(true);
''';

  static const dateFormat = '''
await session.setDateFormat(JWDateFormat.monthDay); // MM-DD
await session.setDateFormat(JWDateFormat.dayMonth); // DD-MM
''';

  static const syncTime = '''
await session.setTime(DateTime.now());
// 协议不支持读回确认
''';

  static const findDevice = '''
await session.findDevice(true);  // 开始查找
await session.findDevice(false); // 停止查找
''';

  static const notifyRemind = '''
final settings = await session.readNotifySettings();
await session.setNotifyChannelVerified(JWNotifyChannel.wechat, true);
await session.setNotifySettingsVerified(JWNotifySettings.all(false));

await session.sendNotifyMessage(JWNotifyChannel.wechat, text: '你好');
await session.sendIncomingCall(display: '10086');
''';

  static const userProfileGoals = '''
await session.setUserProfile(profile);
await session.setGoals(
  const JWGoals(steps: 8000, sleepMinutes: 480, calories: 400),
);
''';

  static const disconnect = '''
await session.dispose();
''';

  static const clearDeviceData = '''
await session.clearDeviceData(confirmed: true);
// Device typically reboots; dispose the local session afterwards.
await session.dispose();
''';

  static const heartRateAuto = '''
final cfg = await session.measure.readHeartRateAutoMeasure();
await session.measure.setHeartRateAutoMeasure(
  JWAutoMeasureConfig(enabled: true, intervalMinutes: 10),
);
''';

  static const highHeartRate = '''
final cfg = await session.readHighHeartRateReminder();
await session.setHighHeartRateReminderVerified(
  JWHighHeartRateReminder(enabled: true, thresholdBpm: 180),
);
''';

  static const spo2Auto = '''
final cfg = await session.measure.readSpO2AutoMeasure();
await session.measure.setSpO2AutoMeasure(
  JWAutoMeasureConfig(enabled: true, intervalMinutes: 1),
);
''';

  static const bloodPressureAuto = '''
final cfg = await session.measure.readBloodPressureAutoMeasure();
await session.measure.setBloodPressureAutoMeasure(
  JWAutoMeasureConfig(enabled: true, intervalMinutes: 10),
);
''';

  static const bloodSugarAuto = '''
final cfg = await session.measure.readBloodSugarAutoMeasure();
await session.measure.setBloodSugarAutoMeasure(
  JWBloodSugarAutoMeasureConfig(enabled: true, intervalMinutes: 10),
);
''';

  static const temperatureAuto = '''
final cfg = await session.measure.readTemperatureControl();
await session.measure.setTemperatureControl(
  JWTemperatureControlSetting(
    enabled: true,
    adjust: cfg.adjust,
    celsius: cfg.celsius,
  ),
);
''';

  static const pressureAuto = '''
await session.measure.setPressureAutoMeasure(true);
''';

  static const heatStress = '''
final cfg = await session.readHeatStressReminder();
await session.setHeatStressReminderVerified(
  JWHeatStressReminder(
    enabled: true,
    schedule: const JWTimeRange(
      startHour: 8,
      startMinute: 0,
      endHour: 22,
      endMinute: 0,
    ),
  ),
);
''';

  static const sedentaryReminder = '''
final reminder = await session.readSedentaryReminder();
await session.setSedentaryReminderVerified(reminder);
''';
}
