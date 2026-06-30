import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'encoder.dart';

/// Persists the last-used [EncoderConfig] to a JSON file in the app support
/// directory, so the encoding test bench restores history on the next launch.
class EncoderConfigStore {
  EncoderConfigStore._();

  static const _fileName = 'encoder_config.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Load the saved config, falling back to defaults when absent/corrupt.
  static Future<EncoderConfig> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const EncoderConfig();
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return EncoderConfig.fromJson(map);
    } catch (_) {
      return const EncoderConfig();
    }
  }

  /// Persist [config]. Failures are swallowed — persistence is best-effort.
  static Future<void> save(EncoderConfig config) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(config.toJson()));
    } catch (_) {}
  }
}
