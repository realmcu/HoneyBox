import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/watch_record_file.dart';

void main() {
  test('writes PCM frames into a stop-time named WAV file', () async {
    final temp = await Directory.systemTemp.createTemp('watch-record-file-');
    addTearDown(() => temp.delete(recursive: true));
    final writer = WatchRecordFileWriter(root: temp, deviceId: 'watch:1');

    await writer.start(
      sampleRate: 16000,
      channels: 1,
      bitsPerSample: 16,
      startedAt: DateTime(2026, 11, 25, 16),
    );
    await writer.append([
      Uint8List.fromList([1, 2, 3, 4]),
      Uint8List.fromList([5, 6]),
    ]);
    final file = await writer.finish(DateTime(2026, 11, 25, 16, 30, 45));

    expect(file, isNotNull);
    expect(file!.path, endsWith('/watch_1/20261125_163045.wav'));
    final bytes = await file.readAsBytes();
    expect(bytes.length, 44 + 6);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(bytes.sublist(44), [1, 2, 3, 4, 5, 6]);
  });

  test('does not overwrite a recording stopped in the same second', () async {
    final temp = await Directory.systemTemp.createTemp('watch-record-file-');
    addTearDown(() => temp.delete(recursive: true));
    final stop = DateTime(2026, 11, 25, 16, 30, 45);

    final first = WatchRecordFileWriter(root: temp, deviceId: 'watch');
    await first.start(
      sampleRate: 16000,
      channels: 1,
      bitsPerSample: 16,
      startedAt: DateTime(2026, 11, 25, 16),
    );
    expect((await first.finish(stop))!.path, endsWith('20261125_163045.wav'));

    final second = WatchRecordFileWriter(root: temp, deviceId: 'watch');
    await second.start(
      sampleRate: 8000,
      channels: 1,
      bitsPerSample: 16,
      startedAt: DateTime(2026, 11, 25, 16, 31),
    );
    expect((await second.finish(stop))!.path, endsWith('20261125_163045_1.wav'));
  });
}
