import 'dart:async';

import 'package:flutter/material.dart';

import 'jw_demo_controller.dart';
import 'jw_measure_detail_page.dart';
import 'jw_measure_module.dart';

class JWMeasureHubPage extends StatelessWidget {
  const JWMeasureHubPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = controller.state.isReady;

    return Scaffold(
      key: const Key('jw.demo.measure.hub'),
      appBar: AppBar(title: const Text('健康测量')),
      body: !ready
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('请先完成登录或首次绑定。测量 API 只在 ready 会话中可用。'),
            )
          : Builder(
              builder: (context) {
                final modules = JWMeasureModuleKind.visibleModules(controller);
                if (modules.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('当前设备功能列表未包含可演示的测量项。'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: modules.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        '选择指标进入详情：自动监测与点测分开展示。',
                        style: theme.textTheme.bodyMedium,
                      );
                    }
                    final kind = modules[index - 1];
                    return Card(
                      child: ListTile(
                        key: kind.hubTileKey,
                        leading: CircleAvatar(
                          backgroundColor:
                              kind.accentColor(theme.colorScheme).withValues(alpha: 0.15),
                          foregroundColor: kind.accentColor(theme.colorScheme),
                          child: Icon(kind.icon),
                        ),
                        title: Text(kind.title),
                        subtitle: Text(jwMeasureModuleSubtitle(kind, controller)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          unawaited(
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => JWMeasureDetailPage(
                                  controller: controller,
                                  kind: kind,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
