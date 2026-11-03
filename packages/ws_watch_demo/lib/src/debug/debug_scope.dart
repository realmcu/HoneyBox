import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import '../demo_raw_sheet.dart';
import 'debug_capture.dart';

/// Each route borrows the same capture when it borrows the same watch.
class DemoDebugScope extends StatefulWidget {
  const DemoDebugScope(
      {super.key,
      required this.watch,
      required this.child,
      this.showButton = true});
  final WSWatch watch;
  final Widget child;
  final bool showButton;
  static final _leases = Expando<_CaptureLease>();
  static DemoDebugCapture of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DebugContext>()!.capture;
  static Future<T> runAction<T>(
          WSWatch watch, String label, Future<T> Function() action) =>
      _leases[watch]!.capture.run(label, action);
  @override
  State<DemoDebugScope> createState() => _DemoDebugScopeState();
}

class _CaptureLease {
  _CaptureLease(this.capture);
  final DemoDebugCapture capture;
  int references = 0;
}

class _DemoDebugScopeState extends State<DemoDebugScope> {
  late _CaptureLease _lease;
  void _acquire() {
    _lease = DemoDebugScope._leases[widget.watch] ??
        _CaptureLease(DemoDebugCapture(widget.watch));
    DemoDebugScope._leases[widget.watch] = _lease;
    _lease.references++;
  }

  void _release(WSWatch watch) {
    if (--_lease.references == 0) {
      DemoDebugScope._leases[watch] = null;
      _lease.capture.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void didUpdateWidget(DemoDebugScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watch != widget.watch) {
      _release(oldWidget.watch);
      _acquire();
    }
  }

  @override
  void dispose() {
    _release(widget.watch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DebugContext(
      capture: _lease.capture,
      child: Stack(children: [
        widget.child,
        if (widget.showButton)
          Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Raw 调试',
                    key: const Key('ws-debug-tools'),
                    onPressed: () => showDemoRawDebugSheet(
                          context,
                          watch: widget.watch,
                          capture: _lease.capture,
                        ),
                    child: const Icon(Icons.bug_report_outlined)),
              )),
      ]));
}

class _DebugContext extends InheritedWidget {
  const _DebugContext({required this.capture, required super.child});
  final DemoDebugCapture capture;
  @override
  bool updateShouldNotify(_DebugContext oldWidget) =>
      oldWidget.capture != capture;
}

/// Shared scaffold keeps the capture alive while a tool route is on top.
class DemoDebugScaffold extends StatelessWidget {
  const DemoDebugScaffold(
      {super.key, required this.watch, this.appBar, this.body});
  final WSWatch watch;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  @override
  Widget build(BuildContext context) =>
      DemoDebugScope(watch: watch, child: Scaffold(appBar: appBar, body: body));
}

/// Common result card for feature calls made through runAction.
class DemoActionCard extends StatelessWidget {
  const DemoActionCard({super.key});
  @override
  Widget build(BuildContext context) {
    final capture = DemoDebugScope.of(context);
    return AnimatedBuilder(
        animation: capture,
        builder: (_, __) {
          if (capture.actions.isEmpty) return const SizedBox.shrink();
          final result = capture.actions.first;
          return Card(
              child: ExpansionTile(
                  title: Text(
                      '${result.label} · ${result.error == null ? '成功' : '失败'} · ${result.elapsed.inMilliseconds} ms'),
                  subtitle: Text('trace=${result.traceId}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                        'trace=${result.traceId}\n返回：${result.value ?? 'void'}\n错误：${result.error ?? '无'}'))
              ]));
        });
  }
}
