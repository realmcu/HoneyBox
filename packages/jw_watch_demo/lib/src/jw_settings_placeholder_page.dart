import 'package:flutter/material.dart';

import 'jw_settings_app_widgets.dart';
import 'jw_settings_catalog.dart';

class JwSettingsPlaceholderPage extends StatelessWidget {
  const JwSettingsPlaceholderPage({
    super.key,
    required this.title,
    required this.status,
    this.androidRef,
    this.detail,
  });

  final String title;
  final JwSettingsImplStatus status;
  final String? androidRef;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final body = switch (status) {
      JwSettingsImplStatus.sdkUnsupported =>
        '当前 jw_watch_sdk 尚未提供对应公开 API。Demo 先保留 UI 入口，便于对照 App（UK）查漏；后续 SDK 补齐后再接线。',
      JwSettingsImplStatus.deferredThisSprint =>
        '本轮 Demo 改造明确暂不实现（资源服务 / OTA / 表盘等）。设备若支持，仍可在能力列表中看到相关位。',
      JwSettingsImplStatus.sdkReady => '该项应已接入 SDK，请从设置主页重新进入。',
    };
    return Scaffold(
      backgroundColor: JwSettingsAppTheme.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: JwSettingsAppTheme.card,
        foregroundColor: JwSettingsAppTheme.title,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          JwSettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JwSettingsStatusChip(status),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: JwSettingsAppTheme.title,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        detail!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: JwSettingsAppTheme.subtitle,
                        ),
                      ),
                    ],
                    if (androidRef != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Android 对照：$androidRef',
                        style: const TextStyle(
                          fontSize: 12,
                          color: JwSettingsAppTheme.muted,
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
