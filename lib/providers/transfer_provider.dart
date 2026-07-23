import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble_provider.dart';
import '../services/file_cache.dart';
import '../services/resource_pack.dart';

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
  /// [buffer] is sent verbatim — for real sends it is a resource package whose
  /// header already carries the content kind and background colour, so no extra
  /// tag byte is appended.
  ///
  /// When [cache] is non-null, [buffer] is written to the local send-cache on
  /// successful completion, so it can later be reloaded and re-sent without
  /// re-conversion. Pass null (the default) to skip caching — e.g. when
  /// re-sending a file that was itself loaded from the cache.
  void send(int fileType, Uint8List buffer, String filename,
      {CacheSpec? cache}) {
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
      // Cache the sent package on success only (fire-and-forget). The cached
      // buffer is exactly what was sent, so re-sending it reproduces it byte for
      // byte.
      if (cache != null) {
        _ref.read(fileCacheProvider).add(cache.kind, buffer, cache.params);
      }
    };

    session.onError = (reason) {
      state = TransferState(
        status: TransferStatus.error,
        errorMessage: reason,
      );
    };

    // Log the package header being sent (both fresh sends and cache re-sends go
    // through here). Legacy bare-bin caches aren't packages → note that instead.
    final ResourcePack? pack = parseResourcePack(buffer);
    if (pack != null) {
      debugPrint('发送/资源包 ${pack.describeHeader()} '
          '→ "$filename" (TYPE=$fileType)');
    } else {
      debugPrint('发送/裸数据 ${buffer.length}B → "$filename" '
          '(TYPE=$fileType, 非资源包)');
    }

    session.send(fileType, buffer, filename);
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
