import 'package:flutter/material.dart';
import '../../../services/jw/history/jw_history_models.dart';
import 'jw_health_charts.dart';

// History key0x16 V2 byte8 is the raw UK mode, not unified WSSportType.
// cavo_band_protocol/HL_Private_Protocol.md:2234-2261;
// RTL8762D/sdk-4.0.0/src/app/wristband/sensor_hub/hub_exercise.h:33-60.
const _historySportNames = [
  '跑步',
  '登山',
  '足球',
  '骑行',
  '跳绳',
  '户外跑步',
  '户外骑车',
  '户外徒步',
  '室内跑步',
  '自由训练',
  '平板支撑',
  '健走',
  '呼吸训练',
  '瑜伽',
  '徒步',
  '动感单车',
  '划船机',
  '踏步机',
  '椭圆机',
  '篮球',
  '网球',
  '羽毛球',
  '棒球',
  '橄榄球',
  '乒乓球',
  '滑雪',
  '板球',
  '力量训练'
];

String jwHealthSportTitle(JwHistoryRecord record) {
  final mode = record.values['mode'];
  final name = mode is int && mode >= 0 && mode < _historySportNames.length
      ? _historySportNames[mode]
      : '模式 ${mode ?? '未知'}';
  return '运动记录 · $name';
}

num? _sportValue(JwHistoryRecord record, String key) {
  final value = record.values[key];
  return value is num && value.isFinite && value >= 0 ? value : null;
}

String _sportDuration(JwHistoryRecord record) {
  final minutes = _sportValue(record, 'durationMinutes');
  final seconds = _sportValue(record, 'durationSeconds');
  if (minutes == null && seconds == null) return '暂无时长';
  if (minutes == null) return '${healthNumber(seconds)}秒';
  return '${healthDuration(minutes)}${seconds == null || seconds == 0 ? '' : '${healthNumber(seconds)}秒'}';
}

String jwHealthSportOverview(JwHistoryRecord record) {
  final energy = _sportValue(record, 'energyCalories');
  final distance = _sportValue(record, 'distanceMeters');
  return '${record.day} · ${_sportDuration(record)} · ${energy == null ? '暂无能量' : '${healthNumber(energy / 1000)} kcal'}${distance == null ? '' : ' · ${healthNumber(distance / 1000)} km'}';
}

class JwHealthSportPage extends StatelessWidget {
  const JwHealthSportPage({super.key, required this.record});
  final JwHistoryRecord record;
  @override
  Widget build(BuildContext context) {
    final v = record.values;
    String number(String key, String unit, {double factor = 1}) {
      final value = v[key];
      return value is num && value.isFinite && value >= 0
          ? '${healthNumber(value * factor)} $unit'
          : '暂无数据';
    }

    final minute = record.sourceTime['minute'];
    final timestamp = minute is int
        ? '${record.day} ${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}'
        : record.day;
    return Scaffold(
        backgroundColor: const Color(0xfff9f9f9),
        appBar: AppBar(title: const Text('运动详情')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(jwHealthSportTitle(record),
              style: Theme.of(context).textTheme.headlineSmall),
          Text('$timestamp · 设备本地时间'),
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(spacing: 28, runSpacing: 20, children: [
                    _Value(
                        '时长',
                        _sportDuration(record) == '暂无时长'
                            ? '暂无数据'
                            : _sportDuration(record)),
                    _Value('步数', number('steps', '步')),
                    _Value('距离', number('distanceMeters', 'km', factor: .001)),
                    _Value(
                        '能量', number('energyCalories', 'kcal', factor: .001)),
                    if (v['heartRateAverage'] != null)
                      _Value('平均心率', number('heartRateAverage', 'bpm')),
                    if (v['heartRateMax'] != null)
                      _Value('最高心率', number('heartRateMax', 'bpm')),
                    if (v['heartRateMin'] != null)
                      _Value('最低心率', number('heartRateMin', 'bpm')),
                    if (v['pauseMinutes'] != null)
                      _Value('暂停时长',
                          '${number('pauseMinutes', 'min')} ${number('pauseSeconds', 's')}'),
                  ]))),
          const SizedBox(height: 16),
          const Text('来源：设备已保存运动记录'),
          const Text('记录未提供连续心率或配速样本，不显示曲线。'),
        ]));
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 150,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleLarge)
      ]));
}
