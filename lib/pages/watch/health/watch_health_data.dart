enum WatchHealthPeriod { day, week, month }

class WatchHealthTrend {
  final String label;
  final String summary;
  final List<String> labels;
  final List<int> steps;
  final List<int> heartRates;

  const WatchHealthTrend({
    required this.label,
    required this.summary,
    required this.labels,
    required this.steps,
    required this.heartRates,
  });

  int get averageHeartRate =>
      (heartRates.reduce((sum, value) => sum + value) / heartRates.length)
          .round();
}

class WatchSleepStage {
  final String name;
  final int minutes;

  const WatchSleepStage(this.name, this.minutes);
}

class WatchHealthRecord {
  final WatchHealthRecordType type;
  final String title;
  final String subtitle;
  final String value;

  const WatchHealthRecord({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.value,
  });
}

enum WatchHealthRecordType { heartRate, activity, milestone }

class WatchHealthSnapshot {
  final int batteryPercent;
  final DateTime syncedAt;
  final int steps;
  final int stepGoal;
  final int heartRate;
  final int minimumHeartRate;
  final int maximumHeartRate;
  final int sleepMinutes;
  final int activeMinutes;
  final int vigorousMinutes;
  final String sleepRange;
  final List<WatchSleepStage> sleepStages;
  final Map<WatchHealthPeriod, WatchHealthTrend> trends;
  final List<WatchHealthRecord> records;

  const WatchHealthSnapshot({
    required this.batteryPercent,
    required this.syncedAt,
    required this.steps,
    required this.stepGoal,
    required this.heartRate,
    required this.minimumHeartRate,
    required this.maximumHeartRate,
    required this.sleepMinutes,
    required this.activeMinutes,
    required this.vigorousMinutes,
    required this.sleepRange,
    required this.sleepStages,
    required this.trends,
    required this.records,
  });
}

abstract interface class WatchHealthRepository {
  Future<WatchHealthSnapshot> sync(String deviceId);
}

class MockWatchHealthRepository implements WatchHealthRepository {
  const MockWatchHealthRepository({
    this.delay = const Duration(milliseconds: 1400),
  });

  final Duration delay;

  @override
  Future<WatchHealthSnapshot> sync(String deviceId) async {
    await Future<void>.delayed(delay);
    return WatchHealthSamples.snapshot;
  }
}

class WatchHealthSamples {
  WatchHealthSamples._();

  static WatchHealthSnapshot get snapshot => WatchHealthSnapshot(
        batteryPercent: 78,
        syncedAt: DateTime.now(),
        steps: 8426,
        stepGoal: 10000,
        heartRate: 72,
        minimumHeartRate: 58,
        maximumHeartRate: 126,
        sleepMinutes: 438,
        activeMinutes: 48,
        vigorousMinutes: 23,
        sleepRange: '23:18 - 06:52',
        sleepStages: const [
          WatchSleepStage('深睡', 96),
          WatchSleepStage('浅睡', 211),
          WatchSleepStage('快速眼动', 101),
          WatchSleepStage('清醒', 30),
        ],
        trends: const {
          WatchHealthPeriod.day: WatchHealthTrend(
            label: '今天 · 分时趋势',
            summary: '今日累计 8,426 步',
            labels: ['0时', '4时', '8时', '12时', '16时', '20时'],
            steps: [2, 5, 48, 72, 56, 31],
            heartRates: [56, 54, 78, 72, 83, 68],
          ),
          WatchHealthPeriod.week: WatchHealthTrend(
            label: '7月21日 - 7月27日',
            summary: '本周日均 7,680 步',
            labels: ['一', '二', '三', '四', '五', '六', '日'],
            steps: [62, 79, 54, 88, 67, 93, 74],
            heartRates: [68, 72, 66, 75, 70, 82, 72],
          ),
          WatchHealthPeriod.month: WatchHealthTrend(
            label: '2026年7月',
            summary: '本月日均 7,324 步',
            labels: ['1日', '6日', '11日', '16日', '21日', '26日'],
            steps: [55, 71, 64, 82, 76, 68],
            heartRates: [69, 73, 68, 77, 71, 72],
          ),
        },
        records: const [
          WatchHealthRecord(
            type: WatchHealthRecordType.heartRate,
            title: '心率',
            subtitle: '10:18 · 静息状态',
            value: '72 次/分',
          ),
          WatchHealthRecord(
            type: WatchHealthRecordType.activity,
            title: '活跃时段',
            subtitle: '08:42-09:05 · 快走',
            value: '23 分钟',
          ),
          WatchHealthRecord(
            type: WatchHealthRecordType.milestone,
            title: '步数里程碑',
            subtitle: '08:56',
            value: '5,000 步',
          ),
        ],
      );
}
