import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide user preferences (persisted to a small JSON file in the app support
/// directory). Currently just the local-cache size cap; more knobs can be added
/// alongside [cacheLimitMB] without touching the persistence plumbing.
class AppSettings {
  /// Upper bound on the total size of the local send-cache, in megabytes.
  final int cacheLimitMB;

  const AppSettings({this.cacheLimitMB = kDefaultCacheLimitMB});

  AppSettings copyWith({int? cacheLimitMB}) =>
      AppSettings(cacheLimitMB: cacheLimitMB ?? this.cacheLimitMB);

  Map<String, dynamic> toJson() => {'cacheLimitMB': cacheLimitMB};

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        cacheLimitMB:
            ((json['cacheLimitMB'] as num?)?.toInt() ?? kDefaultCacheLimitMB)
                .clamp(kMinCacheLimitMB, kMaxCacheLimitMB),
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
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());
