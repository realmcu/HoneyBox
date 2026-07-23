import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Save [bin] — a converted ARGB8565 (RAW or RLE) circular-thumbnail `.bin`,
/// the same bytes packaged as resource[1] — to a user-chosen location via the
/// system "save as" dialog.
///
/// The suggested filename is `<base>_<RRGGBB>.bin`, where `base` is [sourceName]
/// with any extension stripped and `RRGGBB` is the low 24 bits of [bgColor] —
/// i.e. the resource-pack header colour (the badge background) as six uppercase
/// hex digits. So a "cat.bin" framed on header colour 0x00·1E2A3B exports as
/// `cat_1E2A3B.bin`.
///
/// Shows a snackbar for success / cancel / failure. Call only while [context]
/// is mounted (the messenger is resolved before the first await, so it's safe
/// across the dialog's async gap).
Future<void> exportThumbnailBin(
  BuildContext context, {
  required Uint8List bin,
  required String sourceName,
  required int bgColor,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final String hex =
      (bgColor & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final String fileName = '${_stripExtension(sourceName)}_$hex.bin';
  try {
    // On Android/iOS file_picker persists `bytes` itself and returns the saved
    // path (which may be a content-uri); on desktop it only returns the chosen
    // path, so we write the bytes there ourselves.
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: '导出缩略图',
      fileName: fileName,
      bytes: bin,
    );
    if (path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('已取消导出')));
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bin, flush: true);
    }
    messenger.showSnackBar(SnackBar(content: Text('已导出: $fileName')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
  }
}

// Drop the trailing ".ext" so the exported name is `<stem>_<hex>.bin`, not
// `<stem>.bin_<hex>.bin`. A leading-dot name (".foo") keeps its full name.
String _stripExtension(String name) {
  final int dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
