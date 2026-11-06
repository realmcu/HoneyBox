import 'package:flutter/material.dart';

import '../../services/ota/ota_target.dart';
import 'watch_ota_root.dart';

class OtaChipPage extends StatelessWidget {
  const OtaChipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择芯片类型')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('RTL8773G'),
            subtitle: const Text('eBadge / Watch 普通 OTA'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WatchOtaRoot(target: OtaTarget.rtl87x3g),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('RTL8762D'),
            subtitle: const Text('Realtek 蓝牙固件升级'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WatchOtaRoot()),
            ),
          ),
        ],
      ),
    );
  }
}
