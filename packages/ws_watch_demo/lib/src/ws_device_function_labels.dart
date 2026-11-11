import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'compat/ws_demo_compat.dart';

/// Demo-only Chinese labels for [WSDeviceFunction]. SDK keeps English identifiers.
String jwDeviceFunctionLabel(WSDeviceFunction function) {
  return switch (function) {
    WSDeviceFunction.musicControl => '音乐控制',
    WSDeviceFunction.volumeControl => '音量控制',
    WSDeviceFunction.alarm => '智能闹钟',
    WSDeviceFunction.longSitReminder => '久坐提醒',
    WSDeviceFunction.eventReminder => '事件提醒',
    WSDeviceFunction.autoLock => '锁屏防触',
    WSDeviceFunction.appSportRateDetect => 'App 运动心率检测',
    WSDeviceFunction.baseSwitch => '基础开关',
    WSDeviceFunction.multiSport => '多运动模式',
    WSDeviceFunction.stepWatch => '秒表',
    WSDeviceFunction.countDown => '倒计时',
    WSDeviceFunction.rateReminder => '心率提醒',
    WSDeviceFunction.cameraControl => '遥控拍照',
    WSDeviceFunction.findPhone => '查找手机',
    WSDeviceFunction.findDevice => '查找手环',
    WSDeviceFunction.lightControl => '亮度控制',
    WSDeviceFunction.notifyReminder => '消息提醒',
    WSDeviceFunction.screenTheme => '主界面切换',
    WSDeviceFunction.turnLight => '转腕亮屏',
    WSDeviceFunction.multiLanguage => '多国语言',
    WSDeviceFunction.hourSystem => '小时制',
    WSDeviceFunction.unitSystem => '公英制',
    WSDeviceFunction.ota => 'OTA 升级',
    WSDeviceFunction.nfc => 'NFC',
    WSDeviceFunction.earPhone => '通话耳机',
    WSDeviceFunction.bpDetection => '血压手动测量',
    WSDeviceFunction.rate => '心率',
    WSDeviceFunction.disturb => '勿扰模式',
    WSDeviceFunction.step => '计步',
    WSDeviceFunction.sleep => '睡眠',
    WSDeviceFunction.weChatRun => '微信运动',
    WSDeviceFunction.lightDuration => '亮屏时长',
    WSDeviceFunction.todayAdjust => '今日数据校准',
    WSDeviceFunction.sleepAdjust => '睡眠数据校准',
    WSDeviceFunction.temperature => '体温',
    WSDeviceFunction.bp2 => '血压 2.0',
    WSDeviceFunction.alarm2 => '闹钟 2.0',
    WSDeviceFunction.customUi => '自定义主界面',
    WSDeviceFunction.downloadUi => '下载主界面',
    WSDeviceFunction.spo2Measure => '血氧测量',
    WSDeviceFunction.modeUpgrade => '字库升级',
    WSDeviceFunction.sleepQuality2 => '睡眠质量 2.0',
    WSDeviceFunction.sportRate2 => 'App 运动心率 2.0',
    WSDeviceFunction.rateTempPressure => '心率/体温/压力数据',
    WSDeviceFunction.spo2Continuous => '连续血氧',
    WSDeviceFunction.ecgFunction => '心电',
    WSDeviceFunction.deviceStateSync => '同步设备状态',
    WSDeviceFunction.addressBook => '通讯录',
    WSDeviceFunction.rtkHrv => 'HRV',
    WSDeviceFunction.rtkBp3 => '血压 3.0',
    WSDeviceFunction.bloodSugar => '血糖',
    WSDeviceFunction.hypoxia => '低氧提醒',
    WSDeviceFunction.highHrv => '心率过高提醒',
    WSDeviceFunction.sleepAll => '全天睡眠',
    WSDeviceFunction.deviceDateFormat => '日期格式',
    WSDeviceFunction.hideQTAndHrv => '隐藏 QT/HRV',
    WSDeviceFunction.readiness => '准备度',
    WSDeviceFunction.metab => 'METAB 日摘要',
    WSDeviceFunction.controlDeviceSport => 'App 控制多运动',
    WSDeviceFunction.heatStress => '热应激',
    WSDeviceFunction.pressure => '压力',
    WSDeviceFunction.hideHealthFunction => '隐藏健康功能',
    WSDeviceFunction.ecgBelt => '心电带',
  };
}

List<WSDeviceFunction> jwSupportedFunctionsSorted(WSDeviceFunctionInfo info) {
  final supported = info.supported.toList();
  supported.sort(
    (a, b) => jwDeviceFunctionLabel(a).compareTo(jwDeviceFunctionLabel(b)),
  );
  return supported;
}
