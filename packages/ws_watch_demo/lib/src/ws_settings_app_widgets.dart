import 'package:flutter/material.dart';

import 'ws_settings_api_sheet.dart';
import 'ws_settings_app_theme.dart';
import 'ws_settings_catalog.dart';

export 'ws_settings_app_theme.dart';

class WsSettingsSectionHeader extends StatelessWidget {
  const WsSettingsSectionHeader(this.title, {super.key, this.apiCode});

  final String title;
  final String? apiCode;

  @override
  Widget build(BuildContext context) {
    // 对齐 WatchDetail：title paddingTop 15 / paddingBottom 7；
    // 下方首项再 marginTop 8，合计标题到卡片约 15dp。
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WsSettingsAppTheme.pagePaddingH + 5,
        15,
        WsSettingsAppTheme.pagePaddingH,
        7,
      ),
      child: apiCode == null
          ? Text(title, style: WsSettingsAppTheme.sectionTitle)
          : WsSettingsApiTitle(
              title: title,
              apiCode: apiCode!,
              style: WsSettingsAppTheme.sectionTitle,
            ),
    );
  }
}

class WsSettingsStatusChip extends StatelessWidget {
  const WsSettingsStatusChip(this.status,
      {super.key, this.deviceUnsupported = false});

  final WsSettingsImplStatus status;
  final bool deviceUnsupported;

  @override
  Widget build(BuildContext context) {
    final label = deviceUnsupported
        ? '设备不支持'
        : jwSettingsImplStatusLabel(status);
    if (label == null) return const SizedBox.shrink();
    final color = deviceUnsupported
        ? WsSettingsAppTheme.muted
        : switch (status) {
            WsSettingsImplStatus.sdkReady => WsSettingsAppTheme.accent,
            WsSettingsImplStatus.sdkUnsupported => WsSettingsAppTheme.warn,
            WsSettingsImplStatus.deferredThisSprint => WsSettingsAppTheme.muted,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 对齐 App `shape_item_default`：每个功能独立圆角白底卡片。
class WsSettingsItemCard extends StatelessWidget {
  const WsSettingsItemCard({
    super.key,
    required this.child,
    this.onTap,
    this.marginTop = WsSettingsAppTheme.itemGap,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(WsSettingsAppTheme.itemRadius);
    return Padding(
      padding: EdgeInsets.only(
        left: WsSettingsAppTheme.pagePaddingH,
        right: WsSettingsAppTheme.pagePaddingH,
        top: marginTop,
      ),
      child: Material(
        color: WsSettingsAppTheme.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? child
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: child,
              ),
      ),
    );
  }
}

class WsSettingsRow extends StatelessWidget {
  const WsSettingsRow({
    super.key,
    required this.item,
    required this.onTap,
    this.deviceUnsupported = false,
    this.trailingSummary,
    this.showDivider = false,
    this.asStandaloneCard = true,
    this.marginTop = WsSettingsAppTheme.itemGap,
  });

  final WsSettingsItem item;
  final VoidCallback onTap;
  final bool deviceUnsupported;
  final String? trailingSummary;

  /// 主页为 false；旧分组卡内可 true。
  final bool showDivider;
  final bool asStandaloneCard;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final enabled = !deviceUnsupported;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: WsSettingsAppTheme.itemMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.4,
              child: item.iconAsset != null
                  ? WsSettingsIcons.image(
                      item.iconAsset!,
                      width: 22,
                      height: 22,
                      fallback: item.icon,
                    )
                  : Icon(
                      item.icon,
                      size: 22,
                      color: WsSettingsAppTheme.title,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.apiCode != null)
                    WsSettingsApiTitle(
                      title: item.title,
                      apiCode: item.apiCode!,
                      style: WsSettingsAppTheme.itemTitle.copyWith(
                        color: enabled
                            ? WsSettingsAppTheme.title
                            : WsSettingsAppTheme.muted,
                      ),
                    )
                  else
                    Text(
                      item.title,
                      style: WsSettingsAppTheme.itemTitle.copyWith(
                        color: enabled
                            ? WsSettingsAppTheme.title
                            : WsSettingsAppTheme.muted,
                      ),
                    ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: WsSettingsAppTheme.itemValue,
                    ),
                  ],
                ],
              ),
            ),
            if (trailingSummary != null) ...[
              Flexible(
                child: Text(
                  trailingSummary!,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: WsSettingsAppTheme.itemValue,
                ),
              ),
              const SizedBox(width: 8),
            ],
            WsSettingsStatusChip(
              item.implStatus,
              deviceUnsupported: deviceUnsupported,
            ),
            const SizedBox(width: 6),
            WsSettingsIcons.image(
              WsSettingsIcons.chevron,
              width: 8,
              height: 14,
            ),
          ],
        ),
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('jw.demo.settings.row.${item.id.name}'),
        onTap: onTap,
        child: row,
      ),
    );

    if (!asStandaloneCard) {
      return Column(
        children: [
          tappable,
          if (showDivider)
            const Divider(
              height: 1,
              indent: 50,
              color: WsSettingsAppTheme.divider,
            ),
        ],
      );
    }

    return WsSettingsItemCard(
      marginTop: marginTop,
      child: tappable,
    );
  }
}

/// 二级页内仍可把相关开关合成一张卡（对齐健康监测 App 布局）。
class WsSettingsCard extends StatelessWidget {
  const WsSettingsCard({
    super.key,
    required this.children,
    this.marginTop = 12,
  });

  final List<Widget> children;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        WsSettingsAppTheme.pagePaddingH,
        marginTop,
        WsSettingsAppTheme.pagePaddingH,
        0,
      ),
      child: Material(
        color: WsSettingsAppTheme.card,
        borderRadius: BorderRadius.circular(WsSettingsAppTheme.itemRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}
