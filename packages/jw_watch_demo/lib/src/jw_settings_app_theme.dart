import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 对齐 WoFit App `WatchDetail` / `styles.xml` 设置主题（浅色）。
///
/// 颜色来自 `nor_cl_setting_*`；字号来自 `tv_item_title` / `tv_section_title` 等。
abstract final class JwSettingsAppTheme {
  /// `nor_cl_setting_bg` / `nor_cl_setting_bg1`
  static const background = Color(0xFFEDF0FA);

  /// `nor_cl_setting_item_bg` / `shape_item_default`
  static const card = Color(0xFFFFFFFF);

  /// `nor_cl_setting_toolbar_bg`
  static const toolbar = Color(0xFFFFFFFF);

  /// `nor_cl_setting_title`
  static const title = Color(0xFF171C3C);

  /// `nor_cl_setting_title_light`
  static const titleLight = Color(0xCC171C3C);

  /// `nor_cl_setting_gray` — 分组标题等
  static const section = Color(0xFFB1B1B1);

  /// 间隔/副文案（App 间隔 value `#818181`）
  static const subtitle = Color(0xFF818181);

  /// `nor_cl_setting_value` / `nor_cl_setting_opt` — 可点 API 标题、强调
  static const accent = Color(0xFF5C5CE0);

  /// 白主题 `nor_cl_find_device_color`（查找设备水波纹）
  static const findDeviceRipple = Color(0xFFF5024E);

  /// `nor_cl_setting_contact` / 链接蓝
  static const link = Color(0xFF007AFF);

  static const warn = Color(0xFFB86A00);
  static const muted = Color(0xFFB1B1B1);
  static const divider = Color(0xFFE8E8E8);

  /// App `shape_btn_positive`（断开连接等主操作按钮）
  static const positiveButton = Color(0xFFFF2D55);
  static const positiveButtonText = Color(0xFFFFFFFF);

  /// App `shape_btn_negative`
  static const negativeButton = Color(0xFFE6E6E6);

  /// App `shape_btn_*` 圆角（小圆角矩形，非胶囊）
  static const buttonRadius = 8.0;

  /// App `selector_sheet_time_tips` / `selector_sheet_time_text_color` 选中态
  static const sheetTimeTipSelectedBg = Color(0xFFFFD5DD);
  static const sheetTimeTipSelectedText = Color(0xFFFF2D55);

  /// `shape_item_default` corners
  static const itemRadius = 8.0;

  /// `item_default` minHeight
  static const itemMinHeight = 54.0;

  /// 主页 item 间距（App `layout_marginTop="8dp"`）
  static const itemGap = 8.0;

  /// 主页左右边距（`layout_device_operate` padding 16）
  static const pagePaddingH = 16.0;

  static const itemTitle = TextStyle(
    fontSize: 17,
    height: 1.2,
    color: title,
    fontWeight: FontWeight.w400,
  );

  static const itemSubTitle = TextStyle(
    fontSize: 15,
    height: 1.2,
    color: subtitle,
    fontWeight: FontWeight.w400,
  );

  static const itemValue = TextStyle(
    fontSize: 13,
    height: 1.2,
    color: subtitle,
    fontWeight: FontWeight.w400,
  );

  static const sectionTitle = TextStyle(
    fontSize: 19,
    height: 1.2,
    color: section,
    fontWeight: FontWeight.w700,
  );

  static const reminderTitle = TextStyle(
    fontSize: 17,
    height: 1.2,
    color: title,
    fontWeight: FontWeight.w700,
  );

  /// 设置相关页面可包一层，统一背景 / AppBar / Switch 色。
  static ThemeData theme([ThemeData? base]) {
    final seed = base ?? ThemeData(useMaterial3: true);
    return seed.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: seed.colorScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: card,
        onSurface: title,
        outline: divider,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: toolbar,
        foregroundColor: title,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: title,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: title),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(itemRadius),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFFF5F5F5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF4CD964); // nor_cl_setting_switch_on
          }
          return const Color(0xFFB7B7B7); // nor_cl_setting_switch_off
        }),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: title,
        textColor: title,
        minVerticalPadding: 0,
      ),
    );
  }
}

/// Demo 包内从 App 复制的设置图标。
abstract final class JwSettingsIcons {
  static const _pkg = 'jw_watch_demo';
  static const _dir = 'assets/settings';

  static const chevron = '$_dir/setting_aron_icon.png';
  static const chevronGray = '$_dir/icon_arrow_right_gray.png';

  static const findDevice = '$_dir/setting_device_icon_find.png';
  static const findBand = '$_dir/icon_findband.png';
  static const takePhoto = '$_dir/setting_device_icon_camera.png';
  static const telephone = '$_dir/icon_telephone.png';
  static const alarm = '$_dir/setting_device_icon_clock.png';
  static const notifyRemind = '$_dir/setting_device_icon_message.png';
  static const eventRemind = '$_dir/icon_event_reminder.png';
  static const longSit = '$_dir/setting_device_icon_sit.png';
  static const healthMonitoring = '$_dir/setting_device_icon_switches.png';
  static const doNotDisturb = '$_dir/setting_device_icon_disturb.png';
  static const language = '$_dir/icon_device_language_settings.png';
  static const unitSettings = '$_dir/setting_unitsetting_icon.png';
  static const screenDisplay = '$_dir/icon_screen_display.png';
  static const autoScreenOff = '$_dir/icon_auto_screen_off.png';
  static const autoScreenLock = '$_dir/icon_auto_screen_lock.png';
  static const turnWrist = '$_dir/setting_device_icon_turnwrist.png';
  static const brightnessDark = '$_dir/setting_device_lightj_dark.png';
  static const brightnessLight = '$_dir/setting_device_lightj_dark2.png';
  static const syncTime = '$_dir/setting_device_icon_date_format.png';
  static const userProfile = '$_dir/ic_setting_user.png';
  static const watchFace = '$_dir/setting_device_icon.png';
  static const clearData = '$_dir/icon_clear_device_data.png';
  static const firmwareUpdate = '$_dir/setting_device_icon_update.png';
  static const disconnect = '$_dir/setting_device_icon_delete.png';

  static const heartRate = '$_dir/icon_heart_rate_auto_measure.png';
  static const highHeartRate = '$_dir/icon_high_heart_rate_alarm.png';
  static const bloodPressure = '$_dir/icon_blood_pressure_auto_measure.png';
  static const spo2 = '$_dir/icon_spo2_auto_measure.png';
  static const lowSpo2 = '$_dir/icon_low_spo2.png';
  static const bloodSugar = '$_dir/icon_blood_sugar_auto_measure.png';
  static const heatStress = '$_dir/icon_heat_stress_reminder_set.png';
  static const sleepAll = '$_dir/icon_sleep_all_set.png';
  static const temperature = '$_dir/icon_temperature_auto_measure.png';
  static const pressure = '$_dir/icon_pressure_auto_measure.png';

  static String _fileName(String assetOrFile) {
    final i = assetOrFile.lastIndexOf('/');
    return i < 0 ? assetOrFile : assetOrFile.substring(i + 1);
  }

  /// 按优先级尝试多个清单键（宿主 / packages 前缀 / 包内）。
  static List<String> assetKeys(String assetOrFile) {
    final file = _fileName(assetOrFile);
    return [
      'assets/jw_settings/$file',
      'packages/$_pkg/assets/settings/$file',
      'assets/settings/$file',
    ];
  }

  static Future<Uint8List?> loadBytes(String assetOrFile) async {
    for (final key in assetKeys(assetOrFile)) {
      try {
        final data = await rootBundle.load(key);
        return data.buffer.asUint8List();
      } catch (_) {
        // try next key
      }
    }
    return null;
  }

  static Widget image(
    String asset, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
    IconData fallback = Icons.settings_outlined,
  }) {
    return _JwSettingsAssetImage(
      asset: asset,
      width: width ?? 22,
      height: height ?? 22,
      fit: fit,
      color: color,
      fallback: fallback,
    );
  }
}

class _JwSettingsAssetImage extends StatefulWidget {
  const _JwSettingsAssetImage({
    required this.asset,
    required this.width,
    required this.height,
    required this.fit,
    required this.fallback,
    this.color,
  });

  final String asset;
  final double width;
  final double height;
  final BoxFit fit;
  final Color? color;
  final IconData fallback;

  @override
  State<_JwSettingsAssetImage> createState() => _JwSettingsAssetImageState();
}

class _JwSettingsAssetImageState extends State<_JwSettingsAssetImage> {
  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _JwSettingsAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await JwSettingsIcons.loadBytes(widget.asset);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _failed = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: w,
        height: h,
        fit: widget.fit,
        color: widget.color,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }
    // 加载中或失败：先用 Material 图标占位，避免空白。
    return SizedBox(
      width: w,
      height: h,
      child: Icon(
        widget.fallback,
        size: w * 0.9,
        color: _failed
            ? JwSettingsAppTheme.muted
            : JwSettingsAppTheme.title,
      ),
    );
  }
}
