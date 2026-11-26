import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Streams received PCM frames into a WAV file while recording is active.
///
/// The temporary file is renamed only when the stop is processed, so the final
/// name can use the stop timestamp without buffering the whole recording in RAM.
class WatchRecordFileWriter {
  WatchRecordFileWriter({required Directory root, required String deviceId})
      : _root = root,
        _deviceId = deviceId;

  final Directory _root;
  final String _deviceId;

  RandomAccessFile? _file;
  File? _temporary;
  Future<void> _writeTail = Future<void>.value();
  int _sampleRate = 0;
  int _channels = 1;
  int _bitsPerSample = 16;
  int _dataBytes = 0;
  bool _active = false;

  bool get isActive => _active;
  int get dataBytes => _dataBytes;

  static Future<WatchRecordFileWriter> createDefault({
    required String deviceId,
  }) async {
    final support = await getApplicationSupportDirectory();
    return WatchRecordFileWriter(
      root: Directory('${support.path}/watch_recordings'),
      deviceId: deviceId,
    );
  }

  Future<void> start({
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
    required DateTime startedAt,
  }) async {
    if (_active) throw StateError('Recording file is already active');

    final deviceDirectory = Directory(
      '${_root.path}/${_deviceId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}',
    );
    await deviceDirectory.create(recursive: true);
    final temporary = File(
      '${deviceDirectory.path}/.active-${startedAt.millisecondsSinceEpoch}.part',
    );
    final file = await temporary.open(mode: FileMode.write);
    await file.writeFrom(_wavHeader(0));

    _temporary = temporary;
    _file = file;
    _sampleRate = sampleRate;
    _channels = channels;
    _bitsPerSample = bitsPerSample;
    _dataBytes = 0;
    _writeTail = Future<void>.value();
    _active = true;
  }

  Future<void> append(Iterable<Uint8List> frames) {
    final file = _file;
    if (!_active || file == null) return Future<void>.value();
    final builder = BytesBuilder(copy: false);
    for (final frame in frames) {
      builder.add(frame);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) return _writeTail;

    _writeTail = _writeTail.then((_) async {
      await file.writeFrom(bytes);
      _dataBytes += bytes.length;
    });
    return _writeTail;
  }

  Future<File?> finish(DateTime stoppedAt) async {
    final file = _file;
    final temporary = _temporary;
    if (!_active || file == null || temporary == null) return null;
    _active = false;

    await _writeTail;
    await file.setPosition(0);
    await file.writeFrom(_wavHeader(_dataBytes));
    await file.flush();
    await file.close();
    _file = null;

    final finalFile = await _uniqueFile(stoppedAt);
    await temporary.rename(finalFile.path);
    _temporary = null;
    return finalFile;
  }

  Future<void> abort() async {
    final file = _file;
    final temporary = _temporary;
    _active = false;
    _file = null;
    _temporary = null;
    if (file != null) {
      await _writeTail;
      await file.close();
    }
    if (temporary != null && await temporary.exists()) {
      await temporary.delete();
    }
  }

  Future<File> _uniqueFile(DateTime stoppedAt) async {
    final stem = _timestamp(stoppedAt);
    for (var suffix = 0;; suffix++) {
      final name = suffix == 0 ? '$stem.wav' : '${stem}_$suffix.wav';
      final file = File('${_root.path}/'
          '${_deviceId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}/$name');
      if (!await file.exists()) return file;
    }
  }

  static String _timestamp(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}${two(local.month)}${two(local.day)}_'
        '${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }

  Uint8List _wavHeader(int dataBytes) {
    final bytesPerSample = (_bitsPerSample + 7) ~/ 8;
    final blockAlign = _channels * bytesPerSample;
    final byteRate = _sampleRate * blockAlign;
    final header = ByteData(44)
      ..setUint8(0, 0x52)
      ..setUint8(1, 0x49)
      ..setUint8(2, 0x46)
      ..setUint8(3, 0x46)
      ..setUint32(4, 36 + dataBytes, Endian.little)
      ..setUint8(8, 0x57)
      ..setUint8(9, 0x41)
      ..setUint8(10, 0x56)
      ..setUint8(11, 0x45)
      ..setUint8(12, 0x66)
      ..setUint8(13, 0x6D)
      ..setUint8(14, 0x74)
      ..setUint8(15, 0x20)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, _channels, Endian.little)
      ..setUint32(24, _sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, _bitsPerSample, Endian.little)
      ..setUint8(36, 0x64)
      ..setUint8(37, 0x61)
      ..setUint8(38, 0x74)
      ..setUint8(39, 0x61)
      ..setUint32(40, dataBytes, Endian.little);
    return header.buffer.asUint8List();
  }
}
