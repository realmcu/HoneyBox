import 'dart:async';
import '../connection/connection_state.dart';
import '../debug/models.dart';
import '../errors.dart';
import '../model/display_format.dart';
import '../model/language.dart';
import '../model/setting_values.dart';
import '../model/feature.dart';
import '../model/wall_clock.dart';
import '../protocol/cmd_02_settings.dart';
import '../session/session.dart';

/// Last values actually read or notified by the device, not optimistic writes.
class WSSettingsSnapshot {
  const WSSettingsSnapshot({this.language, this.displayFormat, this.time});
  final WSLanguage? language;
  final WSDisplayFormat? displayFormat;
  final WSWallClock? time;
}

abstract interface class WSSettings {
  Future<void> setTime([WSWallClock? time]);
  Future<void> setLanguage(WSLanguage language);
  Future<WSLanguage> getLanguage();
  Future<WSDisplayFormat> getDisplayFormat();
  Future<void> setDisplayFormat(WSDisplayFormat value);
  Future<void> setHourSystem(WSHourSystem value);
  Future<WSHourSystem> getHourSystem();
  Future<void> setDistanceUnit(WSDistanceUnit value);
  Future<WSDistanceUnit> getDistanceUnit();
  WSFeatureSupport get languageSupport;
  WSFeatureSupport get displayFormatSupport;
  WSSettingsSnapshot get observed;
  Stream<WSSettingsSnapshot> get changes;
}

/// Internal adapter: features check readiness/capability; Session owns ordering.
class WSSettingsController implements WSSettings {
  WSSettingsController(
      {required this.requireSession,
      required this.support,
      required this.now,
      required Stream<WSConnectionChange> states}) {
    _states = states.listen((_) => _refreshSession());
    _refreshSession();
  }
  final WSSession Function() requireSession;
  final WSFeatureSupport Function(WSFeature feature) support;
  final DateTime Function() now;
  StreamSubscription<WSDeviceReport>? _reports;
  WSSession? _observingSession;
  late final StreamSubscription<WSConnectionChange> _states;
  final _changes = StreamController<WSSettingsSnapshot>.broadcast();
  bool _disposed = false;
  Future<void>? _disposing;
  WSSettingsSnapshot _observed = const WSSettingsSnapshot();
  @override
  WSSettingsSnapshot get observed => _observed;
  @override
  Stream<WSSettingsSnapshot> get changes => _changes.stream;
  @override
  WSFeatureSupport get languageSupport => support(WSFeature.language);
  @override
  WSFeatureSupport get displayFormatSupport => support(WSFeature.displayFormat);
  bool _ready([WSSession? expected]) {
    if (_disposed) return false;
    try {
      final session = requireSession();
      return expected == null || identical(session, expected);
    } on WSException {
      return false;
    }
  }

  void _refreshSession() {
    if (_disposed) return;
    WSSession? session;
    try {
      session = requireSession();
    } on WSException {/* Not ready. */}
    _observeSession(session);
  }

  void _observeSession(WSSession? session) {
    if (identical(session, _observingSession)) return;
    final previous = _reports;
    if (previous != null) unawaited(previous.cancel());
    _observingSession = session;
    _publish(const WSSettingsSnapshot());
    _reports = session?.reports.listen((report) {
      if (_ready(session)) _report(report);
    });
  }

  void _publish(WSSettingsSnapshot value) {
    if (_disposed) return;
    _observed = value;
    _changes.add(value);
  }

  Future<T> _run<T>(
      WSFeature? feature,
      Future<T> Function(WSSessionTransaction tx, WSSession session)
          action) async {
    if (_disposed) throw const WSDisposedException();
    final session = requireSession(); // Capture this generation before queuing.
    _observeSession(session);
    if (feature != null && support(feature) == WSFeatureSupport.unsupported) {
      throw WSUnsupportedException(feature);
    }
    return session.transaction((tx) => action(tx, session));
  }

  void _language(WSLanguage language) => _publish(WSSettingsSnapshot(
      language: language,
      displayFormat: _observed.displayFormat,
      time: _observed.time));
  void _display(WSDisplayFormat display) => _publish(WSSettingsSnapshot(
      language: _observed.language,
      displayFormat: display,
      time: _observed.time));
  void _report(WSDeviceReport report) {
    final a = report.address;
    if (!_ready() ||
        report.kind != WSReportKind.notification ||
        a == null ||
        a.cmd != 2 ||
        a.version != 0 ||
        a.settingOpcode != 3) {
      return;
    }
    if (a.key == 3 && report.value is int) {
      _language(WSLanguage(report.value! as int));
    }
    if (a.key == 4 && report.value is WSDisplayFormat) {
      _display(report.value! as WSDisplayFormat);
    }
    if (a.key == 1 && report.value is WSWallClock) {
      _publish(WSSettingsSnapshot(
          language: _observed.language,
          displayFormat: _observed.displayFormat,
          time: report.value! as WSWallClock));
    }
  }

  @override
  Future<void> setTime([WSWallClock? time]) => _run(
      null,
      (tx, _) => tx.send(
          WSSettingsProtocol.setTime, time ?? WSWallClock.fromCalendar(now())));
  @override
  Future<void> setLanguage(WSLanguage language) => _run(WSFeature.language,
      (tx, _) => tx.send(WSSettingsProtocol.setLanguage, language.code));
  @override
  Future<WSLanguage> getLanguage() =>
      _run(WSFeature.language, (tx, session) async {
        final value =
            WSLanguage(await tx.query(WSSettingsProtocol.getLanguage, null));
        if (_ready(session)) _language(value);
        return value;
      });
  Future<WSDisplayFormat> _readDisplay(
      WSSessionTransaction tx, WSSession session) async {
    final value = await tx.query(WSSettingsProtocol.getDisplayFormat, null);
    if (_ready(session)) _display(value);
    return value;
  }

  @override
  Future<WSDisplayFormat> getDisplayFormat() =>
      _run(WSFeature.displayFormat, _readDisplay);
  @override
  Future<void> setDisplayFormat(WSDisplayFormat value) => _run(
      WSFeature.displayFormat,
      (tx, _) => tx.send(WSSettingsProtocol.setDisplayFormat, value));
  Future<void> _modify(WSDisplayFormat Function(WSDisplayFormat) change) =>
      _run(WSFeature.displayFormat, (tx, session) async {
        final current = await _readDisplay(tx, session);
        await tx.send(WSSettingsProtocol.setDisplayFormat, change(current));
      });
  @override
  Future<void> setHourSystem(WSHourSystem value) =>
      _modify((current) => current.copyWith(hourSystem: value));
  @override
  Future<WSHourSystem> getHourSystem() async =>
      (await getDisplayFormat()).hourSystem;
  @override
  Future<void> setDistanceUnit(WSDistanceUnit value) =>
      _modify((current) => current.copyWith(distanceUnit: value));
  @override
  Future<WSDistanceUnit> getDistanceUnit() async =>
      (await getDisplayFormat()).distanceUnit;

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    _observed = const WSSettingsSnapshot();
    await _reports?.cancel();
    _observingSession = null;
    await _states.cancel();
    await _changes.close();
  }
}
