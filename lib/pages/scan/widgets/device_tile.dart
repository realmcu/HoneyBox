import 'package:flutter/material.dart';
import '../../../i18n/app_strings.dart';

/// nRF-Connect-style scan result row: signal strength on the left, device
/// name + address + tags in the middle, and an explicit connect action on the
/// right. Tapping anywhere on the card also connects.
class DeviceTile extends StatelessWidget {
  final String deviceId;
  final String name;
  final int? rssi;
  final bool connectable;
  final Map<int, List<int>> manufacturerData;
  final bool isConnecting;
  final VoidCallback? onConnect;
  final String? actionLabel;

  /// 虚拟调试设备:在标签行额外显示一枚橙色"调试"徽标以示区分。
  final bool debug;

  const DeviceTile({
    super.key,
    required this.deviceId,
    required this.name,
    this.rssi,
    this.connectable = true,
    this.manufacturerData = const {},
    this.isConnecting = false,
    this.onConnect,
    this.actionLabel,
    this.debug = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    // `未知设备` 是数据层的哨兵值(ble_provider 在设备无名时填入),这里翻译它。
    final hasName =
        name.isNotEmpty && name != '未知设备' && name != strings.unknownDevice;
    final canTap = !isConnecting && connectable && onConnect != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: canTap ? onConnect : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              _SignalBars(rssi: rssi, color: cs.primary, muted: cs.outline),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasName ? name : 'N/A',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasName ? cs.onSurface : cs.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deviceId,
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (manufacturerData.isNotEmpty)
                      Text(
                          manufacturerData.entries
                              .map(
                                  (e) => AppStrings.of(context).manufacturerTag(
                                        e.key
                                            .toRadixString(16)
                                            .padLeft(4, '0')
                                            .toUpperCase(),
                                        e.value
                                            .map((b) => b
                                                .toRadixString(16)
                                                .padLeft(2, '0')
                                                .toUpperCase())
                                            .join(':'),
                                      ))
                              .join('\n'),
                          style: tt.bodySmall),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (rssi != null) ...[
                          Text('$rssi dBm', style: tt.labelMedium),
                        ],
                        _Tag(
                          label: connectable
                              ? AppStrings.of(context).tagConnectable
                              : AppStrings.of(context).tagNotConnectable,
                          color: connectable ? cs.secondary : cs.outline,
                        ),
                        if (debug) ...[
                          _Tag(
                            label: AppStrings.of(context).tagDebug,
                            color: const Color(0xFFF57C00), // orange[700]
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: isConnecting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton(
                        onPressed: canTap ? onConnect : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(actionLabel ?? strings.scanConnect),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four ascending bars whose filled count reflects RSSI strength.
class _SignalBars extends StatelessWidget {
  final int? rssi;
  final Color color;
  final Color muted;

  const _SignalBars({
    required this.rssi,
    required this.color,
    required this.muted,
  });

  int get _level {
    final r = rssi;
    if (r == null) return 0;
    if (r >= -60) return 4;
    if (r >= -72) return 3;
    if (r >= -84) return 2;
    if (r >= -96) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    final inactive = muted.withValues(alpha: 0.35);
    return SizedBox(
      width: 30,
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 4.5,
              height: 8.0 + i * 6.0,
              decoration: BoxDecoration(
                color: i < level ? color : inactive,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Small pill-shaped status label.
class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
