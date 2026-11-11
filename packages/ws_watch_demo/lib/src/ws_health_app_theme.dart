import 'package:flutter/material.dart';

/// 对齐 Android App **亮色主题** `whitetheme/.../colors.xml`。
abstract final class WsHealthAppTheme {
  static const topBg = Color(0xFFF9F9F9);
  static const pageBg = Color(0xFFF9F9F9);
  static const toolbarBg = Color(0xFFFFFFFF);
  static const toolbarFg = Color(0xFF000000);
  static const infoItem = Color(0xFFFFFFFF);
  static const infoTitle = Color(0xFF000000);
  static const infoTitleLight = Color(0xCC000000);
  static const infoUnit = Color(0xFFB7B7B7);
  static const topDate = Color(0xFF000000);
  static const topTurn = Color(0xFF000000);
  static const topTurnDisabled = Color(0x4D000000);

  // StepTouchView
  static const stepTrack = Color(0x08000000);
  static const stepBegin = Color(0xFFFF4D35);
  static const stepEnd = Color(0xFFFF614C);
  static const stepEmpty = Color(0xFFB7B7B7);
  static const stepThumb = Color(0xFFB7B7B7);
  static const stepThumbBg = Color(0xFFFF4229);
  static const stepLabel = Color(0xFFB7B7B7);
  static const stepBuoy = Color(0xFFFF4229);

  // HeartRateTouchView3
  static const hrChartBg = Color(0xFFFFFFFF);
  static const hrHeadLine = Color(0xFFE6E6E6);
  static const hrEmpty = Color(0xFFB7B7B7);
  static const hrAvgDash = Color(0xFFF5024E);
  static const hrAvgText = Color(0xFFFFFFFF);
  static const hrSampleDot = Color(0xFFEBEBEB);
  static const hrLine = Color(0xFFF03F3E);
  static const hrThumbBg = Color(0xFFFF2D55);
  static const hrBuoy = Color(0xFFFF4229);
  static const hrValueEsp = Color(0xFFF03F3E);
  static const hrAxisLabel = Color(0xFFB7B7B7);

  // SleepTouchView
  static const sleepAwake = Color(0xFF827CF0);
  static const sleepRem = Color(0xFFEF60AB);
  static const sleepLight = Color(0xFFB45BFF);
  static const sleepDeep = Color(0xFF981AF1);
  static const sleepEmpty = Color(0xFFB7B7B7);
  static const sleepThumbBg = Color(0xFF981AF1);
  static const sleepBuoy = Color(0xFF981AF1);

  // BpTouchView2
  static const bpBandHigh = Color(0xFFFAEFE0);
  static const bpBandLow = Color(0xFFFAE7CC);
  static const bpHigh = Color(0xFFFF9000);
  static const bpLow = Color(0xFFFFA425);
  static const bpText = Color(0xFFB7B7B7);
  static const bpEmpty = Color(0xFFB7B7B7);
  static const bpHeadLine = Color(0xFFE6E6E6);
  static const bpThumbBg = Color(0xFFFF9F19);
  static const bpBuoy = Color(0xFFFF9F19);

  // Spo2TouchView2
  static const spo2Value = Color(0xFFFF7719);
  static const spo2Text = Color(0xFFB7B7B7);
  static const spo2Empty = Color(0xFFB7B7B7);
  static const spo2HeadLine = Color(0xFFE6E6E6);
  static const spo2ThumbBg = Color(0xFFFF7719);
  static const spo2Buoy = Color(0xFFFF7719);

  // TempTouchView
  static const tempValue = Color(0xCCFFC009);
  static const tempValueHigh = Color(0xFFFFC009);
  static const tempText = Color(0xFFB7B7B7);
  static const tempEmpty = Color(0xFFB7B7B7);
  static const tempLine = Color(0xFFE6E6E6);
  static const tempThumbBg = Color(0xFFFFC009);
  static const tempBuoy = Color(0xFFFFC009);
  static const tempAvgBg = Color(0xFFFFC009);

  // HrvTouchView
  static const hrvValue = Color(0xCCFF0000);
  static const hrvText = Color(0xFFB7B7B7);
  static const hrvEmpty = Color(0xFFB7B7B7);
  static const hrvLine = Color(0xFFE6E6E6);
  static const hrvThumbBg = Color(0xFFFF2828);
  static const hrvBuoy = Color(0xFFFF2828);

  // PressureTouchView3
  static const pressureLow = Color(0xFF27DEB0);
  static const pressureNormal = Color(0xFF2EACEE);
  static const pressureMedium = Color(0xFFECD32B);
  static const pressureHigh = Color(0xFFF0712B);
  static const pressureText = Color(0xFFB7B7B7);
  static const pressureEmpty = Color(0xFFB7B7B7);
  static const pressureHeadLine = Color(0xFFE6E6E6);
  static const pressureThumbBg = Color(0xFF20CFD1);
  static const pressureBuoy = Color(0xFF20CFD1);

  // BloodSugarTouchView3
  static const gluDot = Color(0xFFEBEBEB);
  static const gluLine = Color(0xFFF03F3E);
  static const gluText = Color(0xFFB7B7B7);
  static const gluEmpty = Color(0xFFB7B7B7);
  static const gluHeadLine = Color(0xFFE6E6E6);
  static const gluThumbBg = Color(0xFFFF2D55);
  static const gluBuoy = Color(0xFFFF4229);
  static const gluAvgDash = Color(0xFFF5024E);

  // Sport day bars
  static const sportBar = Color(0xFFFF4D35);
  static const sportBarTrack = Color(0x08000000);
  static const sportText = Color(0xFFB7B7B7);
  static const sportEmpty = Color(0xFFB7B7B7);
  static const sportBuoy = Color(0xFFFF4229);

  static const chartTouchDelay = Duration(milliseconds: 501);
  static const dateBarHeight = 48.0;
  static const chartBottomInset = 25.0;

  /// 绘图区固定高度（不含日期条）。
  ///
  /// 按 375 设计宽下 App `64.2%w`≈241 的卡片体量推算，再扣掉详情页日期条，
  /// 取整为 220，避免再跟屏宽百分比漂移。
  static const chartPlotHeight = 220.0;

  /// 顶部面板 = 日期条 + 绘图区。
  static const topPanelHeight = dateBarHeight + chartPlotHeight;
}
