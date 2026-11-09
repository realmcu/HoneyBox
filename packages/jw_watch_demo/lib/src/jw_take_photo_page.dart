import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_theme.dart';

/// 对齐 App `TakePhotoActivity`：进入页即 `setTakePhotoControl(true)`，
/// 表端转腕或按键触发 [JWControlListener.onTakePhoto]；离开页关闭遥控。
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
  bool _listenerAttached = false;
  bool _leaving = false;
  int _triggerCount = 0;
  Future<void>? _teardown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    unawaited(_enableControl());
  }

  void _onControllerChanged() {
    if (_leaving || _controlEnabled || _enabling) return;
    if (widget.controller.state.isReady) {
      unawaited(_enableControl());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    if (!_leaving) {
      unawaited(_ensureTeardown());
    }
    super.dispose();
  }

  Future<void> _ensureTeardown() {
    return _teardown ??= _runTeardown();
  }

  Future<void> _runTeardown() async {
    final session = widget.controller.session;
    if (_listenerAttached && session != null) {
      session.control.removeControlListener(this);
      _listenerAttached = false;
    }
    if (!_controlEnabled || session == null) return;
    _controlEnabled = false;
    try {
      await session.control.setTakePhotoControl(false);
    } catch (_) {}
  }

  void _detachListener() {
    final session = widget.controller.session;
    if (_listenerAttached && session != null) {
      session.control.removeControlListener(this);
      _listenerAttached = false;
    }
  }

  Future<void> _enableControl() async {
    if (_leaving || _enabling || _controlEnabled) return;
    final session = widget.controller.session;
    if (session == null || !widget.controller.state.isReady) return;

    setState(() => _enabling = true);
    try {
      session.control.addControlListener(this);
      _listenerAttached = true;
      await session.control.setTakePhotoControl(true);
      if (!mounted || _leaving) return;
      setState(() => _controlEnabled = true);
    } catch (e) {
      _detachListener();
      if (!mounted || _leaving) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted && !_leaving) setState(() => _enabling = false);
    }
  }

  void _leavePage() {
    if (_leaving) return;
    _leaving = true;
    _detachListener();
    if (mounted) {
      Navigator.of(context).pop();
    }
    unawaited(_ensureTeardown());
  }

  void _showApi() {
    unawaited(
      JwSettingsApiTitle.show(
        context,
        title: '遥控拍照',
        apiCode: JwSettingsApiExamples.takePhoto,
      ),
    );
  }

  @override
  void onTakePhoto() {
    if (!mounted || _leaving) return;
    setState(() => _triggerCount++);
    unawaited(HapticFeedback.mediumImpact());
  }

  @override
  void onFindPhone({required bool enable}) {}

  @override
  void onMusicControl(int control) {}

  @override
  Widget build(BuildContext context) {
    final ready = widget.controller.state.isReady;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leavePage();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
        child: Scaffold(
          key: const Key('jw.demo.settings.take_photo.page'),
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('遥控拍照'),
            leading: IconButton(
              key: const Key('jw.demo.settings.take_photo.back'),
              tooltip: '返回',
              onPressed: _leavePage,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            actions: [
              IconButton(
                key: const Key('jw.demo.settings.take_photo.api'),
                tooltip: '公开 API',
                onPressed: _showApi,
                icon: const Icon(Icons.code, color: Colors.white),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        ? '遥控已开启：转腕或点按手表拍照入口'
                        : ready
                            ? (_enabling ? '正在开启遥控…' : '等待开启遥控')
                            : '未连接设备',
                    key: const Key('jw.demo.settings.take_photo.status'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
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
        ),
      ),
    );
  }
}
