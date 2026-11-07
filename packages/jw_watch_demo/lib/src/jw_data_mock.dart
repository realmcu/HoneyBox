import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_data_catalog.dart';
import 'jw_data_units.dart';

/// Demo 用模拟历史数据：形状对齐本地 DB 查询结果，便于预览 UI。
abstract final class JwDataMock {
  static const enabledByDefault = true;

  static List<Object> queryDay(JwDataTypeId id, DateTime day) {
    final start = jwDataDayStart(day);
    final dayOffset = jwDataDayStart(DateTime.now()).difference(start).inDays;
    final factor = switch (dayOffset) {
      0 => 1.0,
      1 => 0.75,
      _ => 0.45,
    };
    return switch (id) {
      JwDataTypeId.activity => _activity(start, factor),
      JwDataTypeId.sleep => _sleep(start),
      JwDataTypeId.heartRate => _heartRate(start, factor),
      JwDataTypeId.bloodPressure => _bloodPressure(start),
      JwDataTypeId.bloodOxygen => _bloodOxygen(start),
      JwDataTypeId.temperature => _temperature(start),
      JwDataTypeId.hrv => _hrv(start),
      JwDataTypeId.pressure => _pressure(start),
      JwDataTypeId.bloodSugar => _bloodSugar(start),
      JwDataTypeId.sport => _sport(start, factor),
    };
  }

  static String cardSummary(JwDataTypeId id, {DateTime? day}) {
    final target = jwDataDayStart(day ?? DateTime.now());
    final rows = queryDay(id, target);
    if (rows.isEmpty) return '暂无数据';

    if (id == JwDataTypeId.activity) {
      var steps = 0;
      for (final row in rows) {
        if (row is JWActivity) steps += row.steps;
      }
      return '${jwDataFormatDay(target)} $steps 步';
    }
    if (id == JwDataTypeId.sleep) {
      final sleep = jwDataSummarizeSleep(rows);
      if (sleep.totalMinutes > 0) {
        return '${jwDataFormatDay(target)} '
            '${jwDataFormatDuration(sleep.totalMinutes * 60)}';
      }
    }
    if (id == JwDataTypeId.sport) {
      var seconds = 0;
      for (final row in rows) {
        if (row is JWSport) seconds += row.duration;
      }
      return '${jwDataFormatDay(target)} '
          '${rows.length} 次 · ${jwDataFormatDuration(seconds)}';
    }

    final latest = rows.last;
    final summary = jwDataLatestSummary(latest);
    final time =
        latest is JWHistoryRecord ? jwDataFormatTime(latest.time) : null;
    return time == null
        ? '${jwDataFormatDay(target)} $summary'
        : '${jwDataFormatDay(target)} $time · $summary';
  }

  static List<Object> _activity(DateTime day, double factor) {
    final slots = <(int hour, int minute, int steps)>[
      (7, 0, 420),
      (7, 30, 680),
      (8, 0, 1250),
      (8, 30, 980),
      (9, 0, 340),
      (9, 30, 210),
      (10, 0, 180),
      (11, 30, 260),
      (12, 0, 520),
      (12, 30, 610),
      (13, 0, 290),
      (15, 0, 190),
      (16, 30, 320),
      (17, 30, 890),
      (18, 0, 1560),
      (18, 30, 1320),
      (19, 0, 740),
      (19, 30, 410),
      (20, 30, 180),
      (21, 0, 260),
    ];
    return [
      for (final s in slots)
        JWActivity(
          time: DateTime(day.year, day.month, day.day, s.$1, s.$2),
          steps: (s.$3 * factor).round(),
          distance: ((s.$3 * 0.7) * factor).round(),
          energy: ((s.$3 * 35) * factor).round(),
          activeTime: 15,
          mode: 0,
        ),
    ];
  }

  static List<Object> _sleep(DateTime day) {
    // 状态切换点：1浅 2深 3退出 4REM（画图映射到 App 档位）
    return [
      JWSleep(time: DateTime(day.year, day.month, day.day, 0, 10), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 0, 45), mode: 2),
      JWSleep(time: DateTime(day.year, day.month, day.day, 1, 40), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 2, 5), mode: 4),
      JWSleep(time: DateTime(day.year, day.month, day.day, 2, 35), mode: 2),
      JWSleep(time: DateTime(day.year, day.month, day.day, 3, 50), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 4, 20), mode: 3),
      JWSleep(time: DateTime(day.year, day.month, day.day, 4, 35), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 5, 10), mode: 2),
      JWSleep(time: DateTime(day.year, day.month, day.day, 6, 0), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 6, 40), mode: 4),
      JWSleep(time: DateTime(day.year, day.month, day.day, 7, 5), mode: 1),
      JWSleep(time: DateTime(day.year, day.month, day.day, 7, 30), mode: 3),
    ];
  }

  static List<Object> _heartRate(DateTime day, double factor) {
    final out = <JWHeartRate>[];
    for (var h = 0; h < 24; h++) {
      final base = switch (h) {
        >= 0 && < 6 => 58,
        >= 6 && < 9 => 72,
        >= 9 && < 12 => 78,
        >= 12 && < 14 => 85,
        >= 14 && < 18 => 80,
        >= 18 && < 21 => 90,
        _ => 65,
      };
      for (final m in [5, 20, 35, 50]) {
        if (h == 3 || h == 4) continue; // 留空档方便看缺口
        final wobble = ((h * 3 + m) % 11) - 5;
        out.add(
          JWHeartRate(
            time: DateTime(day.year, day.month, day.day, h, m),
            heartRate:
                ((base + wobble) * (0.92 + 0.08 * factor)).round().clamp(45, 180),
          ),
        );
      }
    }
    return out;
  }

  static List<Object> _bloodPressure(DateTime day) {
    final samples = <(int, int, int, int)>[
      (7, 20, 112, 72),
      (8, 5, 118, 76),
      (9, 40, 121, 78),
      (11, 10, 116, 74),
      (12, 40, 124, 80),
      (14, 15, 119, 77),
      (16, 30, 122, 79),
      (18, 50, 126, 82),
      (20, 15, 121, 78),
      (21, 45, 117, 75),
    ];
    return [
      for (final s in samples)
        JWBloodPressure(
          time: DateTime(day.year, day.month, day.day, s.$1, s.$2),
          systolic: s.$3,
          diastolic: s.$4,
        ),
    ];
  }

  static List<Object> _bloodOxygen(DateTime day) {
    final out = <JWBloodOxygen>[];
    for (final h in [7, 8, 9, 11, 12, 14, 16, 18, 20, 21, 22]) {
      for (final m in [0, 25]) {
        final v = 95 + ((h + m) % 4);
        out.add(
          JWBloodOxygen(
            time: DateTime(day.year, day.month, day.day, h, m),
            value: v,
            low: v - 1,
            high: (v + 2).clamp(0, 100),
          ),
        );
      }
    }
    return out;
  }

  static List<Object> _temperature(DateTime day) {
    final out = <JWTemperature>[];
    for (var h = 6; h <= 22; h++) {
      for (final m in [0, 30]) {
        final base = 36.3 + (h - 6) * 0.03;
        final bump = (h == 13 || h == 18) ? 0.4 : 0.0;
        out.add(
          JWTemperature(
            time: DateTime(day.year, day.month, day.day, h, m),
            skinTemperature: double.parse((base + bump).toStringAsFixed(1)),
            heatStress: bump > 0.3 ? 1 : 0,
            worn: true,
            compensated: true,
          ),
        );
      }
    }
    return out;
  }

  static List<Object> _hrv(DateTime day) {
    final out = <JWHrv>[];
    for (final h in [7, 8, 9, 10, 12, 14, 16, 18, 20, 21, 22]) {
      for (final m in [10, 40]) {
        out.add(
          JWHrv(
            time: DateTime(day.year, day.month, day.day, h, m),
            sdnn: 30 + ((h * 5 + m) % 40),
          ),
        );
      }
    }
    return out;
  }

  static List<Object> _pressure(DateTime day) {
    final out = <JWPressure>[];
    for (var h = 7; h <= 22; h++) {
      for (var m = 0; m < 60; m += 10) {
        if (h == 15) continue;
        final v = switch (h) {
          <= 9 => 22 + (m ~/ 10) * 2,
          <= 12 => 35 + (m ~/ 10),
          <= 18 => 48 + (h % 3) * 6,
          _ => 30 + (m ~/ 10) * 3,
        };
        out.add(
          JWPressure(
            time: DateTime(day.year, day.month, day.day, h, m),
            value: v.clamp(15, 95),
          ),
        );
      }
    }
    return out;
  }

  static List<Object> _bloodSugar(DateTime day) => [
        // value 单位 0.1 mmol/L
        for (final s in [
          (7, 10, 48),
          (7, 40, 52),
          (9, 20, 61),
          (11, 5, 55),
          (12, 10, 68),
          (13, 0, 72),
          (15, 30, 58),
          (17, 45, 63),
          (19, 0, 61),
          (20, 20, 57),
          (21, 50, 53),
        ])
          JWBloodGlucose(
            time: DateTime(day.year, day.month, day.day, s.$1, s.$2),
            value: s.$3,
          ),
      ];

  static List<Object> _sport(DateTime day, double factor) {
    final runMinutes = (32 * factor).round().clamp(12, 60);
    final walkMinutes = (18 * factor).round().clamp(8, 40);
    return [
      JWSport(
        time: DateTime(day.year, day.month, day.day, 7, 10),
        mode: 0x02,
        duration: runMinutes * 60,
        pauseCount: 1,
        pauseDuration: 60,
        steps: (4200 * factor).round(),
        distance: (3800 * factor).round(),
        energy: (280000 * factor).round(),
        heartRateMax: 162,
        heartRateAverage: 138,
        heartRateMin: 96,
      ),
      JWSport(
        time: DateTime(day.year, day.month, day.day, 12, 20),
        mode: 0x01,
        duration: 12 * 60,
        pauseCount: 0,
        pauseDuration: 0,
        steps: 980,
        distance: 720,
        energy: 45000,
        heartRateMax: 110,
        heartRateAverage: 95,
        heartRateMin: 80,
      ),
      JWSport(
        time: DateTime(day.year, day.month, day.day, 18, 40),
        mode: 0x01,
        duration: walkMinutes * 60,
        pauseCount: 0,
        pauseDuration: 0,
        steps: (2100 * factor).round(),
        distance: (1600 * factor).round(),
        energy: (110000 * factor).round(),
        heartRateMax: 118,
        heartRateAverage: 102,
        heartRateMin: 84,
      ),
    ];
  }
}
