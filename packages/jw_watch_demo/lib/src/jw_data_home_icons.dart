import 'package:flutter/material.dart';

import 'jw_data_catalog.dart';
import 'jw_settings_app_theme.dart';

/// 数据首页图标：优先宿主 `assets/jw_data_home/`，否则包内 `package: jw_watch_demo`。
abstract final class JwDataHomeIcons {
  static const _pkg = 'jw_watch_demo';

  static String _fileName(JwDataTypeId id) {
    return switch (id) {
      JwDataTypeId.activity => 'home_icon_steps.png',
      JwDataTypeId.sleep => 'home_icon_sleep.png',
      JwDataTypeId.heartRate => 'home_icon_bpm.png',
      JwDataTypeId.bloodPressure => 'home_icon_mm_hg.png',
      JwDataTypeId.bloodOxygen => 'home_icon_bloodoxygen.png',
      JwDataTypeId.temperature => 'home_icon_temputure.png',
      JwDataTypeId.hrv => 'home_icon_hrv.png',
      JwDataTypeId.pressure => 'home_icon_pressure.png',
      JwDataTypeId.bloodSugar => 'home_icon_blood_sugar.png',
      JwDataTypeId.sport => 'home_icon_weight.png',
    };
  }

  static Widget image(
    JwDataTypeId id, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    required IconData fallback,
  }) {
    final file = _fileName(id);
    final fallbackIcon = Icon(
      fallback,
      size: width * 0.55,
      color: JwSettingsAppTheme.title,
    );
    return Image.asset(
      'assets/jw_data_home/$file',
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/data_home/$file',
          package: _pkg,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => fallbackIcon,
        );
      },
    );
  }
}
