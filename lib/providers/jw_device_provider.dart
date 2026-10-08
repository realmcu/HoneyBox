import '../services/jw/history/jw_history_models.dart';
import '../services/jw/history/jw_history_store.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../services/jw/jw_device_repository.dart';
import '../services/jw/jw_identity_store.dart';
import '../services/jw/jw_models.dart';
import '../services/jw/jw_session.dart';
import 'ble_provider.dart';

// One lazy app-owned store supports saved-history browsing across reconnects.
final jwHistoryStoreProvider = FutureProvider<JwHistoryStore>((ref) async {
  var disposed = false;
  JwHistoryStore? store;
  ref.onDispose(() {
    disposed = true;
    final current = store;
    if (current != null) {
      unawaited(current.close().catchError((Object _) {}));
    }
  });
  store = await openJwHistoryStore();
  if (disposed) {
    await store.close();
    throw StateError('History provider disposed');
  }
  return store;
});

final jwRepositoryProvider =
    FutureProvider.autoDispose<JwDeviceRepository?>((ref) async {
  final connected = ref.watch(connectedDeviceProvider);
  if (connected?.isJw != true) return null;
  final port = ref.read(bleManagerProvider).jwTransport;
  if (port == null) throw StateError('JW transport unavailable');
  var disposed = false;
  JwDeviceRepository? repository;
  ref.onDispose(() {
    disposed = true;
    final current = repository;
    if (current != null) unawaited(current.dispose().catchError((Object _) {}));
  });
  // Directory resolution errors keep the device readable and prevent writes.
  File file;
  try {
    final directory = await getApplicationSupportDirectory();
    file =
        File('${directory.path}${Platform.pathSeparator}jw_identity_v1.json');
  } catch (_) {
    // A deliberately invalid parent keeps failure inside the identity store,
    // after the read-only device information/capability queries.
    file = File(
        '${Platform.resolvedExecutable}${Platform.pathSeparator}jw_identity_v1.json');
  }
  if (disposed) return null;
  repository = JwDeviceRepository(
      session: JwSession(port),
      identityStore: JwIdentityStore(file),
      transport: port,
      platformDeviceKey: connected!.deviceId,
      historyStoreFactory: () => ref.read(jwHistoryStoreProvider.future),
      ownsHistoryStore: false);
  return repository;
});

final jwDeviceProvider =
    StateNotifierProvider.autoDispose<JwDeviceNotifier, JwDeviceState>((ref) {
  final repository = ref.watch(jwRepositoryProvider);
  final notifier = JwDeviceNotifier(
      repository: repository.valueOrNull,
      initialState: repository.hasError
          ? const JwDeviceState(
              phase: JwDevicePhase.failed,
              operationError: 'JW initialization unavailable')
          : null);
  Future.microtask(notifier.initialize);
  return notifier;
});

class JwDeviceNotifier extends StateNotifier<JwDeviceState> {
  final JwDeviceRepository? repository;
  StreamSubscription<JwDeviceState>? _subscription;
  Future<void>? _initializing;
  bool _closed = false;
  JwDeviceNotifier({required this.repository, JwDeviceState? initialState})
      : super(initialState ?? repository?.state ?? const JwDeviceState()) {
    _subscription = repository?.changes.listen((next) {
      if (!_closed) state = next;
    });
  }
  Future<void> initialize() =>
      _initializing ??= _run(() => repository!.initialize());
  Future<void> _run(Future<void> Function() action) async {
    if (_closed || repository == null || state.operationInProgress) return;
    try {
      await action();
    } catch (_) {/* Repository publishes actionable error state. */}
  }

  Future<void> login() => _run(() => repository!.login());
  Future<void> bind({required bool confirmedFirstBind}) => _run(
      () => repository!.bindFirstTime(confirmedFirstBind: confirmedFirstBind));
  Future<void> syncTime(DateTime time) =>
      _run(() => repository!.syncTime(time));
  Future<void> setLanguage(int value) =>
      _run(() => repository!.setLanguageVerified(value));
  Future<void> setHeartRateStreaming(bool enabled) =>
      _run(() => repository!.setHeartRateStreaming(enabled));
  Future<JwHistoryResult> syncHistory(
      {JwHistoryOptions options = const JwHistoryOptions()}) {
    if (_closed || repository == null || state.operationInProgress) {
      return Future.error(StateError('JW history unavailable/already running'));
    }
    return repository!.syncHistory(options: options);
  }

  Future<void> cancelHistory() async {
    if (!_closed) {
      await repository?.cancelHistory();
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _subscription?.cancel();
    final current = repository;
    if (current != null) unawaited(current.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
