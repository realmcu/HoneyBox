import 'dart:async' as _async;
import 'dart:convert';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// CRC-32 (polynomial 0xEDB88320, reflected)
// ---------------------------------------------------------------------------

/// Compute a table-based CRC-32 over [data] and return the unsigned 32-bit
/// value.
int crc32(Uint8List data) {
  const int poly = 0xEDB88320;

  // Build lookup table once.
  final table = List<int>.generate(256, (int i) {
    int crc = i;
    for (int j = 0; j < 8; j++) {
      if (crc & 1 != 0) {
        crc = (crc >> 1) ^ poly;
      } else {
        crc = crc >> 1;
      }
    }
    return crc;
  });

  int crc = 0xFFFFFFFF;
  for (int i = 0; i < data.length; i++) {
    final index = (crc ^ data[i]) & 0xFF;
    crc = (crc >> 8) ^ table[index];
  }
  return (crc ^ 0xFFFFFFFF) >>> 0; // force unsigned 32-bit
}

// ---------------------------------------------------------------------------
// Protocol constants
// ---------------------------------------------------------------------------

/// The command byte for all L2 file-transfer frames.
const int l2Cmd = 0x10;

/// L2 sub-command keys.
class K {
  K._();
  static const int beginReq = 0x01;
  static const int beginRsp = 0x02;
  static const int data = 0x03;
  static const int endReq = 0x05;
  static const int endRsp = 0x06;
  static const int abort = 0x07;
}

/// File type identifiers.
class TYPE {
  TYPE._();
  static const int raw = 0x00;
  static const int image = 0x01;
  static const int video = 0x02;
}

/// L2 state machine states.
class L2State {
  L2State._();
  static const int idle = 0;
  static const int negotiating = 1;
  static const int transferring = 2;
  static const int verifying = 3;
}

// ---------------------------------------------------------------------------
// Byte helpers
// ---------------------------------------------------------------------------

void _writeU16(Uint8List data, int offset, int value) {
  data[offset] = (value >> 8) & 0xFF;
  data[offset + 1] = value & 0xFF;
}

void _writeU32(Uint8List data, int offset, int value) {
  data[offset] = (value >> 24) & 0xFF;
  data[offset + 1] = (value >> 16) & 0xFF;
  data[offset + 2] = (value >> 8) & 0xFF;
  data[offset + 3] = value & 0xFF;
}

int _readU16(Uint8List data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

// ---------------------------------------------------------------------------
// Timeout constants
// ---------------------------------------------------------------------------

const int _defaultChunkSize = 2048;
// Host-waits-for-slave-reply timeouts, unified to 25 s: a slow device may erase
// flash before replying with BEGIN_RSP, or verify the CRC and commit the file
// before END_RSP, so give ample headroom before declaring the transfer failed.
const Duration _negotiationTimeout = Duration(seconds: 25); // BEGIN_RSP
const Duration _dataAckTimeout = Duration(seconds: 25); // DATA L1 ACK
const Duration _verifyTimeout = Duration(seconds: 25); // END_RSP

// ---------------------------------------------------------------------------
// Parsed L2 frame
// ---------------------------------------------------------------------------

/// A single parsed L2 frame.
class L2Frame {
  final int cmdId;
  final int key;
  final Uint8List value;

  const L2Frame({
    required this.cmdId,
    required this.key,
    required this.value,
  });
}

// ---------------------------------------------------------------------------
// Frame builders
// ---------------------------------------------------------------------------

/// Build a generic L2 frame: [cmd, 0x00, key, vLen_hi, vLen_lo] + value
Uint8List buildL2Frame(int key, Uint8List value) {
  final len = value.length;
  final frame = Uint8List(5 + len);
  frame[0] = l2Cmd;
  frame[1] = 0x00;
  frame[2] = key;
  frame[3] = (len >> 8) & 0xFF;
  frame[4] = len & 0xFF;
  if (len > 0) {
    frame.setRange(5, 5 + len, value);
  }
  return frame;
}

/// Build a BEGIN_REQ frame.
///
/// Payload layout:
///   [type(1), totalSize(4), chunkSize(2), nameLen(1), utf8Name]
Uint8List buildBeginReq(
  int fileType,
  int totalSize,
  int chunkSize,
  String filename,
) {
  final nameBytes = Uint8List.fromList(utf8.encode(filename));
  final value = Uint8List(8 + nameBytes.length);
  value[0] = fileType;
  _writeU32(value, 1, totalSize);
  _writeU16(value, 5, chunkSize);
  value[7] = nameBytes.length & 0xFF;
  value.setRange(8, 8 + nameBytes.length, nameBytes);
  return buildL2Frame(K.beginReq, value);
}

/// Build a DATA frame.
///
/// Payload: [seq_hi, seq_lo] + chunk
Uint8List buildDataFrame(int seq, Uint8List chunk) {
  final value = Uint8List(2 + chunk.length);
  _writeU16(value, 0, seq);
  value.setRange(2, 2 + chunk.length, chunk);
  return buildL2Frame(K.data, value);
}

/// Build an END_REQ frame.
///
/// Payload: [crc32(4)]
Uint8List buildEndReq(int crc32Val) {
  final value = Uint8List(4);
  _writeU32(value, 0, crc32Val);
  return buildL2Frame(K.endReq, value);
}

/// Build an ABORT frame.
///
/// Payload: [reason]
Uint8List buildAbort(int reason) {
  final value = Uint8List(1);
  value[0] = reason & 0xFF;
  return buildL2Frame(K.abort, value);
}

/// Parse a raw L2 payload (already stripped of the L1 header) into an
/// [L2Frame]. Returns `null` on malformed input.
L2Frame? parseL2Frame(Uint8List data) {
  if (data.length < 5) return null;
  if (data[0] != l2Cmd) return null;

  final key = data[2];
  final valLen = (data[3] << 8) | data[4];
  if (data.length < 5 + valLen) return null;

  final value = data.sublist(5, 5 + valLen);
  return L2Frame(cmdId: data[0], key: key, value: value);
}

// ---------------------------------------------------------------------------
// Timer provider abstraction
// ---------------------------------------------------------------------------

/// Typedef for a no-argument callback used by [TimerProvider].
typedef void TimerCallback();

/// Minimal abstraction so [FileTransferSession] can use timers without a
/// direct `dart:async` dependency on the public API. Production code uses
/// the default dart:async-based provider. Tests can inject a fake.
abstract class TimerProvider {
  void start(Duration duration, TimerCallback callback);
  void cancel();
}

/// Default timer provider backed by `dart:async.Timer`.
class _DefaultTimerProvider implements TimerProvider {
  _async.Timer? _timer;

  @override
  void start(Duration duration, TimerCallback callback) {
    _timer = _async.Timer(duration, callback);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

// ---------------------------------------------------------------------------
// FileTransferSession
// ---------------------------------------------------------------------------

/// Signature for sending raw L2 bytes through the L1 engine.
///
/// Returns the L1 sequence number assigned to the frame, which the session
/// uses to match ACKs.
typedef int SendL2Fn(Uint8List frame);

/// Manages the L2 file-transfer state machine.
///
/// This class has **no Flutter dependency** and communicates with the L1 layer
/// through callbacks passed at construction time.
class FileTransferSession {
  // --------------------------------------------------------------------------
  // Dependencies
  // --------------------------------------------------------------------------

  /// Function to send a raw L2 frame via the L1 engine.
  final SendL2Fn sendL2;

  /// Called when the session should attach itself to the L1 engine (so
  /// [onL2Frame] calls arrive).
  final void Function(FileTransferSession session)? attachToL1;

  /// Called when the session should detach itself from the L1 engine.
  final void Function()? detachFromL1;

  // --------------------------------------------------------------------------
  // State
  // --------------------------------------------------------------------------

  int _state = L2State.idle;

  /// The complete file buffer being transferred.
  late Uint8List _buf;

  int _totalSize = 0;
  int _chunkSize = _defaultChunkSize;
  int _sentBytes = 0;
  int _dataSeq = 0;
  int _pendingL1Seq = -1;
  int _lastChunkLen = 0;
  int _crc32Val = 0;
  int _fileType = TYPE.raw;
  String _filename = '';

  /// Optional injected timer provider. When null, a default dart:async-based
  /// provider is used automatically.
  TimerProvider? _timerProvider;

  /// Lazily-allocated default timer provider. Instance-level so each session
  /// owns its own timer (avoids cross-session interference).
  _DefaultTimerProvider? _defaultTimerProvider;

  // --------------------------------------------------------------------------
  // Callbacks
  // --------------------------------------------------------------------------

  void Function(int sent, int total)? onProgress;
  void Function()? onComplete;
  void Function(String reason)? onError;

  // --------------------------------------------------------------------------
  // Construction
  // --------------------------------------------------------------------------

  FileTransferSession({
    required this.sendL2,
    this.attachToL1,
    this.detachFromL1,
    this.onProgress,
    this.onComplete,
    this.onError,
    TimerProvider? timerProvider,
  }) : _timerProvider = timerProvider;

  // --------------------------------------------------------------------------
  // Properties
  // --------------------------------------------------------------------------

  int get state => _state;
  int get sentBytes => _sentBytes;
  int get totalSize => _totalSize;
  int get chunkSize => _chunkSize;
  String get filename => _filename;
  int get fileType => _fileType;

  double get progress => _totalSize > 0 ? _sentBytes / _totalSize : 0.0;

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Start a file transfer.
  ///
  /// [fileType] is one of [TYPE.raw], [TYPE.image], or [TYPE.video].
  /// [buffer] contains the complete file bytes.
  /// [filename] is a human-readable name sent in the BEGIN_REQ.
  void send(int fileType, Uint8List buffer, String filename) {
    if (_state != L2State.idle) {
      _fail('Already in transfer');
      return;
    }

    _state = L2State.negotiating;
    _buf = buffer;
    _totalSize = buffer.length;
    _chunkSize = _defaultChunkSize;
    _fileType = fileType;
    _filename = filename;
    _sentBytes = 0;
    _dataSeq = 0;
    _pendingL1Seq = -1;
    _lastChunkLen = 0;
    _crc32Val = crc32(buffer);

    // Attach to L1 engine so onL2Frame callbacks arrive.
    attachToL1?.call(this);

    // Send BEGIN_REQ.
    final l2 = buildBeginReq(fileType, _totalSize, _chunkSize, filename);
    _pendingL1Seq = sendL2(l2);
    _startTimer(_negotiationTimeout, 'Wait for BEGIN_RSP timed out');
  }

  /// Abort the current transfer.
  void abort() {
    if (_state == L2State.idle) return;
    sendL2(buildAbort(0x01));
    _cleanUp();
  }

  /// Called by the L1 engine when an L2 frame arrives.
  void onL2Frame(Uint8List raw) {
    final frame = parseL2Frame(raw);
    if (frame == null) return;

    switch (frame.key) {
      case K.beginRsp:
        _onBeginRsp(frame.value);
        break;
      case K.endRsp:
        _onEndRsp(frame.value);
        break;
      case K.abort:
        _fail('Peer aborted');
        break;
    }
  }

  /// Called by the L1 engine when an ACK/NAK for our sent frame arrives.
  void onL1Ack(int seq, bool ok) {
    if (seq != _pendingL1Seq) return;
    if (_state == L2State.idle) return;

    if (!ok) {
      _fail('NAK for seq $seq');
      return;
    }

    if (_state == L2State.transferring) {
      _clearTimer();
      _sentBytes += _lastChunkLen;
      if (_sentBytes > _totalSize) _sentBytes = _totalSize;
      onProgress?.call(_sentBytes, _totalSize);
      _sendNextChunk();
    } else if (_state == L2State.verifying) {
      // END_REQ was ACK'd -- wait for END_RSP.
      _startTimer(_verifyTimeout, 'Wait for END_RSP timed out');
    }
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  void _sendNextChunk() {
    if (_sentBytes >= _totalSize) {
      // All data sent -- send END_REQ.
      _state = L2State.verifying;
      final l2 = buildEndReq(_crc32Val);
      _pendingL1Seq = sendL2(l2);
      _startTimer(_verifyTimeout, 'Wait for END_RSP timed out');
      return;
    }

    final remaining = _totalSize - _sentBytes;
    final chunkLen = remaining < _chunkSize ? remaining : _chunkSize;
    final chunk = _buf.sublist(_sentBytes, _sentBytes + chunkLen);

    final l2 = buildDataFrame(_dataSeq, chunk);
    _pendingL1Seq = sendL2(l2);
    _dataSeq++;
    _lastChunkLen = chunkLen;
    _startTimer(_dataAckTimeout, 'DATA ACK timed out');
  }

  void _onBeginRsp(Uint8List value) {
    if (_state != L2State.negotiating) return;
    _clearTimer();

    final status = value.isNotEmpty ? value[0] : 0;
    if (status != 0) {
      const reasons = {
        0x01: '设备忙',
        0x02: '存储空间不足',
        0x03: '不支持的文件类型',
      };
      _fail('握手被拒绝: ${reasons[status] ?? '0x${status.toRadixString(16)}'}');
      return;
    }

    if (value.length >= 3) {
      final agreedChunkSize = _readU16(value, 1);
      if (agreedChunkSize > 0) _chunkSize = agreedChunkSize;
    }

    _state = L2State.transferring;
    _sendNextChunk();
  }

  void _onEndRsp(Uint8List value) {
    if (_state != L2State.verifying) return;
    _clearTimer();
    _state = L2State.idle;
    onComplete?.call();
    _cleanUp();
  }

  // --------------------------------------------------------------------------
  // Timer
  // --------------------------------------------------------------------------

  void _startTimer(Duration duration, String message) {
    _clearTimer();
    final provider =
        _timerProvider ?? (_defaultTimerProvider ??= _DefaultTimerProvider());
    provider.start(duration, () => _fail(message));
  }

  void _clearTimer() {
    final provider =
        _timerProvider ?? (_defaultTimerProvider ??= _DefaultTimerProvider());
    provider.cancel();
  }

  // --------------------------------------------------------------------------
  // Cleanup
  // --------------------------------------------------------------------------

  void _fail(String reason) {
    _clearTimer();
    if (_state != L2State.idle) {
      sendL2(buildAbort(0x01));
    }
    onError?.call(reason);
    _cleanUp();
  }

  void _cleanUp() {
    _clearTimer();
    detachFromL1?.call();
    _state = L2State.idle;
    _buf = Uint8List(0);
    _totalSize = 0;
    _sentBytes = 0;
    _dataSeq = 0;
    _pendingL1Seq = -1;
    _lastChunkLen = 0;
    _crc32Val = 0;
    _fileType = TYPE.raw;
    _filename = '';
  }
}
