import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';
import 'l2_file_transfer.dart';

/// Categories of send-cache entry. Each maps a cached artifact back to the exact
/// [send] parameters that reproduce it (device file type), so a cached file can
/// be re-sent through the normal transfer flow without re-conversion. Cached
/// bytes are the whole resource package; the device reads the content kind from
/// the package header, so no content-kind trailing byte is involved anymore.
/// [key] is the on-disk tag; [ext] the file suffix.
enum CacheKind {
  image('image', '图片', 'bin', TYPE.image, 'image.bin'),
  danmaku('danmaku', '弹幕', 'bin', TYPE.image, 'danmaku.bin'),
  video('video', '视频', 'avi', TYPE.video, 'video.avi');

  const CacheKind(
    this.key,
    this.label,
    this.ext,
    this.fileType,
    this.deviceName,
  );

  /// Stable identifier written into the cache filename.
  final String key;

  /// Human-facing Chinese label (图片 / 弹幕 / 视频).
  final String label;

  /// On-disk file extension (without dot).
  final String ext;

  /// Device file type ([TYPE.image] / [TYPE.video]) used when re-sending.
  final int fileType;

  /// Default filename presented to the device on (re)send.
  final String deviceName;

  static CacheKind? fromKey(String key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// One cached file, parsed from its name + on-disk stat.
class CacheEntry {
  final File file;
  final CacheKind kind;

  /// When the file was cached (parsed from the name; falls back to mtime).
  final DateTime time;

  /// Size on disk, in bytes.
  final int size;

  /// Conversion parameters decoded from the filename (e.g. {size: 360, cmp: rle}).
  final Map<String, String> params;

  const CacheEntry({
    required this.file,
    required this.kind,
    required this.time,
    required this.size,
    required this.params,
  });
}

/// What to cache after a successful send. Passed to [send]; the notifier writes
/// the pre-trailing-byte buffer to the cache on completion.
class CacheSpec {
  final CacheKind kind;
  final Map<String, String> params;
  const CacheSpec(this.kind, this.params);
}

/// On-disk cache of every successfully sent, converted artifact (images,
/// danmaku, videos — screencast is never routed through [send] so it is
/// naturally excluded). Files live in a private `file_cache/` directory and are
/// named `<timestamp>__<kind>__<params>.<ext>` so the list is self-describing
/// without a sidecar index. Total size is capped by
/// [AppSettings.cacheLimitMB]; adding past the cap evicts oldest-first.
class FileCache {
  FileCache(this._ref);

  final Ref _ref;

  static const _dirName = 'file_cache';

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// All cached entries (optionally of one [kind], and/or matching the [where]
  /// predicate — e.g. by a `src` param to split a shared pool), newest first.
  Future<List<CacheEntry>> list({
    CacheKind? kind,
    bool Function(CacheEntry)? where,
  }) async {
    try {
      final dir = await _dir();
      final entries = <CacheEntry>[];
      await for (final ent in dir.list(followLinks: false)) {
        if (ent is! File) continue;
        final e = _decode(ent);
        if (e == null) continue;
        if (kind != null && e.kind != kind) continue;
        if (where != null && !where(e)) continue;
        entries.add(e);
      }
      entries.sort((a, b) => b.time.compareTo(a.time));
      return entries;
    } catch (e) {
      debugPrint('FileCache.list: $e');
      return <CacheEntry>[];
    }
  }

  /// Total size of the whole cache, in bytes.
  Future<int> totalSize() async {
    final all = await list();
    return all.fold<int>(0, (sum, e) => sum + e.size);
  }

  /// Write [bytes] as a new cache entry of [kind] tagged with [params], then
  /// evict oldest entries until the total is back within the configured cap.
  /// The just-written file is never evicted (even if it alone exceeds the cap).
  /// Returns the created entry, or null on any I/O failure (best-effort).
  Future<CacheEntry?> add(
    CacheKind kind,
    Uint8List bytes,
    Map<String, String> params,
  ) async {
    try {
      final dir = await _dir();
      final stamp = _fmtStamp(DateTime.now());
      final tail = '${kind.key}__${_encodeParams(params)}.${kind.ext}';
      var name = '${stamp}__$tail';
      var file = File('${dir.path}/$name');
      var dedup = 1;
      while (await file.exists()) {
        name = '$stamp-$dedup'
            '__$tail';
        file = File('${dir.path}/$name');
        dedup++;
      }
      await file.writeAsBytes(bytes, flush: true);
      await _enforceLimit(keepName: name);
      return _decode(file);
    } catch (e) {
      debugPrint('FileCache.add: $e');
      return null;
    }
  }

  /// Delete a single cached file (best-effort).
  Future<void> delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('FileCache.delete: $e');
    }
  }

  /// Evict oldest entries until the total fits the current cap. Call after the
  /// user lowers the cap so the reduction takes effect immediately.
  Future<void> enforceLimit() => _enforceLimit(keepName: null);

  Future<void> _enforceLimit({required String? keepName}) async {
    try {
      final limitBytes =
          _ref.read(appSettingsProvider).cacheLimitMB * 1024 * 1024;
      final all = await list(); // newest first
      var total = all.fold<int>(0, (sum, e) => sum + e.size);
      if (total <= limitBytes) return;
      // Oldest are at the end of the newest-first list.
      for (final e in all.reversed) {
        if (total <= limitBytes) break;
        if (keepName != null && _base(e.file) == keepName) continue;
        await delete(e.file);
        total -= e.size;
      }
    } catch (e) {
      debugPrint('FileCache._enforceLimit: $e');
    }
  }

  /// Delete every cached file.
  Future<void> clear() async {
    try {
      final all = await list();
      for (final e in all) {
        await delete(e.file);
      }
    } catch (e) {
      debugPrint('FileCache.clear: $e');
    }
  }

  // ── Filename codec ─────────────────────────────────────────────────────────

  /// Parse a cache filename + stat into a [CacheEntry]; null if it isn't ours.
  CacheEntry? _decode(File f) {
    final name = _base(f);
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = name.substring(dot + 1);
    final base = name.substring(0, dot);
    final parts = base.split('__');
    if (parts.length < 2) return null;
    final kind = CacheKind.fromKey(parts[1]);
    if (kind == null || kind.ext != ext) return null;
    FileStat st;
    try {
      st = f.statSync();
    } catch (e) {
      debugPrint('FileCache._decode: $e');
      return null;
    }
    final time = _parseStamp(parts[0]) ?? st.modified;
    final params =
        parts.length >= 3 ? _decodeParams(parts[2]) : <String, String>{};
    return CacheEntry(
      file: f,
      kind: kind,
      time: time,
      size: st.size,
      params: params,
    );
  }

  static String _base(File f) => f.uri.pathSegments.last;

  static String _encodeParams(Map<String, String> params) {
    if (params.isEmpty) return 'na';
    return params.entries
        .map((e) => '${_san(e.key)}-${_san(e.value)}')
        .join('_');
  }

  static Map<String, String> _decodeParams(String s) {
    final out = <String, String>{};
    if (s.isEmpty || s == 'na') return out;
    for (final tok in s.split('_')) {
      final i = tok.indexOf('-');
      if (i <= 0) continue;
      out[tok.substring(0, i)] = tok.substring(i + 1);
    }
    return out;
  }

  /// Strip filename-delimiter characters so params round-trip cleanly.
  static String _san(String v) => v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  static String _two(int n) => n < 10 ? '0$n' : '$n';
  static String _three(int n) => n < 10 ? '00$n' : (n < 100 ? '0$n' : '$n');

  /// `yyyyMMdd-HHmmss-SSS` (local time) — the filename time prefix.
  static String _fmtStamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}'
      '-${_two(t.hour)}${_two(t.minute)}${_two(t.second)}'
      '-${_three(t.millisecond)}';

  static DateTime? _parseStamp(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final d = parts[0], t = parts[1], ms = parts[2];
    if (d.length != 8 || t.length != 6) return null;
    try {
      return DateTime(
        int.parse(d.substring(0, 4)),
        int.parse(d.substring(4, 6)),
        int.parse(d.substring(6, 8)),
        int.parse(t.substring(0, 2)),
        int.parse(t.substring(2, 4)),
        int.parse(t.substring(4, 6)),
        int.parse(ms),
      );
    } catch (e) {
      debugPrint('FileCache._parseStamp: $e');
      return null;
    }
  }
}

final fileCacheProvider = Provider<FileCache>((ref) => FileCache(ref));
