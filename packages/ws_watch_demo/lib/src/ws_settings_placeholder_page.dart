import 'package:flutter/material.dart';

import 'ws_settings_app_widgets.dart';
import 'ws_settings_catalog.dart';
import 'ws_settings_app_theme.dart';

class WsSettingsPlaceholderPage extends StatelessWidget {
  const WsSettingsPlaceholderPage({
    super.key,
    required this.title,
    required this.status,
    this.androidRef,
    this.detail,
  });

  final String title;
  final WsSettingsImplStatus status;
  final String? androidRef;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final body = switch (status) {
      WsSettingsImplStatus.sdkUnsupported =>
        '当前 ws_watch_sdk 尚未提供对应公开 API。Demo 先保留 UI 入口，便于对照 App（UK）查漏；后续 SDK 补齐后再接线。',
      WsSettingsImplStatus.deferredThisSprint =>
        '本轮 Demo 改造明确暂不实现（资源服务 / OTA / 表盘等）。设备若支持，仍可在能力列表中看到相关位。',
      WsSettingsImplStatus.sdkReady => '该项应已接入 SDK，请从设置主页重新进入。',
    };
    return Scaffold(
      backgroundColor: WsSettingsAppTheme.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: WsSettingsAppTheme.card,
        foregroundColor: WsSettingsAppTheme.title,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WsSettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WsSettingsStatusChip(status),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: WsSettingsAppTheme.title,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        detail!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: WsSettingsAppTheme.subtitle,
                        ),
                      ),
                    ],
                    if (androidRef != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Android 对照：$androidRef',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WsSettingsAppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
