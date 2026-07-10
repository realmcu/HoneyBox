import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble_provider.dart';

enum TransferStatus { idle, sending, done, error }

class TransferState {
  final TransferStatus status;
  final double progress; // 0.0 to 1.0
  final int speedKBs;
  final String? errorMessage;

  const TransferState({
    this.status = TransferStatus.idle,
    this.progress = 0.0,
    this.speedKBs = 0,
    this.errorMessage,
  });

  TransferState copyWith({
    TransferStatus? status,
    double? progress,
    int? speedKBs,
    String? errorMessage,
  }) {
    return TransferState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedKBs: speedKBs ?? this.speedKBs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Transfer progress notifier — manages file transfer status
final transferProgressProvider =
    StateNotifierProvider<TransferProgressNotifier, TransferState>((ref) {
  return TransferProgressNotifier(ref);
});

class TransferProgressNotifier extends StateNotifier<TransferState> {
  final Ref _ref;
  int _startTime = 0;

  TransferProgressNotifier(this._ref) : super(const TransferState());

  /// Send a file via BLE. Sets up progress/complete/error callbacks.
  ///
  /// When [trailingByte] is non-null it is appended as one extra byte at the
  /// very end of [buffer], becoming the last byte of the transferred payload.
  /// Used to tag the kind of a TYPE.image file for the device: 0 = picture,
  /// 1 = danmaku.
  void send(int fileType, Uint8List buffer, String filename,
      {int? trailingByte}) {
    final bleManager = _ref.read(bleManagerProvider);
    final session = bleManager.session;
    if (session == null) {
      state = const TransferState(
        status: TransferStatus.error,
        errorMessage: '设备未连接',
      );
      return;
    }

    _startTime = DateTime.now().millisecondsSinceEpoch;
    state = const TransferState(status: TransferStatus.sending);

    session.onProgress = (sent, total) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - _startTime) / 1000;
      final speed = elapsed > 0 ? (sent / elapsed / 1024).round() : 0;
      state = TransferState(
        status: TransferStatus.sending,
        progress: total > 0 ? sent / total : 0.0,
        speedKBs: speed,
      );
    };

    session.onComplete = () {
      state = const TransferState(status: TransferStatus.done, progress: 1.0);
    };

    session.onError = (reason) {
      state = TransferState(
        status: TransferStatus.error,
        errorMessage: reason,
      );
    };

    // Optionally append the one-byte content-kind tag (image=0, danmaku=1) so
    // it rides along as the final byte of the payload.
    final payload = trailingByte == null
        ? buffer
        : (Uint8List(buffer.length + 1)
          ..setRange(0, buffer.length, buffer)
          ..[buffer.length] = trailingByte & 0xFF);
    session.send(fileType, payload, filename);
  }

  void abort() {
    final bleManager = _ref.read(bleManagerProvider);
    bleManager.session?.abort();
    state = const TransferState();
  }

  void reset() {
    state = const TransferState();
  }

  /// Stop any in-flight transfer and clear its status when a sender page is
  /// disposed. Safe to call from `State.dispose()`: writing provider state
  /// synchronously there rebuilds the disposing (now-defunct) element and trips
  /// a `markNeedsBuild()` assertion, so the write is deferred to a microtask
  /// (which never runs during a build/dispose) and thus reaches only live
  /// listeners.
  void resetForDispose() {
    final wasSending = state.status == TransferStatus.sending;
    Future.microtask(() => wasSending ? abort() : reset());
  }
}
