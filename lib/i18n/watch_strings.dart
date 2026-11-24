import 'app_strings.dart';

/// Watch app copy. Grouped in its own class so the shared [AppStrings] stays
/// readable while a whole module is migrated.
abstract class WatchStrings {
  const WatchStrings();

  String battery(int percent);
  String dateShort(int month, int day);
  String lastSync(String time);
  String firmware(String version);
  String get currentFace;
  String get connected;
  String get retrySync;
  String get cardFace;
  String get cardNotification;
  String get cardHealth;
  String get cardOta;
  String get cardFactory;
  String get needBind;
  String get bindDevice;
  String get binding;
  String get bound;
  String get rebind;
  String get cannotBind;
  String get batteryUnknown;
  String get chargingSuffix;
  String get firmwareUnknown;
  String get faceDescription;
  String get currentFaceUnknown;
  String get bleConnected;
  String get reading;
  String get retryRead;
  String get healthTitle;
  String get syncHealthTooltip;
  String get todayOverview;
  String get syncingData;
  String get deviceNotBound;
  String get syncFailedRetry;
  String get neverSynced;
  String get retry;
  String get syncing;
  String get sync;
  String get syncNow;
  String get resync;
  String get readingWatchData;
  String get bindWatchFirst;
  String get syncIncomplete;
  String get syncToView;
  String get waitingRecords;
  String get bindToSync;
  String get keepConnected;
  String get providedByWatch;
  String get steps;
  String get unitSteps;
  String get distance;
  String get unitKm;
  String get calories;
  String get unitKcal;
  String get lastHeartRate;
  String get noData;
  String get unitBpm;
  String get sleep;
  String get unitHours;
  String get trend;
  String get periodDay;
  String get periodWeek;
  String get periodMonth;
  String get legendHeartRate;
  String get noSleepRecords;
  String get noHeartRateRecords;
  String get heartRate;
  String heartRateValue(int bpm);
  String sleepStage(int minutes);
  String heartRatePeriods(int count);
  String get notificationTitle;
  String get factoryTitle;
}

class ZhWatchStrings extends WatchStrings {
  const ZhWatchStrings();

  @override
  String battery(int percent) => '电量 $percent%';

  @override
  String dateShort(int month, int day) => '$month月$day日';

  @override
  String lastSync(String time) => '最近同步：$time';

  @override
  String firmware(String version) => '固件 $version';

  @override
  String get currentFace => '当前表盘';
  @override
  String get connected => '已连接';
  @override
  String get retrySync => '重试同步';
  @override
  String get cardFace => '表盘推送';
  @override
  String get cardNotification => '通知转发';
  @override
  String get cardHealth => '运动 / 健康';
  @override
  String get cardOta => '固件 OTA 升级';
  @override
  String get cardFactory => '工厂测试';
  @override
  String get needBind => '请先完成设备绑定';
  @override
  String get bindDevice => '绑定设备';
  @override
  String get binding => '绑定中...';
  @override
  String get bound => '已绑定';
  @override
  String get rebind => '重新绑定';
  @override
  String get cannotBind => '无法绑定';
  @override
  String get batteryUnknown => '电量 —';
  @override
  String get chargingSuffix => ' · 充电中';
  @override
  String get firmwareUnknown => '固件 —';

  @override
  String get faceDescription => '选择或自定义表盘，并推送设为手表当前表盘';
  @override
  String get currentFaceUnknown => '当前表盘 · —';
  @override
  String get bleConnected => 'BLE 已连接';
  @override
  String get reading => '读取中';
  @override
  String get retryRead => '重试读取';
  @override
  String get healthTitle => '运动 / 健康';
  @override
  String get syncHealthTooltip => '同步健康数据';
  @override
  String get todayOverview => '今日概览';
  @override
  String get syncingData => '正在同步健康数据...';
  @override
  String get deviceNotBound => '设备尚未绑定';
  @override
  String get syncFailedRetry => '同步失败 · 可重新尝试';
  @override
  String get neverSynced => '尚未同步健康数据';
  @override
  String get retry => '重试';
  @override
  String get syncing => '同步中';

  @override
  String get sync => '同步';
  @override
  String get syncNow => '立即同步';
  @override
  String get resync => '重新同步';
  @override
  String get readingWatchData => '正在读取手表数据';
  @override
  String get bindWatchFirst => '请先绑定手表';
  @override
  String get syncIncomplete => '同步未完成';
  @override
  String get syncToView => '同步手表后即可查看';
  @override
  String get waitingRecords => '等待手表返回运动、睡眠和心率记录';
  @override
  String get bindToSync => '连接后需先完成绑定，才能同步健康数据';
  @override
  String get keepConnected => '请确认手表保持连接，然后重新同步';
  @override
  String get providedByWatch => '数据由已连接的手表提供';
  @override
  String get steps => '步数';
  @override
  String get unitSteps => '步';
  @override
  String get distance => '距离';
  @override
  String get unitKm => '公里';
  @override
  String get calories => '卡路里';
  @override
  String get unitKcal => '千卡';
  @override
  String get lastHeartRate => '最近心率';
  @override
  String get noData => '暂无数据';
  @override
  String get unitBpm => '次/分';
  @override
  String get sleep => '睡眠';
  @override
  String get unitHours => '小时';
  @override
  String get trend => '趋势';

  @override
  String get periodDay => '日';

  @override
  String get periodWeek => '周';

  @override
  String get periodMonth => '月';

  @override
  String get legendHeartRate => '心率';

  @override
  String get noSleepRecords => '手表未返回睡眠记录';

  @override
  String get noHeartRateRecords => '手表未返回心率记录';

  @override
  String get heartRate => '心率';

  @override
  String heartRateValue(int bpm) => '$bpm 次/分';

  @override
  String sleepStage(int minutes) => '${minutes ~/ 60}时${minutes % 60}分';

  @override
  String heartRatePeriods(int count) => '$count 个时段';
  @override
  String get notificationTitle => '通知转发';
  @override
  String get factoryTitle => '工厂测试';
}

class EnWatchStrings extends WatchStrings {
  const EnWatchStrings();

  @override
  String battery(int percent) => 'Battery $percent%';

  @override
  String dateShort(int month, int day) => '$month/$day';

  @override
  String lastSync(String time) => 'Last sync: $time';

  @override
  String firmware(String version) => 'Firmware $version';

  @override
  String get currentFace => 'Current face';
  @override
  String get connected => 'Connected';
  @override
  String get retrySync => 'Retry sync';
  @override
  String get cardFace => 'Watch faces';
  @override
  String get cardNotification => 'Notifications';
  @override
  String get cardHealth => 'Activity & health';
  @override
  String get cardOta => 'Firmware OTA';
  @override
  String get cardFactory => 'Factory test';
  @override
  String get needBind => 'Bind the device first';
  @override
  String get bindDevice => 'Bind device';
  @override
  String get binding => 'Binding…';
  @override
  String get bound => 'Bound';
  @override
  String get rebind => 'Rebind';
  @override
  String get cannotBind => 'Cannot bind';
  @override
  String get batteryUnknown => 'Battery —';
  @override
  String get chargingSuffix => ' · charging';
  @override
  String get firmwareUnknown => 'Firmware —';

  @override
  String get faceDescription =>
      'Pick or customise a watch face and push it as the current face';
  @override
  String get currentFaceUnknown => 'Current face · —';
  @override
  String get bleConnected => 'BLE connected';
  @override
  String get reading => 'Reading';
  @override
  String get retryRead => 'Retry';
  @override
  String get healthTitle => 'Activity & health';
  @override
  String get syncHealthTooltip => 'Sync health data';
  @override
  String get todayOverview => 'Today';
  @override
  String get syncingData => 'Syncing health data…';
  @override
  String get deviceNotBound => 'Device not bound';
  @override
  String get syncFailedRetry => 'Sync failed · tap to retry';
  @override
  String get neverSynced => 'No health data yet';
  @override
  String get retry => 'Retry';
  @override
  String get syncing => 'Syncing';

  @override
  String get sync => 'Sync';
  @override
  String get syncNow => 'Sync now';
  @override
  String get resync => 'Sync again';
  @override
  String get readingWatchData => 'Reading watch data';
  @override
  String get bindWatchFirst => 'Bind the watch first';
  @override
  String get syncIncomplete => 'Sync incomplete';
  @override
  String get syncToView => 'Sync the watch to see data';
  @override
  String get waitingRecords =>
      'Waiting for activity, sleep and heart-rate records';
  @override
  String get bindToSync => 'Bind the device to sync health data';
  @override
  String get keepConnected => 'Keep the watch connected, then sync again';
  @override
  String get providedByWatch => 'Data comes from the connected watch';
  @override
  String get steps => 'Steps';
  @override
  String get unitSteps => 'steps';
  @override
  String get distance => 'Distance';
  @override
  String get unitKm => 'km';
  @override
  String get calories => 'Calories';
  @override
  String get unitKcal => 'kcal';
  @override
  String get lastHeartRate => 'Last heart rate';
  @override
  String get noData => 'No data';
  @override
  String get unitBpm => 'bpm';
  @override
  String get sleep => 'Sleep';
  @override
  String get unitHours => 'h';
  @override
  String get trend => 'Trend';

  @override
  String get periodDay => 'D';

  @override
  String get periodWeek => 'W';

  @override
  String get periodMonth => 'M';

  @override
  String get legendHeartRate => 'Heart rate';

  @override
  String get noSleepRecords => 'The watch returned no sleep records';

  @override
  String get noHeartRateRecords => 'The watch returned no heart-rate records';

  @override
  String get heartRate => 'Heart rate';

  @override
  String heartRateValue(int bpm) => '$bpm bpm';

  @override
  String sleepStage(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

  @override
  String heartRatePeriods(int count) => '$count periods';
  @override
  String get notificationTitle => 'Notifications';
  @override
  String get factoryTitle => 'Factory test';
}
