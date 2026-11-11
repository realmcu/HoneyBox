import 'package:flutter/material.dart';

import 'ws_data_catalog.dart';
import 'ws_settings_app_theme.dart';

/// 数据首页图标：优先宿主 `assets/jw_data_home/`，否则包内 `package: ws_watch_demo`。
abstract final class WsDataHomeIcons {
  static const _pkg = 'ws_watch_demo';

  static String _fileName(WsDataTypeId id) {
    return switch (id) {
      WsDataTypeId.activity => 'home_icon_steps.png',
      WsDataTypeId.sleep => 'home_icon_sleep.png',
      WsDataTypeId.heartRate => 'home_icon_bpm.png',
      WsDataTypeId.bloodPressure => 'home_icon_mm_hg.png',
      WsDataTypeId.bloodOxygen => 'home_icon_bloodoxygen.png',
      WsDataTypeId.temperature => 'home_icon_temputure.png',
      WsDataTypeId.hrv => 'home_icon_hrv.png',
      WsDataTypeId.pressure => 'home_icon_pressure.png',
      WsDataTypeId.bloodSugar => 'home_icon_blood_sugar.png',
      WsDataTypeId.sport => 'home_icon_weight.png',
    };
  }

  static Widget image(
    WsDataTypeId id, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    required IconData fallback,
  }) {
    final file = _fileName(id);
    final fallbackIcon = Icon(
      fallback,
      size: width * 0.55,
      color: WsSettingsAppTheme.title,
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
