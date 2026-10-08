import 'package:flutter/material.dart';
import '../../../services/jw/health/jw_health_models.dart';
import 'jw_health_charts.dart';

/// Device statistics stay separate from timestamped raw sample averages.
class JwHealthSummaryCard extends StatelessWidget {
  const JwHealthSummaryCard({super.key, required this.summaries, this.metric});
  final List<JwHealthDailySummary> summaries;
  // Null selects sleep summary fields. There is no blood pressure summary.
  final JwHealthMetric? metric;

  List<String> _lines(Map<String, num> v) {
    final lines = <String>[];
    void value(String key, String label, String unit) {
      if (v[key] != null) lines.add('$label ${healthNumber(v[key])} $unit');
    }

    switch (metric) {
      case JwHealthMetric.heartRate:
        value('dayHeartRateAverageBpm', '日间心率平均', 'bpm');
        value('restHeartRateBpm', '静息心率', 'bpm');
        value('nightHeartRateP10', '夜间心率 P10', 'bpm');
      case JwHealthMetric.bloodOxygen:
        value('spo2MeanPercent', '血氧平均', '%');
        value('spo2MinPercent', '血氧最低', '%');
        value('spo2Lt90Count', '低于 90% 次数', '次');
      case JwHealthMetric.hrv:
        value('sdnnMedianMs', 'SDNN 中位数', 'ms');
        if (v['sdnnP25Ms'] != null || v['sdnnP75Ms'] != null) {
          lines.add(
              'P25 ${healthNumber(v['sdnnP25Ms'])} ms · P75 ${healthNumber(v['sdnnP75Ms'])} ms');
        }
        value('sdnnCount', 'SDNN 数量', '个');
      case JwHealthMetric.skinTemperature:
        value('skinTemperatureMeanCelsius', '皮温平均', '°C');
        value('skinTemperatureRangeCelsius', '皮温范围', '°C');
      case JwHealthMetric.pressure:
        value('stressAverage', '压力平均', '固件值');
      case JwHealthMetric.bloodPressure:
        break;
      case null:
        if (v['sleepMinutes'] != null) {
          lines.add('睡眠时长 ${healthDuration(v['sleepMinutes'])}');
        }
        if (v['deepSleepMinutes'] != null) {
          lines.add('深睡时长 ${healthDuration(v['deepSleepMinutes'])}');
        }
        final onset = v['sleepOnsetMinute'];
        if (onset != null) {
          // A reported onset is not a basis for inferring a wake time or stages.
          lines.add(
              '报告入睡时间 ${(onset ~/ 60).toString().padLeft(2, '0')}:${(onset.toInt() % 60).toString().padLeft(2, '0')}');
        }
    }
    return lines;
  }

  bool get hasValues => summaries.any((s) => _lines(s.values).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final visible = summaries.where((s) => _lines(s.values).isNotEmpty);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      const Text('设备每日摘要', style: TextStyle(fontWeight: FontWeight.w600)),
      for (final summary in visible) ...[
        Text(jwHealthDayKey(summary.date),
            style: const TextStyle(fontSize: 12)),
        for (final line in _lines(summary.values)) Text(line),
        if (summary.issues.isNotEmpty) const Text('此摘要带有质量标记，请结合原始记录查看'),
      ],
    ]);
  }
}
