import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Outcome of an update check against the project's Gitee release page.
class UpdateInfo {
  /// Latest release version, leading `v` stripped (e.g. `0.8.0`).
  final String latestVersion;

  /// The version this app is currently running.
  final String currentVersion;

  /// Direct download URL of the latest release's `.apk` asset (empty if none).
  final String apkUrl;

  /// The release notes (`body`) as shown on Gitee.
  final String releaseNotes;

  /// True when [latestVersion] is newer than [currentVersion] and an APK asset
  /// is available to download.
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.apkUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

/// Checks the project's **public** Gitee repository for a newer release APK and
/// downloads it. The repo is public, so the release API is read anonymously —
/// no access token is embedded in the shipped app.
class UpdateService {
  UpdateService._();

  static const String _owner = 'realmcu';
  static const String _repo = 'hmi-android-apk';

  /// Gitee OpenAPI v5 — latest release of the repo.
  static const String _latestReleaseApi =
      'https://gitee.com/api/v5/repos/$_owner/$_repo/releases/latest';

  /// Queries the latest release and compares it with [currentVersion].
  /// Throws on network / parse errors so the caller can surface them.
  static Future<UpdateInfo> checkForUpdate(String currentVersion) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(_latestReleaseApi));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('Gitee 返回状态码 ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tag = (json['tag_name'] as String? ?? '').trim();
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '');
      final notes = (json['body'] as String? ?? '').trim();

      String apkUrl = '';
      for (final asset in (json['assets'] as List<dynamic>? ?? const [])) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String? ?? '';
        if (name.endsWith('.apk') && url.isNotEmpty) {
          apkUrl = url;
          break;
        }
      }

      return UpdateInfo(
        latestVersion: latest.isEmpty ? currentVersion : latest,
        currentVersion: currentVersion,
        apkUrl: apkUrl,
        releaseNotes: notes,
        hasUpdate: latest.isNotEmpty &&
            apkUrl.isNotEmpty &&
            _isNewer(latest, currentVersion),
      );
    } finally {
      client.close();
    }
  }

  /// Downloads [url] to an app-private file, reporting fractional progress
  /// (0–1), or `null` progress when the server omits a content length.
  /// Returns the saved file. Throws on failure.
  static Future<File> downloadApk(
    String url, {
    void Function(double? progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('下载失败，状态码 ${resp.statusCode}');
      }

      // App-specific external dir installs most reliably; fall back to cache.
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      final sink = file.openWrite();
      try {
        final total = resp.contentLength; // -1 when unknown
        var received = 0;
        await for (final chunk in resp) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(total > 0 ? received / total : null);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// True when dotted version [latest] is strictly greater than [current].
  /// Missing trailing parts are treated as 0 (so `0.8` == `0.8.0`).
  static bool _isNewer(String latest, String current) {
    final l = _parts(latest);
    final c = _parts(current);
    final n = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < n; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  static List<int> _parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
