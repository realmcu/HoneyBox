import 'dart:typed_data';

import 'l2_file_transfer.dart';

/// CRC-16/CCITT-FALSE — polynomial 0x1021, init 0xFFFF, no input/output
/// reflection, no final XOR. Per desk-mate PROTOCOL.md §2.1 the L1 CRC16
/// covers **only the L2 payload** (not the frame header / crc / seq fields);
/// an empty payload (ACK frames) therefore yields the init value 0xFFFF.
/// Self-check: crc16("123456789") == 0x29B1.
int _crc16(Uint8List data) {
  int crc = 0xFFFF;
  for (int i = 0; i < data.length; i++) {
    crc ^= (data[i] << 8) & 0xFFFF;
    for (int j = 0; j < 8; j++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc & 0xFFFF;
}

void _writeU16(Uint8List data, int offset, int value) {
  data[offset] = (value >> 8) & 0xFF;
  data[offset + 1] = value & 0xFF;
}

int _readU16(List<int> data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

/// L1 frame control byte values.
class _Ctrl {
  static const int data = 0x00;
  static const int ack = 0x10;
  static const int error = 0x30;
}

/// The L1 engine handles low-level BLE frame framing, CRC validation, ACK
/// generation, and MTU-aware chunking.
///
/// It is a direct port of the working WeChat miniprogram L1 implementation and
/// carries **no Flutter dependency** for testability.
class L1Engine {
  /// Callback used to enqueue a raw byte chunk for transmission.
  final void Function(Uint8List chunk) writeFn;

  /// Sequence number for the next outbound L1 frame.
  int _seq = 0;

  /// Buffer of bytes received from the BLE notify characteristic.
  final List<int> _rxBuf = [];

  /// Maximum number of payload bytes per BLE write chunk.
  int _chunkSize = 20;

  /// The currently bound file-transfer session, if any.
  FileTransferSession? _session;

  /// Callback invoked when an ACK or ERROR L1 frame is received.
  void Function(int seq, bool ok)? onAck;

  /// Callback invoked for the payload of *every* inbound L2 DATA frame, in
  /// addition to the attached [FileTransferSession]. Used to route command-channel
  /// L2 frames that don't belong to a file transfer (e.g. WiFi provisioning,
  /// CMD 0x0D) without stealing them from the file-transfer session.
  void Function(Uint8List payload)? onL2Data;

  L1Engine({required this.writeFn});

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Update the MTU. The effective chunk size is `max(20, mtu - 3)`.
  void setMtu(int mtu) {
    _chunkSize = mtu - 3;
    if (_chunkSize < 20) _chunkSize = 20;
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  /// Bind a [FileTransferSession].
  ///
  /// Does NOT reset the sequence number — L1 seq is a connection-level counter.
  /// Resetting on attach causes the device to discard BEGIN_REQ as a stale frame.
  void attach(FileTransferSession session) {
    _session = session;
  }

  /// Detach the current session without sending any teardown.
  void detach() {
    _session = null;
  }

  /// Reset all internal state (sequence number, receive buffer, session).
  /// Only called on disconnect / connection end.
  void reset() {
    _seq = 0;
    _rxBuf.clear();
    _session = null;
    onAck = null;
    onL2Data = null;
  }

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  /// Build a full L1 frame (header + payload) as a single [Uint8List].
  ///
  /// Per desk-mate PROTOCOL.md §2.1 the CRC16 (CCITT-FALSE) covers **only the
  /// L2 payload** — not the header, crc, or seq fields.
  Uint8List _buildL1Frame(int ctrl, Uint8List payload, {int? seqOverride}) {
    final seq = seqOverride ?? _seq;
    final header = Uint8List(8);
    header[0] = 0xAB;
    header[1] = ctrl;
    _writeU16(header, 2, payload.length);

    final crc = _crc16(payload);
    _writeU16(header, 4, crc);
    _writeU16(header, 6, seq);

    final frame = Uint8List(8 + payload.length);
    frame.setRange(0, 8, header);
    frame.setRange(8, 8 + payload.length, payload);
    return frame;
  }

  /// Send an L2 [payload] through the L1 layer.
  ///
  /// Returns the sequence number used for this frame.
  int sendL2(Uint8List payload) {
    final seq = _seq;
    final frame = _buildL1Frame(_Ctrl.data, payload);
    _sliceAndWrite(frame);
    _seq = (seq + 1) & 0xFFFF;
    return seq;
  }

  /// Split a complete L1 frame into MTU-sized chunks and write each via
  /// [writeFn].
  void _sliceAndWrite(Uint8List frame) {
    int offset = 0;
    while (offset < frame.length) {
      final end = (offset + _chunkSize) < frame.length
          ? offset + _chunkSize
          : frame.length;
      final chunk = Uint8List(end - offset);
      for (int i = offset; i < end; i++) {
        chunk[i - offset] = frame[i];
      }
      writeFn(chunk);
      offset = end;
    }
  }

  // ---------------------------------------------------------------------------
  // Receiving
  // ---------------------------------------------------------------------------

  /// Feed raw notification bytes into the receive buffer and attempt to drain
  /// complete L1 frames.
  void onNotified(Uint8List data) {
    _rxBuf.addAll(data);
    _drainRx();
  }

  /// Drain as many complete frames as possible from [_rxBuf].
  void _drainRx() {
    while (true) {
      // 1. Skip non-0xAB bytes.
      int start = 0;
      while (start < _rxBuf.length && _rxBuf[start] != 0xAB) {
        start++;
      }
      if (start > 0) {
        _rxBuf.removeRange(0, start);
      }

      // 2. Need at least 8 bytes for the header.
      if (_rxBuf.length < 8) return;

      // 3. Payload length from header bytes [2..3].
      final payloadLen = _readU16(_rxBuf, 2);

      // Guard against implausible payload length that would pin the parser.
      if (payloadLen > 32 * 1024) {
        // Drop this bogus starting byte and retry.
        _rxBuf.removeAt(0);
        continue;
      }

      // 4. Need 8 + payloadLen bytes for a complete frame.
      if (_rxBuf.length < 8 + payloadLen) return;

      // 5. Copy the complete frame bytes.
      final frameBytes = Uint8List.fromList(_rxBuf.sublist(0, 8 + payloadLen));

      // 6. Consume the frame from the buffer first (defensive: even if
      //    validation fails, we don't want to re-parse the same bytes).
      _rxBuf.removeRange(0, 8 + payloadLen);

      // 7. Parse header. Per PROTOCOL.md §6.1 the host does NOT validate the
      //    inbound L1 CRC16 — framing relies on the 0xAB sync byte + length
      //    field (only the device validates CRC strictly, on frames we send).
      final ctrl = frameBytes[1];
      final frameSeq = _readU16(frameBytes, 6);

      // 8. Dispatch by control byte.
      if (ctrl == _Ctrl.ack) {
        onAck?.call(frameSeq, true);
      } else if (ctrl == _Ctrl.error) {
        // The frame's seq field tells the sender which frame was NAK'd.
        onAck?.call(frameSeq, false);
      } else if (ctrl == _Ctrl.data) {
        // Data frame → send back an ACK.
        _sendAck(frameSeq);

        // Deliver the payload to the L2 session and any general listener.
        final payload = frameBytes.sublist(8);
        _session?.onL2Frame(payload);
        onL2Data?.call(payload);
      }
      // Unknown control bytes are silently skipped.
    }
  }

  /// Build and enqueue an ACK for the given [seq].
  void _sendAck(int seq) {
    _sliceAndWrite(_buildL1Frame(_Ctrl.ack, Uint8List(0), seqOverride: seq));
  }

  // ---------------------------------------------------------------------------
  // Accessors (for testing / diagnostics)
  // ---------------------------------------------------------------------------

  int get currentSeq => _seq;
  int get chunkSize => _chunkSize;
  FileTransferSession? get session => _session;
}
