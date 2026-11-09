import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_theme.dart';

/// 对齐 App `TakePhotoActivity`：进入页后开启 `setTakePhotoControl`，
/// 收到表端手势时回调 [JWControlListener.onTakePhoto]（Demo 用计数 + 提示；预览快门由 App 接相机）。
class JwTakePhotoPage extends StatefulWidget {
  const JwTakePhotoPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwTakePhotoPage> createState() => _JwTakePhotoPageState();
}

class _JwTakePhotoPageState extends State<JwTakePhotoPage>
    implements JWControlListener {
  bool _enabling = false;
  bool _controlEnabled = false;
  int _triggerCount = 0;
  final _events = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_enableControl()));
  }

  @override
  void dispose() {
    final session = widget.controller.session;
    session?.control.removeControlListener(this);
    if (_controlEnabled && session != null) {
      unawaited(
        session.control.setTakePhotoControl(false).then<void>(
              (_) {},
              onError: (_) {},
            ),
      );
    }
    super.dispose();
  }

  Future<void> _enableControl() async {
    if (_enabling || _controlEnabled) return;
    final session = widget.controller.session;
    if (session == null || !widget.controller.state.isReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接设备并完成登录。')),
      );
      return;
    }
    setState(() => _enabling = true);
    try {
      session.control.addControlListener(this);
      await session.control.setTakePhotoControl(true);
      if (!mounted) return;
      setState(() => _controlEnabled = true);
    } catch (e) {
      session.control.removeControlListener(this);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  void _showApi() {
    unawaited(
      JwSettingsApiTitle.show(
        context,
        title: '摇摇拍照',
        apiCode: JwSettingsApiExamples.takePhoto,
      ),
    );
  }

  @override
  void onTakePhoto() {
    if (!mounted) return;
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _triggerCount++;
      _events.insert(0, '$stamp  收到表端手势');
      if (_events.length > 8) _events.removeLast();
    });
    unawaited(HapticFeedback.mediumImpact());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('收到拍照手势；正式 App 在此触发快门。'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void onFindPhone({required bool enable}) {}

  @override
  void onMusicControl(int control) {}

  @override
  Widget build(BuildContext context) {
    final ready = widget.controller.state.isReady;
    return Theme(
      data: JwSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
        key: const Key('jw.demo.settings.take_photo.page'),
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('摇摇拍照'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              key: const Key('jw.demo.settings.take_photo.api'),
              tooltip: '公开 API',
              onPressed: _showApi,
              icon: const Icon(Icons.code),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _controlEnabled ? 1 : 0.45,
                      child: JwSettingsIcons.image(
                        JwSettingsIcons.takePhoto,
                        width: 72,
                        height: 72,
                        fallback: Icons.camera_alt_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _controlEnabled
                          ? '遥控已开启，请在手表上转腕触发'
                          : ready
                              ? (_enabling ? '正在开启遥控…' : '等待开启遥控')
                              : '未连接设备',
                      key: const Key('jw.demo.settings.take_photo.status'),
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '触发次数：$_triggerCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_events.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.08),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '最近事件',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    for (final line in _events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
