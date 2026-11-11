import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

import 'ws_demo_controller.dart';
import 'ws_settings_api_sheet.dart';
import 'ws_settings_app_widgets.dart';
import 'ws_settings_app_theme.dart';
import 'compat/ws_demo_compat.dart';

/// 对齐 App `NotifyRemindSettingActivity`：开关列表 + 全部开启/关闭；
/// Demo 额外提供发送测试消息入口（不申请通知栏权限）。
class WsNotifyRemindPage extends StatefulWidget {
  const WsNotifyRemindPage({super.key, required this.controller});

  final WSDemoController controller;

  @override
  State<WsNotifyRemindPage> createState() => _JwNotifyRemindPageState();
}

class _JwNotifyRemindPageState extends State<WsNotifyRemindPage> {
  WSNotifySettings? _settings;
  bool _busy = false;
  Object? _error;
  String? _result;

  WSNotifyChannel _sendChannel = WSNotifyChannel.wechat;
  final _sendText = TextEditingController(text: 'Demo 测试消息');

  static const _channels = <(WSNotifyChannel, String)>[
    (WSNotifyChannel.call, '来电'),
    (WSNotifyChannel.sms, '短信'),
    (WSNotifyChannel.wechat, '微信'),
    (WSNotifyChannel.qq, 'QQ'),
    (WSNotifyChannel.facebook, 'Facebook'),
    (WSNotifyChannel.twitter, 'Twitter'),
    (WSNotifyChannel.linkedin, 'LinkedIn'),
    (WSNotifyChannel.whatsapp, 'WhatsApp'),
    (WSNotifyChannel.instagram, 'Instagram'),
    (WSNotifyChannel.skype, 'Skype'),
    (WSNotifyChannel.gmail, 'Gmail'),
    (WSNotifyChannel.line, 'Line'),
    (WSNotifyChannel.viber, 'Viber'),
    (WSNotifyChannel.messenger, 'Messenger'),
    (WSNotifyChannel.kakaotalk, 'KakaoTalk'),
    (WSNotifyChannel.vkontakte, 'VKontakte'),
    (WSNotifyChannel.tim, 'TIM'),
    (WSNotifyChannel.dingtalk, '钉钉'),
    (WSNotifyChannel.workWechat, '企业微信'),
    (WSNotifyChannel.other, '其他应用'),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _sendText.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() op) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read() => _run(() async {
        final settings = await widget.controller.readNotifySettings();
        if (!mounted) return;
        setState(() {
          _settings = settings;
          _result = '已读取消息提醒开关。';
        });
      });

  Future<void> _setChannel(WSNotifyChannel channel, bool enabled) async {
    final current = _settings;
    if (_busy || current == null) return;
    // 先本地翻这一项，避免 busy 时把所有 Switch 切成 disabled 引发整屏抖动。
    setState(() => _settings = current.withChannel(channel, enabled));
    await _run(() async {
      try {
        final verified =
            await widget.controller.setNotifyChannel(channel, enabled);
        if (!mounted) return;
        setState(() {
          _settings = verified.value;
          _result = '${_labelOf(channel)} 已${enabled ? '开启' : '关闭'}。';
        });
      } catch (_) {
        if (mounted) setState(() => _settings = current);
        rethrow;
      }
    });
  }

  Future<void> _setAll(bool enabled) async {
    final current = _settings;
    if (_busy || current == null) return;
    setState(() => _settings = WSNotifySettings.all(enabled));
    await _run(() async {
      try {
        final verified = await widget.controller
            .setNotifySettings(WSNotifySettings.all(enabled));
        if (!mounted) return;
        setState(() {
          _settings = verified.value;
          _result = enabled ? '已全部开启。' : '已全部关闭。';
        });
      } catch (_) {
        if (mounted) setState(() => _settings = current);
        rethrow;
      }
    });
  }

  Future<void> _sendTest() => _run(() async {
        final text = _sendText.text.trim();
        if (_sendChannel == WSNotifyChannel.call) {
          await widget.controller.sendIncomingCall(display: text);
        } else {
          await widget.controller
              .sendNotifyMessage(_sendChannel, text: text);
        }
        if (!mounted) return;
        setState(() => _result = '已发送 ${_labelOf(_sendChannel)} 测试提醒。');
      });

  String _labelOf(WSNotifyChannel channel) {
    for (final entry in _channels) {
      if (entry.$1 == channel) return entry.$2;
    }
    return channel.name;
  }

  bool get _allClosed {
    final settings = _settings;
    if (settings == null) return true;
    return WSNotifyChannel.values.every((c) => !settings[c]);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Theme(
      data: WsSettingsAppTheme.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: WsSettingsAppTheme.background,
        appBar: AppBar(
          title: const Text('消息提醒'),
          actions: [
            IconButton(
              key: const Key('jw.demo.settings.notify.api'),
              tooltip: '公开 API',
              onPressed: () => unawaited(
                WsSettingsApiTitle.show(
                  context,
                  title: '消息提醒',
                  apiCode: WsSettingsApiExamples.notifyRemind,
                ),
              ),
              icon: const Icon(Icons.code),
            ),
            IconButton(
              onPressed: _busy ? null : _read,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                WsSettingsAppTheme.pagePaddingH + 5,
                0,
                WsSettingsAppTheme.pagePaddingH,
                8,
              ),
              child: Text('发送测试', style: WsSettingsAppTheme.sectionTitle),
            ),
            WsSettingsCard(
              marginTop: 0,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '直接向设备发送一条提醒，用于验证开关与展示效果。',
                        style: TextStyle(
                          fontSize: 13,
                          color: WsSettingsAppTheme.subtitle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<WSNotifyChannel>(
                        key: const Key('jw.demo.settings.notify.send_channel'),
                        initialValue: _sendChannel,
                        decoration: const InputDecoration(
                          labelText: '平台',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final entry in _channels)
                            DropdownMenuItem(
                              value: entry.$1,
                              child: Text(entry.$2),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _sendChannel = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('jw.demo.settings.notify.send_text'),
                        controller: _sendText,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: '内容（可选）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('jw.demo.settings.notify.send'),
                        onPressed: _busy ? null : _sendTest,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(_busy ? '发送中…' : '发送测试消息'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: WsSettingsAppTheme.pagePaddingH,
                ),
                child: LinearProgressIndicator(),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: WsSettingsAppTheme.pagePaddingH,
                ),
                child: Text(
                  _result!,
                  style: const TextStyle(color: WsSettingsAppTheme.subtitle),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: WsSettingsAppTheme.pagePaddingH,
                ),
                child: Text(
                  describeWSDemoError(_error!),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WsSettingsAppTheme.pagePaddingH,
              ),
              child: Material(
                color: WsSettingsAppTheme.card,
                borderRadius:
                    BorderRadius.circular(WsSettingsAppTheme.itemRadius),
                child: InkWell(
                  key: const Key('jw.demo.settings.notify.toggle_all'),
                  borderRadius:
                      BorderRadius.circular(WsSettingsAppTheme.itemRadius),
                  onTap: (_busy || settings == null)
                      ? null
                      : () => _setAll(_allClosed),
                  child: SizedBox(
                    height: 54,
                    child: Center(
                      child: Text(
                        _allClosed ? '全部开启' : '全部关闭',
                        style: const TextStyle(
                          fontSize: 17,
                          color: WsSettingsAppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            WsSettingsCard(
              marginTop: 14,
              children: [
                for (var i = 0; i < _channels.length; i++) ...[
                  _NotifySwitchRow(
                    key: Key('jw.demo.settings.notify.${_channels[i].$1.name}'),
                    title: _channels[i].$2,
                    value: settings?[_channels[i].$1] ?? false,
                    showDivider: i != _channels.length - 1,
                    // 始终保持 onChanged 非 null，避免整表 Switch 因 disabled
                    // 样式切换而抖动；忙时在回调内直接忽略。
                    onChanged: settings == null
                        ? null
                        : (value) => _setChannel(_channels[i].$1, value),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifySwitchRow extends StatelessWidget {
  const _NotifySwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.showDivider,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: WsSettingsAppTheme.itemMinHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: WsSettingsAppTheme.itemTitle),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            color: WsSettingsAppTheme.divider,
          ),
      ],
    );
  }
}
