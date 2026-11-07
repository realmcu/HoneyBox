/// Wire / App 单位换算（对齐 HL §5.2 与 Android `StepEntity` 展示）。
///
/// 计步历史：distance = 米，energy/calorie = 卡（cal）；App 展示为 km / kcal。
double jwDataMetersToKm(num meters) => meters / 1000.0;

double jwDataCalToKcal(num cal) => cal / 1000.0;

String jwDataFormatKm(num meters, {int digits = 2}) =>
    jwDataMetersToKm(meters).toStringAsFixed(digits);

String jwDataFormatKcal(num cal, {int digits = 0}) {
  final kcal = jwDataCalToKcal(cal);
  if (digits <= 0) return kcal.round().toString();
  return kcal.toStringAsFixed(digits);
}

String jwDataFormatMmol(int valueTenths) =>
    (valueTenths / 10).toStringAsFixed(1);

String jwDataFormatDuration(int seconds) {
  if (seconds < 60) return '$seconds 秒';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m < 60) return s == 0 ? '$m 分钟' : '$m 分 $s 秒';
  final h = m ~/ 60;
  final rm = m % 60;
  return rm == 0 ? '$h 小时' : '$h 小时 $rm 分';
}

String jwDataSleepModeLabel(int mode) => switch (mode) {
      1 => '浅睡',
      2 => '深睡',
      3 => '清醒/退出',
      0 => '未知',
      4 => '快速眼动',
      _ => '模式 $mode',
    };

/// HL §5.16 运动模式（与协议表一致的常用子集）。
String jwDataSportModeLabel(int mode) => switch (mode) {
      0x01 => '户外徒步',
      0x02 => '跑步',
      0x03 => '骑行',
      0x04 => '爬山',
      0x05 => '羽毛球',
      0x06 => '篮球',
      0x07 => '足球',
      0x08 => '游泳',
      0x09 => '自由训练',
      0x0A => '椭圆机',
      0x0B => '瑜伽',
      0x0C => '乒乓球',
      0x0D => '跳绳',
      0x0E => '划船机',
      _ => '运动 $mode',
    };
