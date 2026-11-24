import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../i18n/app_language.dart';

/// App-wide user preferences (persisted to a small JSON file in the app support
/// directory). Currently: local-cache size cap and the eBadge debug-mode
/// switch. More knobs can be added alongside these without touching the
/// persistence plumbing.
class AppSettings {
  /// Upper bound on the total size of the local send-cache, in megabytes.
  final int cacheLimitMB;

  /// eBadge 无实物调试模式:开启后扫描列表首行注入虚拟设备
  /// `eBadge-debug`,供 UI/交互走查(不发起真实 BLE 连接、不发送数据)。
  /// 见 docs/superpowers/specs/2026-07-29-debug-mode-fake-device-design.md
  final bool debugMode;

  /// UI language: `system` follows the device locale.
  final AppLanguage language;

  const AppSettings({
    this.cacheLimitMB = kDefaultCacheLimitMB,
    this.debugMode = false,
    this.language = AppLanguage.system,
  });

  AppSettings copyWith({
    int? cacheLimitMB,
    bool? debugMode,
    AppLanguage? language,
  }) =>
      AppSettings(
        cacheLimitMB: cacheLimitMB ?? this.cacheLimitMB,
        debugMode: debugMode ?? this.debugMode,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'cacheLimitMB': cacheLimitMB,
        'debugMode': debugMode,
        'language': language.tag,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        cacheLimitMB:
            ((json['cacheLimitMB'] as num?)?.toInt() ?? kDefaultCacheLimitMB)
                .clamp(kMinCacheLimitMB, kMaxCacheLimitMB),
        debugMode: json['debugMode'] as bool? ?? false,
        language: appLanguageFromTag(json['language'] as String?),
      );
}

/// Cache-limit slider bounds and default (megabytes).
const int kMinCacheLimitMB = 5;
const int kMaxCacheLimitMB = 50;
const int kDefaultCacheLimitMB = 20;

/// Reactive holder for [AppSettings]. Loads the persisted value on creation
/// (state starts at defaults, then updates once the file is read) and writes
/// back on every change. Persistence is best-effort — failures are swallowed so
/// a read-only filesystem never blocks the UI.
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _fileName = 'app_settings.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      state = AppSettings.fromJson(map);
    } catch (_) {
      // Keep defaults on any read/parse failure.
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  /// Update the cache cap (clamped to the allowed range) and persist.
  void setCacheLimitMB(int mb) {
    final clamped = mb.clamp(kMinCacheLimitMB, kMaxCacheLimitMB);
    if (clamped == state.cacheLimitMB) return;
    state = state.copyWith(cacheLimitMB: clamped);
    _save();
  }

  /// Switch the UI language and persist it. Pushing it to the native dashboard
  /// is the caller's job (see `languageProviders`), because that needs the
  /// platform channel and a `WidgetRef`.
  void setLanguage(AppLanguage value) {
    if (value == state.language) return;
    state = state.copyWith(language: value);
    _save();
  }

  /// Toggle eBadge 无实物调试模式(see [AppSettings.debugMode]).
  void setDebugMode(bool value) {
    if (value == state.debugMode) return;
    state = state.copyWith(debugMode: value);
    _save();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());
