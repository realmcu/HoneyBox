/// 详情页完整坐标 vs 首页缩略图（无 Y 轴刻度、无长按）。
enum JwAppChartMode { detail, home }

/// 固定首页图表高度（不用屏宽百分比）。
const double jwAppHomeChartHeight = 96;

abstract final class JwAppChartLayout {
  static const homeTop = 2.0;

  /// 首页统一底边（容纳 10.6sp 整点刻度 + 与底边空隙）。
  static const homeBottom = 26.0;
  static const detailTop = 19.0;

  static double top(JwAppChartMode mode) =>
      mode == JwAppChartMode.home ? homeTop : detailTop;

  static double bottomText(JwAppChartMode mode, {required double detail}) =>
      mode == JwAppChartMode.home ? homeBottom : detail;

  /// 首页 / 详情通用：X 轴圆点在底边带内居中偏上。
  static double xAxisDotY(double height, double bottomBand) =>
      height - bottomBand * 0.55;

  /// 整点文字在底边带内，距底留白。
  static double xAxisLabelY(double height, double bottomBand) =>
      height - bottomBand * 0.22;

  /// 详情血压等大 `bottomText` 的历史偏移（仅 detail）。
  static double xAxisDotYBpDetail(double height, double bottomBand) =>
      height - bottomBand + 20;

  static double xAxisLabelYBpDetail(double height, double bottomBand) =>
      height - bottomBand + 23;

  static bool showYAxis(JwAppChartMode mode) => mode == JwAppChartMode.detail;

  /// 首页 Preview 仍画 0/23 点与整点刻度（无 Y 轴数字）。
  static bool showXAxis(JwAppChartMode mode) => true;

  static bool showEmptyHint(JwAppChartMode mode) => true;

  static double emptyHintFontSize(JwAppChartMode mode) =>
      mode == JwAppChartMode.home ? 14.0 : 23.0;

  static bool interactive(JwAppChartMode mode) => mode == JwAppChartMode.detail;
}
