import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jw_watch_demo/jw_watch_demo.dart';
import 'package:ws_watch_demo/ws_watch_demo.dart' as ws_demo;

/// SDK Demo 二级页：双列平台卡片进入 JW / WS 全屏 Demo。
class SdkDemoHubPage extends StatelessWidget {
  const SdkDemoHubPage({super.key});

  static const _jwCard = Color(0xFF5C4DBF);
  static const _wsCard = Color(0xFF1A8A9B);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK Demo'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                    maxWidth: 340,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PlatformSdkTile(
                                key: const Key('sdk_demo.jw_card'),
                                background: _jwCard,
                                glyph: const _JwSdkGlyph(),
                                label: 'JW SDK',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    settings: const RouteSettings(
                                      name: '/watch-lab-jw',
                                    ),
                                    builder: (_) => const JWWatchLabAppRoot(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _PlatformSdkTile(
                                key: const Key('sdk_demo.ws_card'),
                                background: _wsCard,
                                glyph: const _WsSdkGlyph(),
                                label: 'WS SDK',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    settings: const RouteSettings(
                                      name: '/watch-lab-ws',
                                    ),
                                    builder: (_) =>
                                        const ws_demo.WSWatchLabAppRoot(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _PlatformSdkTile extends StatelessWidget {
  const _PlatformSdkTile({
    super.key,
    required this.background,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final Color background;
  final Widget glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Center(child: glyph),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 表盘轮廓 + J，避免通用 Material 手表图标。
final class _JwSdkGlyph extends StatelessWidget {
  const _JwSdkGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            child: Container(
              width: 10,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'J',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5C4DBF),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 六边形节点 + W，表示 Honey / 链路协议栈。
final class _WsSdkGlyph extends StatelessWidget {
  const _WsSdkGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _HexBadgePainter(),
        child: const Center(
          child: Text(
            'W',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A8A9B),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

final class _HexBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide * 0.42;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = (60 * i - 30) * math.pi / 180;
      final x = cx + r * 1.08 * math.cos(a);
      final y = cy + r * 1.08 * math.sin(a);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();
    canvas.drawPath(
      hex,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      hex,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
