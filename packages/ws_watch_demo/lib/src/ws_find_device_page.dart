import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'ws_demo_controller.dart';
import 'ws_settings_api_sheet.dart';
import 'ws_settings_app_theme.dart';

/// 对齐 App `FindDeviceActivity` + `FindDeviceView`：居中水波纹，点击启停。
class WsFindDevicePage extends StatefulWidget {
  const WsFindDevicePage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsFindDevicePage> createState() => _JwFindDevicePageState();
}

class _JwFindDevicePageState extends State<WsFindDevicePage> {
  static const _firstDelay = Duration(seconds: 1);
  static const _autoStop = Duration(seconds: 4);

  bool _finding = false;
  bool _busy = false;
  Timer? _firstStartTimer;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    // App：进入后延迟 1s 自动开始查找。
    _firstStartTimer = Timer(_firstDelay, () {
      if (mounted && !_finding) unawaited(_start());
    });
  }

  @override
  void dispose() {
    _firstStartTimer?.cancel();
    _autoStopTimer?.cancel();
    if (_finding) {
      unawaited(
        widget.controller.findDevice(false).then<void>(
              (_) {},
              onError: (_) {},
            ),
      );
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _firstStartTimer?.cancel();
    if (_finding) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_busy || _finding) return;
    setState(() => _busy = true);
    try {
      await widget.controller.findDevice(true);
      if (!mounted) return;
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(_autoStop, () {
        unawaited(_stop());
      });
      setState(() => _finding = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!_finding) return;
    setState(() => _busy = true);
    try {
      await widget.controller.findDevice(false);
      if (!mounted) return;
      setState(() => _finding = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeWSDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showApi() {
    unawaited(
      WsSettingsApiTitle.show(
        context,
        title: '查找设备',
        apiCode: WsSettingsApiExamples.findDevice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: WsSettingsAppTheme.background,
        appBar: AppBar(
          title: const Text('查找设备'),
          actions: [
            IconButton(
              key: const Key('jw.demo.settings.find_device.api'),
              tooltip: '公开 API',
              onPressed: _showApi,
              icon: const Icon(Icons.code),
            ),
          ],
        ),
        body: Center(
          child: _FindDeviceRipple(
            key: const Key('jw.demo.settings.find_device.toggle'),
            animating: _finding,
            color: WsSettingsAppTheme.findDeviceRipple,
            onTap: _busy ? null : _toggle,
            child: WsSettingsIcons.image(
              WsSettingsIcons.findBand,
              width: 54,
              height: 80,
              fallback: Icons.watch,
            ),
          ),
        ),
      ),
    );
  }
}

/// 对齐 App `FindDeviceView`：静止 4 环；查找中每 500ms 扩散一圈，2s 淡出。
class _FindDeviceRipple extends StatefulWidget {
  const _FindDeviceRipple({
    super.key,
    required this.animating,
    required this.color,
    required this.child,
    this.onTap,
  });

  final bool animating;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_FindDeviceRipple> createState() => _FindDeviceRippleState();
}

class _FindDeviceRippleState extends State<_FindDeviceRipple>
    with SingleTickerProviderStateMixin {
  static const _size = 309.0;
  static const _minDiameter = 120.0;
  static const _durationMs = 2000;
  static const _spawnMs = 500;

  late final Ticker _ticker;
  final _circles = <_RippleCircle>[];
  Duration _elapsed = Duration.zero;
  Duration? _lastSpawn;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.animating) _startTicker();
  }

  @override
  void didUpdateWidget(covariant _FindDeviceRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating == oldWidget.animating) return;
    if (widget.animating) {
      _startTicker();
    } else {
      _ticker.stop();
      _circles.clear();
      _lastSpawn = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startTicker() {
    _circles.clear();
    _elapsed = Duration.zero;
    _lastSpawn = null;
    _ticker.start();
    _spawn();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final last = _lastSpawn;
    if (last == null ||
        elapsed.inMilliseconds - last.inMilliseconds >= _spawnMs) {
      _spawn();
    }
    _circles.removeWhere(
      (c) => elapsed.inMilliseconds - c.bornMs >= _durationMs,
    );
    setState(() {});
  }

  void _spawn() {
    _lastSpawn = _elapsed;
    _circles.add(_RippleCircle(bornMs: _elapsed.inMilliseconds));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _FindDeviceRipplePainter(
            animating: widget.animating,
            color: widget.color,
            nowMs: _elapsed.inMilliseconds,
            circles: List<_RippleCircle>.unmodifiable(_circles),
            minRadius: _minDiameter / 2,
            maxRadius: _size / 2,
            durationMs: _durationMs,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

final class _RippleCircle {
  const _RippleCircle({required this.bornMs});
  final int bornMs;
}

final class _FindDeviceRipplePainter extends CustomPainter {
  _FindDeviceRipplePainter({
    required this.animating,
    required this.color,
    required this.nowMs,
    required this.circles,
    required this.minRadius,
    required this.maxRadius,
    required this.durationMs,
  });

  final bool animating;
  final Color color;
  final int nowMs;
  final List<_RippleCircle> circles;
  final double minRadius;
  final double maxRadius;
  final int durationMs;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    paint.color = color;
    canvas.drawCircle(center, minRadius, paint);

    if (animating) {
      for (final circle in circles) {
        final percent =
            ((nowMs - circle.bornMs) / durationMs).clamp(0.0, 1.0);
        final radius = minRadius + percent * (maxRadius - minRadius);
        final alpha = ((1.0 - percent) * 0.5 * 255).round().clamp(0, 255);
        paint.color = color.withAlpha(alpha);
        canvas.drawCircle(center, radius, paint);
      }
      return;
    }

    for (var i = 0; i < 4; i++) {
      final alpha = ((0.5 - i * 0.1) * 255).round().clamp(0, 255);
      final radius = minRadius + (maxRadius - minRadius) * (i * 0.25);
      paint.color = color.withAlpha(alpha);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FindDeviceRipplePainter oldDelegate) =>
      animating != oldDelegate.animating ||
      color != oldDelegate.color ||
      nowMs != oldDelegate.nowMs ||
      circles.length != oldDelegate.circles.length ||
      !identical(circles, oldDelegate.circles);
}
