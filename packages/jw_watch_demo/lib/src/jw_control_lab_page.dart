import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_settings_api_sheet.dart';

void openJwControlLab(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JwControlLabPage(controller: controller),
      ),
    ),
  );
}

/// 演示 `session.control`：查找手机反馈、音乐事件日志、状态下发与天气推送。
class JwControlLabPage extends StatefulWidget {
  const JwControlLabPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwControlLabPage> createState() => _JwControlLabPageState();
}

class _JwControlLabPageState extends State<JwControlLabPage>
    implements JWControlListener {
  static const _musicLabels = [
    '播放',
    '暂停',
    '播放/暂停',
    '下一首',
    '上一首',
    '音量+',
    '音量-',
  ];

  final _events = <_ControlEvent>[];
  Timer? _findPhonePulse;
  bool _findPhoneActive = false;
  bool _publishingWeather = false;
  bool _syncingMusic = false;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.session;
    session?.control.addControlListener(this);
  }

  @override
  void dispose() {
    _stopFindPhoneFeedback();
    widget.controller.session?.control.removeControlListener(this);
    super.dispose();
  }

  void _append(String kind, String detail) {
    if (!mounted) return;
    setState(() {
      _events.insert(
        0,
        _ControlEvent(
          time: DateTime.now(),
          kind: kind,
          detail: detail,
        ),
      );
      if (_events.length > 24) _events.removeLast();
    });
  }

  void _stopFindPhoneFeedback() {
    _findPhonePulse?.cancel();
    _findPhonePulse = null;
  }

  void _startFindPhoneFeedback() {
    _stopFindPhoneFeedback();
    unawaited(SystemSound.play(SystemSoundType.alert));
    _findPhonePulse = Timer.periodic(const Duration(milliseconds: 900), (_) {
      unawaited(HapticFeedback.heavyImpact());
    });
  }

  @override
  void onFindPhone({required bool enable}) {
    _append('查找手机', enable ? '开启（表端请求响铃）' : '关闭');
    setState(() => _findPhoneActive = enable);
    if (enable) {
      _startFindPhoneFeedback();
    } else {
      _stopFindPhoneFeedback();
    }
  }

  @override
  void onMusicControl(int control) {
    final label =
        control >= 0 && control < _musicLabels.length ? _musicLabels[control] : '未知($control)';
    _append('音乐控制', '$control · $label');
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  void onTakePhoto() {
    _append('拍照手势', 'onTakePhoto（请在「摇摇拍照」页验证快门流程）');
  }

  Future<void> _pushSampleWeather() async {
    if (_publishingWeather) return;
    final session = widget.controller.session;
    if (session == null || !widget.controller.state.isReady) return;
    setState(() => _publishingWeather = true);
    final now = DateTime.now();
    final info = JWWeatherInfo(
      enable: true,
      year: now.year,
      month: now.month,
      day: now.day,
      city: '深圳',
      currentWeather: const JWCurrentWeather(
        weatherCode: JWWeatherInfo.weatherCodeSunny,
        temperature: 26,
        maxTemperature: 32,
        minTemperature: 20,
        humidity: 55,
        ultravioletIntensity: 3,
        pollutionIndex: 2,
      ),
      nextOneDayWeather: const JWFutureWeather(
        weatherCode: JWWeatherInfo.weatherCodeCloudy,
        maxTemperature: 30,
        minTemperature: 22,
      ),
    );
    try {
      await session.control.setWeather(info);
      if (!mounted) return;
      _append('天气下发', '已发送示例（深圳 · 晴）');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('天气参数已下发')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _publishingWeather = false);
    }
  }

  Future<void> _syncSampleMusicStatus() async {
    if (_syncingMusic) return;
    final session = widget.controller.session;
    if (session == null || !widget.controller.state.isReady) return;
    setState(() => _syncingMusic = true);
    try {
      await session.control.setMusicStatus(
        const JWMusicStatusInfo(
          hasPlayer: true,
          playing: true,
          volumePercent: 12,
        ),
      );
      if (!mounted) return;
      _append('音乐状态', '已同步 playing=true, volume=12');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音乐状态已同步到手表')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _syncingMusic = false);
    }
  }

  void _showApi(String title, String code) {
    unawaited(JwSettingsApiTitle.show(context, title: title, apiCode: code));
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final ready = widget.controller.state.isReady;
    return Scaffold(
      key: const Key('jw.demo.control.lab'),
      appBar: AppBar(
        title: const Text('设备控制'),
        actions: [
          IconButton(
            key: const Key('jw.demo.control.lab.api'),
            tooltip: '公开 API',
            onPressed: () => _showApi('设备控制', JwSettingsApiExamples.controlLab),
            icon: const Icon(Icons.code),
          ),
        ],
      ),
      body: !ready
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('请先完成连接与登录。'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  '本页常驻监听 cmd 0x07 入站事件；表端操作会记入下方日志。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _StatusBanner(
                  findPhoneActive: _findPhoneActive,
                  listening: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('jw.demo.control.lab.weather'),
                        onPressed: _publishingWeather ? null : _pushSampleWeather,
                        icon: _publishingWeather
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_outlined),
                        label: const Text('推送示例天气'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('jw.demo.control.lab.music_status'),
                        onPressed: _syncingMusic ? null : _syncSampleMusicStatus,
                        icon: const Icon(Icons.queue_music_outlined),
                        label: const Text('同步音乐状态'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '查找手机：表端触发后本机振动+提示音（2.0 可发关闭停止）；'
                  '音乐：在表上按播/切歌键；拍照请进设置「摇摇拍照」。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text('事件日志', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('等待设备事件…')),
                  )
                else
                  for (final event in _events)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(event.kind),
                        subtitle: Text(event.detail),
                        trailing: Text(
                          _formatTime(event.time),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

final class _ControlEvent {
  const _ControlEvent({
    required this.time,
    required this.kind,
    required this.detail,
  });

  final DateTime time;
  final String kind;
  final String detail;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.findPhoneActive,
    required this.listening,
  });

  final bool findPhoneActive;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = findPhoneActive ? Colors.orange.shade800 : theme.colorScheme.primary;
    final text = findPhoneActive
        ? '查找手机进行中（振动+提示音）'
        : listening
            ? '控制监听已开启'
            : '未监听';
    return Container(
      key: const Key('jw.demo.control.lab.status'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            findPhoneActive ? Icons.notifications_active : Icons.sensors,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
