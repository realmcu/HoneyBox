import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  final String deviceId;
  final String name;
  final int? rssi;
  final bool isConnecting;
  final VoidCallback? onTap;

  const DeviceTile({
    super.key,
    required this.deviceId,
    required this.name,
    this.rssi,
    this.isConnecting = false,
    this.onTap,
  });

  String _shortId(String id) =>
      id.length > 8 ? id.substring(id.length - 8) : id;

  IconData _rssiIcon(int rssi) {
    if (rssi >= -50) return Icons.wifi;
    if (rssi >= -70) return Icons.wifi;
    if (rssi >= -85) return Icons.wifi;
    return Icons.wifi_find;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isConnecting ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: isConnecting
                  ? Border.all(color: cs.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                // icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.smartphone, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                // info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : '未知设备',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shortId(deviceId),
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isConnecting)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  if (rssi != null) ...[
                    Icon(_rssiIcon(rssi!), size: 18, color: cs.outline),
                    const SizedBox(width: 4),
                    Text('$rssi', style: tt.bodySmall),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: cs.outline),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
