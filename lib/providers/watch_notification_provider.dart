import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationGroup { essential, social, work, other, extra }
enum NotificationPrivacy { appOnly, titleAndContact, fullContent }

class NotificationSource {
  final String id;
  final String name;
  final String icon;
  final int color;
  final String subtitle;
  final NotificationGroup group;
  final bool enabled;

  const NotificationSource({
    required this.id, required this.name, required this.icon,
    required this.color, required this.subtitle, required this.group,
    this.enabled = true,
  });

  NotificationSource copyWith({bool? enabled}) => NotificationSource(
        id: id, name: name, icon: icon, color: color,
        subtitle: subtitle, group: group,
        enabled: enabled ?? this.enabled,
      );
}

class CapturedNotification {
  final String appName;
  final String title;
  final String message;
  final DateTime timestamp;

  const CapturedNotification({
    required this.appName, required this.title,
    required this.message, required this.timestamp,
  });
}

class WatchNotificationState {
  final List<NotificationSource> sources;
  final bool masterEnabled;
  final bool permissionGranted;
  final NotificationPrivacy privacy;
  final bool quietEnabled;
  final TimeOfDay quietStart;
  final TimeOfDay quietEnd;
  final CapturedNotification? lastNotification;
  final bool isInQuietPeriod;

  const WatchNotificationState({
    required this.sources,
    required this.masterEnabled,
    required this.permissionGranted,
    required this.privacy,
    required this.quietEnabled,
    required this.quietStart,
    required this.quietEnd,
    this.lastNotification,
    required this.isInQuietPeriod,
  });

  WatchNotificationState copyWith({
    List<NotificationSource>? sources,
    bool? masterEnabled, bool? permissionGranted,
    NotificationPrivacy? privacy,
    bool? quietEnabled,
    TimeOfDay? quietStart, TimeOfDay? quietEnd,
    CapturedNotification? lastNotification,
    bool? isInQuietPeriod,
  }) =>
      WatchNotificationState(
        sources: sources ?? this.sources,
        masterEnabled: masterEnabled ?? this.masterEnabled,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        privacy: privacy ?? this.privacy,
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        lastNotification: lastNotification ?? this.lastNotification,
        isInQuietPeriod: isInQuietPeriod ?? this.isInQuietPeriod,
      );
}

const List<NotificationSource> kDefaultSources = [
  NotificationSource(id: 'call', group: NotificationGroup.essential,
    name: '\u6765\u7535', icon: '\u{1F4DE}', color: 0xFF23845B,
    subtitle: '\u663E\u793A\u8054\u7CFB\u4EBA\u6216\u7535\u8BDD\u53F7\u7801', enabled: true),
  NotificationSource(id: 'missed', group: NotificationGroup.essential,
    name: '\u672A\u63A5\u6765\u7535', icon: '\u{1F4F0}', color: 0xFFD45445,
    subtitle: '\u901A\u8BDD\u7ED3\u675F\u540E\u63D0\u9192', enabled: true),
  NotificationSource(id: 'sms', group: NotificationGroup.essential,
    name: '\u77ED\u4FE1', icon: '\u{1F4AC}', color: 0xFF2D8B57,
    subtitle: '\u8054\u7CFB\u4EBA\u3001\u6807\u9898\u4E0E\u5185\u5BB9', enabled: true),
  NotificationSource(id: 'wechat', group: NotificationGroup.social,
    name: '\u5FAE\u4FE1', icon: '\u5FAE', color: 0xFF27A844,
    subtitle: '\u804A\u5929\u4E0E\u7FA4\u6D88\u606F', enabled: true),
  NotificationSource(id: 'qq', group: NotificationGroup.social,
    name: 'QQ', icon: 'Q', color: 0xFF178BD1,
    subtitle: '\u597D\u53CB\u4E0E\u7FA4\u6D88\u606F', enabled: false),
  NotificationSource(id: 'feishu', group: NotificationGroup.work,
    name: '\u98DE\u4E66', icon: '\u98DE', color: 0xFF3370FF,
    subtitle: '\u6D88\u606F\u3001\u4F1A\u8BAE\u4E0E\u65E5\u7A0B', enabled: true),
  NotificationSource(id: 'wecom', group: NotificationGroup.work,
    name: '\u4F01\u4E1A\u5FAE\u4FE1', icon: '\u4F01', color: 0xFF2F78DD,
    subtitle: '\u5DE5\u4F5C\u6D88\u606F\u4E0E\u4F1A\u8BAE', enabled: false),
  NotificationSource(id: 'dingtalk', group: NotificationGroup.work,
    name: '\u9489\u9489', icon: '\u9489', color: 0xFF1687F8,
    subtitle: '\u5DE5\u4F5C\u901A\u77E5\u4E0E\u5BA1\u6279', enabled: false),
  NotificationSource(id: 'meeting', group: NotificationGroup.work,
    name: '\u817E\u8BAF\u4F1A\u8BAE', icon: '\u4F1A', color: 0xFF2B6FF7,
    subtitle: '\u4F1A\u8BAE\u5F00\u59CB\u4E0E\u9080\u8BF7', enabled: true),
  NotificationSource(id: 'mail', group: NotificationGroup.other,
    name: '\u90AE\u4EF6', icon: '\u90AE', color: 0xFFD04B3E,
    subtitle: '\u7CFB\u7EDF\u9ED8\u8BA4\u90AE\u4EF6\u5E94\u7528', enabled: false),
  NotificationSource(id: 'calendar', group: NotificationGroup.other,
    name: '\u65E5\u5386', icon: '\u5386', color: 0xFFE06B3C,
    subtitle: '\u65E5\u7A0B\u5373\u5C06\u5F00\u59CB', enabled: true),
  NotificationSource(id: 'delivery', group: NotificationGroup.other,
    name: '\u5FEB\u9012\u4E0E\u5916\u5356', icon: '\u9012', color: 0xFFE59A20,
    subtitle: '\u914D\u9001\u8FDB\u5EA6\u4E0E\u53D6\u4EF6\u63D0\u9192', enabled: false),
];

const _kNotificationChannel = 'honeybox/notification_listener';

class NotificationBridge {
  static const _methodChannel = MethodChannel(_kNotificationChannel);
  static const _eventChannel = EventChannel('honeybox/notification_events');
  static StreamSubscription<dynamic>? _eventSub;

  static Future<bool> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
      return true;
    } catch (e) {
      debugPrint('NotificationBridge: openNotificationSettings failed: $e');
      return false;
    }
  }

  static Future<bool> isListenerEnabled() async {
    try {
      final r = await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return r ?? false;
    } catch (e) {
      debugPrint('NotificationBridge: isListenerEnabled failed: $e');
      return false;
    }
  }

  static void startListening(WatchNotificationNotifier notifier) {
    _eventSub?.cancel();
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is! Map) return;
        final captured = CapturedNotification(
          appName: data['appName'] as String? ?? '',
          title: data['title'] as String? ?? '',
          message: data['message'] as String? ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
        notifier.onNotificationCaptured(captured);
      },
      onError: (Object error) {
        debugPrint('NotificationBridge: event error: $error');
      },
    );
  }

  static void stopListening() {
    _eventSub?.cancel();
    _eventSub = null;
  }
}

WatchNotificationState _defaultState() => WatchNotificationState(
  sources: kDefaultSources,
  masterEnabled: true,
  permissionGranted: false,
  privacy: NotificationPrivacy.titleAndContact,
  quietEnabled: false,
  quietStart: const TimeOfDay(hour: 22, minute: 30),
  quietEnd: const TimeOfDay(hour: 7, minute: 30),
  isInQuietPeriod: false,
);

class WatchNotificationNotifier extends StateNotifier<WatchNotificationState> {
  WatchNotificationNotifier() : super(_defaultState()) {
    _checkPermission();
    NotificationBridge.startListening(this);
  }

  Timer? _quietTimer;

  Future<void> _checkPermission() async {
    final enabled = await NotificationBridge.isListenerEnabled();
    if (enabled != state.permissionGranted) {
      state = state.copyWith(permissionGranted: enabled);
    }
    _updateQuietPeriod();
  }

  void toggleMaster() {
    final next = !state.masterEnabled;
    state = state.copyWith(
      masterEnabled: next,
      isInQuietPeriod: next ? _isQuietPeriod() : false,
    );
  }

  void requestPermission() {
    NotificationBridge.openNotificationSettings();
    state = state.copyWith(permissionGranted: true, masterEnabled: true);
  }

  void toggleSource(String sourceId) {
    final updated = state.sources.map((s) {
      if (s.id == sourceId) return s.copyWith(enabled: !s.enabled);
      return s;
    }).toList();
    state = state.copyWith(sources: updated);
  }

  void setPrivacy(NotificationPrivacy privacy) {
    state = state.copyWith(privacy: privacy);
  }

  void toggleQuiet() {
    final next = !state.quietEnabled;
    state = state.copyWith(quietEnabled: next,
      isInQuietPeriod: next ? _isQuietPeriod() : false);
    _scheduleQuietCheck();
  }

  void setQuietStart(TimeOfDay t) {
    state = state.copyWith(quietStart: t);
    _updateQuietPeriod();
    _scheduleQuietCheck();
  }

  void setQuietEnd(TimeOfDay t) {
    state = state.copyWith(quietEnd: t);
    _updateQuietPeriod();
    _scheduleQuietCheck();
  }

  void onNotificationCaptured(CapturedNotification n) {
    state = state.copyWith(lastNotification: n);
  }

  bool _isQuietPeriod() {
    if (!state.quietEnabled) return false;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day,
      state.quietStart.hour, state.quietStart.minute);
    final end = DateTime(now.year, now.month, now.day,
      state.quietEnd.hour, state.quietEnd.minute);
    if (end.isBefore(start)) {
      return now.isAfter(start) || now.isBefore(end.add(const Duration(days: 1)));
    }
    return now.isAfter(start) && now.isBefore(end);
  }

  void _updateQuietPeriod() {
    state = state.copyWith(isInQuietPeriod: _isQuietPeriod());
  }

  void _scheduleQuietCheck() {
    _quietTimer?.cancel();
    if (state.quietEnabled) {
      _quietTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateQuietPeriod();
      });
    }
  }

  @override
  void dispose() {
    _quietTimer?.cancel();
    NotificationBridge.stopListening();
    super.dispose();
  }
}

final watchNotificationProvider =
    StateNotifierProvider.autoDispose<WatchNotificationNotifier, WatchNotificationState>(
  (ref) => WatchNotificationNotifier(),
);
