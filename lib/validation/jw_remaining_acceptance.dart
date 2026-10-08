import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../providers/ble_provider.dart';
import '../services/jw/jw_codec.dart';
import '../services/jw/jw_configuration.dart';
import '../services/jw/jw_device_repository.dart';
import '../services/jw/jw_models.dart';
import '../services/jw/jw_remaining_models.dart';
import '../services/jw/jw_transport.dart';
import 'jw_sdk_acceptance.dart';

String _hex(List<int> raw) =>
    raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
bool _equal(List<int> a, List<int> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

/// Fixed query values plus exact, pre-journaled mutation values. Never raw SDK reimplementation.
class JwRemainingWireAudit {
  final String mode, identityDigest;
  final bool allowRuntimeObservation;
  final allowedWrites = <String>{};
  final attempts = <Map<String, Object?>>[];
  String? violation;
  JwRemainingWireAudit(this.mode, this.identityDigest,
      {this.allowRuntimeObservation = false});
  static const _queries = {
    '2/54',
    '6/61',
    '2/79',
    '2/3',
    '2/59',
    '5/58',
    '2/43',
    '2/135',
    '2/72'
  };
  void permit(int command, int key, List<int> value) {
    final tag = '$command/$key';
    final routine = {'2/42', '2/134', '7/17'};
    final lab = {'2/2', '2/33', '2/16', '2/5', '2/6', '5/13', '5/45', '5/32'};
    if (!(mode == 'remaining-routine' && routine.contains(tag) ||
        mode == 'remaining-lab' && lab.contains(tag))) {
      throw StateError('Mutation outside group policy: $tag');
    }
    if (tag == '7/17' || tag == '5/13' || tag == '5/45' || tag == '5/32') {
      if (value.length != 1 || value.single > 1) {
        throw StateError('Control value outside policy');
      }
    }
    allowedWrites.add('$tag/${_hex(value)}');
  }

  Map<String, Object?> observe(JwFrame frame) {
    final e = <String, Object?>{
      'type': 'wireAttempt',
      'seq': frame.seq,
      'ack': frame.ack
    };
    try {
      if (frame.ack) {
        if (frame.error || frame.payload.isNotEmpty) {
          throw StateError('Invalid ACK');
        }
      } else {
        final m = JwCodec.decodeL2(frame.payload);
        if (m.fields.length != 1) throw StateError('Multiple fields');
        final f = m.fields.single;
        final tag = '${m.command}/${f.key}';
        final login = tag == '3/3' &&
            f.value.length == 32 &&
            sha256.convert(f.value).toString() == identityDigest;
        final sport = tag == '5/92' &&
            (_equal(f.value, [0, 255]) ||
                mode == 'remaining-lab' &&
                    allowedWrites.contains('$tag/${_hex(f.value)}'));
        final query = (_queries.contains(tag) && f.value.isEmpty) ||
            tag == '5/45' && _equal(f.value, [2]) ||
            (mode == 'remaining-lab' ||
                    mode == 'remaining-restart' && allowRuntimeObservation) &&
                tag == '2/38' &&
                f.value.isEmpty;
        final write = allowedWrites.contains('$tag/${_hex(f.value)}');
        e.addAll({
          'command': m.command,
          'key': f.key,
          'length': f.value.length,
          if (!login) 'value': _hex(f.value)
        });
        if (!login && !query && !sport && !write) {
          throw StateError('Forbidden outbound value $tag');
        }
      }
      e['allowed'] = true;
    } catch (error) {
      violation ??= error.toString();
      e.addAll({'allowed': false, 'error': error.toString()});
    }
    attempts.add(e);
    return e;
  }

  void permitSport(int action, int type) {
    if (mode != 'remaining-lab' ||
        action < 1 ||
        action > 4 ||
        (action == 1 ? type < 1 || type > 27 : type != 255)) {
      throw StateError('Sport policy');
    }
    allowedWrites.add('5/92/${_hex([action, type])}');
  }

  Map<String, Object?> observeAlert(JwImmediateAlertAttempt attempt) {
    final allowed = mode == 'remaining-routine' &&
        (attempt.level == 0 || attempt.level == 2);
    final e = <String, Object?>{
      'type': 'iasWireAttempt',
      'service': '1802',
      'characteristic': '2a06',
      'value': _hex([attempt.level]),
      'withResponse': attempt.withResponse,
      'allowed': allowed
    };
    if (!allowed) violation ??= 'IAS outside routine group';
    attempts.add(e);
    return e;
  }

  void check() {
    if (violation != null) throw StateError(violation!);
  }

  Map<String, Object?> get summary => {
        'status': violation == null ? 'pass' : 'fail',
        'attempts': attempts.length,
        'applicationAttempts': attempts.where((e) => e['ack'] == false).length,
        'ackAttempts': attempts.where((e) => e['ack'] == true).length,
        'iasAttempts':
            attempts.where((e) => e['type'] == 'iasWireAttempt').length,
        'forbiddenAttempts':
            attempts.where((e) => e['allowed'] == false).length,
        if (violation != null) 'error': violation
      };
}

class JwRemainingAcceptanceRunner {
  final JwRemainingAcceptancePort port;
  final AcceptanceConfig config;
  final Future<void> Function(Map<String, Object?>) record;
  final Future<void> Function(Duration) delay;
  final bool Function() isCancelled;
  late final audit = JwRemainingWireAudit(
      config.mode, config.expectedIdentitySha256!,
      allowRuntimeObservation: config.labAuthorized);
  final results = <Map<String, Object?>>[];
  final staticRaw = <String, String>{};
  final pending = <Future<void> Function()>[];
  Map<String, Object?>? device;
  bool restorePending = false, recoveryUsed = false;
  final unresolvedActivities = <String>{};
  ScanDevice? target;
  static const contract = JwConfigurationContract.v101S200;
  JwDeviceRepository get r => port.remainingRepository;
  JwRemainingAcceptanceRunner(
      {required this.port,
      required this.config,
      required this.record,
      required this.delay,
      required this.isCancelled});
  void _check() {
    audit.check();
    if (isCancelled()) throw StateError('Acceptance cancelled');
  }

  Future<void> _result(String name, Map<String, Object?> data,
      {String status = 'pass'}) async {
    final e = <String, Object?>{
      'type': 'step',
      'operation': name,
      'status': status,
      ...data
    };
    results.add(e);
    await record(e);
    audit.check();
  }

  Future<void> _scan() async {
    for (var attempt = 0; attempt < config.scanAttempts; attempt++) {
      _check();
      await record({'type': 'scanStart', 'attempt': attempt + 1});
      await port.startScan();
      final deadline = DateTime.now().add(config.scanWindow);
      do {
        _check();
        final matches = port.devices.where(config.matches).toList();
        if (matches.length > 1) {
          throw StateError('Ambiguous actual scan target');
        }
        if (matches.length == 1) {
          target = matches.single;
          port.stopScan();
          return;
        }
        await delay(const Duration(milliseconds: 250));
      } while (DateTime.now().isBefore(deadline));
      port.stopScan();
      await record({'type': 'scanWindowElapsed', 'attempt': attempt + 1});
    }
    throw StateError('Actual scan target absent');
  }

  Future<void> _connect() async {
    await port.connect(target!);
    await port.initialize();
    final state = port.state;
    if (state.phase != JwDevicePhase.loggedIn ||
        state.info?.firmware != 'T005' ||
        state.info?.hardware != 'H001' ||
        state.capabilities?.rawHex != '4dd17dfce34ad83d' ||
        state.capabilities?.factorySwitchRaw != 3 ||
        await port.identityDigest() != config.expectedIdentitySha256) {
      throw StateError('S200 profile/capability/identity gate failed');
    }
    device = {
      'address': target!.deviceId,
      'serial': state.info!.deviceKey,
      'firmware': state.info!.firmware,
      'hardware': state.info!.hardware,
      'functions': state.capabilities!.rawHex,
      'factory': state.capabilities!.factorySwitchRaw,
      'identitySha256': config.expectedIdentitySha256
    };
    audit.check();
  }

  Future<void> _observe() async {
    final alarms = await r.readAlarm(contract: contract);
    staticRaw['alarms'] = _hex(alarms.raw);
    await _result('readAlarm',
        {'raw': _hex(alarms.raw), 'records': alarms.records.length});
    final permission = await r.checkSpO2MeasureEnable(contract: contract);
    await _result('checkSpO2MeasureEnable', {
      'raw': _hex(permission.raw),
      'availableReported': permission.availableReported,
      'evidence': 'diagnostic reply, not measurement success'
    });
    final sports = await r.readSupportDeviceSport(contract: contract);
    staticRaw['sports'] = _hex(sports.raw);
    await _result('readSupportDeviceSport', {
      'raw': _hex(sports.raw),
      'mask': sports.mask,
      'ukTypes': sports.ukTypes
    });
    final state = await r.queryDeviceSportStatus(contract: contract);
    await _result('queryDeviceSportStatus', {
      'raw': _hex(state.raw),
      'result': state.result,
      'state': state.state,
      'sportType': state.sportType,
      'operationAccepted': state.operationAccepted
    });
    await _result('getCachedSupportedUkSportTypes',
        {'ukTypes': r.getCachedSupportedUkSportTypes(), 'wireFrames': 0});
  }

  bool _activityAttempted(String name, int checkpoint) {
    return audit.attempts.skip(checkpoint).any((e) {
      if (name == 'IAS') {
        return e['type'] == 'iasWireAttempt' && e['value'] == '02';
      }
      if (name == 'camera') {
        return e['command'] == 7 && e['key'] == 17 && e['value'] == '00';
      }
      if (name == 'sport') {
        return e['command'] == 5 &&
            e['key'] == 92 &&
            e['value'] is String &&
            (e['value'] as String).startsWith('01');
      }
      final key = switch (name) {
        'measurement.hr' => 13,
        'measurement.spo2' => 45,
        'measurement.temperature' => 32,
        _ => -1
      };
      return e['command'] == 5 && e['key'] == key && e['value'] == '01';
    });
  }

  Future<void> _ownedActivity<T>(String name, Future<T> Function() start,
      Future<void> Function(T) body, Future<void> Function() stop,
      {bool Function(T)? created}) async {
    final owner = r;
    final checkpoint = audit.attempts.length;
    var rejected = false;
    Object? primary;
    await record(
        {'type': 'activityIntent', 'activity': name, 'device': device});
    unresolvedActivities.add(name);
    try {
      final result = await start();
      if (created != null && !created(result)) {
        rejected = true;
        throw StateError('$name start did not create an owned activity');
      }
      await body(result);
    } catch (e) {
      primary = e;
      rethrow;
    } finally {
      if (rejected || !_activityAttempted(name, checkpoint)) {
        unresolvedActivities.remove(name);
      } else if (identical(owner, r) && owner.session.isOpen) {
        try {
          await stop();
          unresolvedActivities.remove(name);
          await record({'type': 'activityStopped', 'activity': name});
        } catch (e) {
          await record({
            'type': 'activityUnresolved',
            'activity': name,
            'reason': e.toString()
          });
          if (primary == null) rethrow;
        }
      } else {
        await record({
          'type': 'activityUnresolved',
          'activity': name,
          'reason':
              'Start may have arrived; session ended; ownership cannot be proven after reconnect'
        });
        if (primary == null) {
          throw StateError('$name cleanup unresolved after session ended');
        }
      }
    }
  }

  Future<void> _routine() async {
    final wrist = await r.readTurnOverWrist(contract: contract);
    staticRaw['wrist'] = _hex(wrist.raw);
    final heat = await r.queryHeatStressReminder(contract: contract);
    staticRaw['heat'] = _hex(heat.raw);
    await record({
      'type': 'restoreBackup',
      'device': device,
      'wrist': _hex(wrist.raw),
      'heat': _hex(heat.raw)
    });
    final wristTarget =
        JwTurnOverWristStatus(Uint8List.fromList([wrist.savedEnabled ? 0 : 1]));
    pending.add(() async {
      final current = await r.readTurnOverWrist(contract: contract);
      if (_equal(current.raw, wrist.raw)) return;
      if (!_equal(current.raw, wristTarget.raw)) {
        throw StateError('External wrist conflict during restore');
      }
      audit.permit(2, 42, wrist.raw);
      await r.setTurnOverWrist(wrist.savedEnabled,
          expectedCurrent: current, contract: contract);
      await record(
          {'type': 'restored', 'operation': 'wrist', 'raw': _hex(wrist.raw)});
    });
    audit.permit(2, 42, wristTarget.raw);
    final wristChange = await r.setTurnOverWrist(wristTarget.savedEnabled,
        expectedCurrent: wrist, contract: contract);
    await _result('setTurnOverWrist', {
      'before': _hex(wrist.raw),
      'requested': _hex(wristTarget.raw),
      'observed': _hex(wristChange.observed.raw)
    });
    if (heat.timeWindowEnabled &&
        heat.startMinutes < heat.endMinutes &&
        heat.endMinutes - heat.startMinutes >= 60) {
      final start = heat.startMinutes + 30;
      final bits = 0x400000 |
          ((start ~/ 60) << 17) |
          ((start % 60) << 11) |
          ((heat.endMinutes ~/ 60) << 6) |
          (heat.endMinutes % 60);
      final requested = JwHeatStressReminderStatus(
          Uint8List.fromList([bits >> 16, (bits >> 8) & 255, bits & 255]));
      pending.add(() async {
        final current = await r.queryHeatStressReminder(contract: contract);
        if (_equal(current.raw, heat.raw)) return;
        if (!_equal(current.raw, requested.raw)) {
          throw StateError('External heat conflict during restore');
        }
        audit.permit(2, 134, heat.raw);
        await r.setHeatStressReminder(heat,
            expectedCurrent: current, contract: contract);
        await record(
            {'type': 'restored', 'operation': 'heat', 'raw': _hex(heat.raw)});
      });
      audit.permit(2, 134, requested.raw);
      final change = await r.setHeatStressReminder(requested,
          expectedCurrent: heat, contract: contract);
      await _result('setHeatStressReminder', {
        'before': _hex(heat.raw),
        'requested': _hex(requested.raw),
        'observed': _hex(change.observed.raw),
        'policy': 'window narrowed, never disabled'
      });
    } else {
      await _result('setHeatStressReminder',
          {'reason': 'No bounded subset of actual heat window'},
          status: 'blocked');
    }
    audit.permit(7, 17, [0]);
    audit.permit(7, 17, [1]);
    await record({
      'type': 'ownedControlIntent',
      'operation': 'camera',
      'enable': '00',
      'disable': '01'
    });
    await _ownedActivity(
        'camera', () => r.setTakePhotoControl(true, contract: contract),
        (_) async {
      await delay(const Duration(seconds: 2));
      _check();
    }, () async {
      await r.setTakePhotoControl(false, contract: contract);
    });
    await _result('setTakePhotoControl', {
      'evidence':
          'start/stop ACK submission only, physical camera mode unverified'
    });
    try {
      await record({
        'type': 'ownedControlIntent',
        'operation': 'IAS',
        'enable': '02',
        'disable': '00'
      });
      await _ownedActivity('IAS', () => r.findDevice(true, contract: contract),
          (_) async {
        await delay(const Duration(seconds: 2));
        _check();
      }, () async {
        await r.findDevice(false, contract: contract);
      });
      await _result('findDevice', {
        'evidence':
            'native IAS write completion and separate GATT attempts; physical alert unverified'
      });
    } on JwConfigurationException catch (e) {
      if (e.stage != 'unsupported') rethrow;
      await _result(
          'findDevice', {'stage': e.stage, 'reason': e.cause.toString()},
          status: 'unsupported');
    }
  }

  Future<void> _lab() async {
    final originalAlarm = await r.readAlarm(contract: contract);
    staticRaw['alarms'] = _hex(originalAlarm.raw);
    var expectedAlarm = originalAlarm;
    final alarmKnown = <String>{_hex(originalAlarm.raw)};
    Future<void> alarmIntent(List<int> bytes) async {
      final predicted = JwAlarmTable(bytes).normalizedRaw;
      await record({
        'type': 'alarmWriteIntent',
        'before': _hex(expectedAlarm.raw),
        'requested': _hex(bytes),
        'predictedNormalized': _hex(predicted),
        'device': device
      });
      alarmKnown.add(_hex(predicted));
      audit.permit(2, 2, bytes);
    }

    final originalSit = await r.readLongSit(contract: contract);
    staticRaw['longSit'] = _hex(originalSit.raw);
    await _result('readLongSit', {
      'raw': _hex(originalSit.raw),
      'scheduleValid': originalSit.hasValidSchedule,
      'runtimeEffect': 'temporarily updates on_off'
    });
    await record({
      'type': 'restoreBackup',
      'device': device,
      'alarms': _hex(originalAlarm.raw),
      'longSit': _hex(originalSit.raw)
    });
    pending.add(() async {
      var current = await r.readAlarm(contract: contract);
      if (_equal(current.raw, originalAlarm.raw)) return;
      if (!alarmKnown.contains(_hex(current.raw))) {
        throw StateError('External alarm table conflict during restore');
      }
      while (current.records.length > originalAlarm.records.length) {
        final bytes = current.raw.take(current.raw.length - 5).toList();
        audit.permit(2, 2, bytes);
        current = (await r.deleteAlarm(current.records.length - 1,
                expectedCurrent: current, contract: contract))
            .observed;
      }
      while (current.records.length < originalAlarm.records.length) {
        final entry = originalAlarm.records[current.records.length];
        audit.permit(2, 2, [...current.raw, ...entry.raw]);
        current = (await r.addAlarm(entry,
                expectedCurrent: current, contract: contract))
            .observed;
      }
      for (var i = 0; i < originalAlarm.records.length; i++) {
        if (!_equal(current.records[i].raw, originalAlarm.records[i].raw)) {
          final bytes = [
            ...current.raw.take(i * 5),
            ...originalAlarm.records[i].raw,
            ...current.raw.skip((i + 1) * 5)
          ];
          audit.permit(2, 2, bytes);
          current = (await r.modifyAlarm(i, originalAlarm.records[i],
                  expectedCurrent: current, contract: contract))
              .observed;
        }
      }
      if (!_equal(current.raw, originalAlarm.raw)) {
        throw StateError('Alarm restore differs from original');
      }
      await record({
        'type': 'restored',
        'operation': 'alarms',
        'raw': _hex(current.raw)
      });
    });
    if (originalAlarm.roundTrippable && originalAlarm.records.length < 20) {
      // A repeating entry avoids firmware's one-shot reserved normalization. Immediately removed.
      final entry = JwAlarmRecord([0x69, 0x42, 0x70, 0x38, 0x7f]);
      await alarmIntent([...expectedAlarm.raw, ...entry.raw]);
      expectedAlarm = (await r.addAlarm(entry,
              expectedCurrent: expectedAlarm, contract: contract))
          .observed;
      await _result('addAlarm', {
        'raw': _hex(expectedAlarm.raw),
        'records': expectedAlarm.records.length
      });
      final index = expectedAlarm.records.length - 1;
      final modified = JwAlarmRecord([0x69, 0x42, 0x80, 0x38, 0x7f]);
      await alarmIntent(
          [...expectedAlarm.raw.take(index * 5), ...modified.raw]);
      expectedAlarm = (await r.modifyAlarm(index, modified,
              expectedCurrent: expectedAlarm, contract: contract))
          .observed;
      await _result('modifyAlarm', {'raw': _hex(expectedAlarm.raw)});
      await alarmIntent(originalAlarm.raw);
      expectedAlarm = (await r.deleteAlarm(index,
              expectedCurrent: expectedAlarm, contract: contract))
          .observed;
      await _result('deleteAlarm', {
        'raw': _hex(expectedAlarm.raw),
        'originalRetained': _equal(expectedAlarm.raw, originalAlarm.raw)
      });
    } else {
      for (final name in ['addAlarm', 'modifyAlarm', 'deleteAlarm']) {
        await _result(
            name,
            {
              'reason': originalAlarm.roundTrippable
                  ? 'Actual legacy table full'
                  : 'Retained one-shot rows cannot round-trip; whole-table writes blocked'
            },
            status: 'blocked');
      }
    }
    // The dedicated lab may have disabled legacy step-limit bytes in the TUYA
    // minute slots. Use a valid explicit trial, then restore exact disabled raw.
    final trialBytes = originalSit.raw.toList();
    if (!originalSit.enabled && !originalSit.hasValidSchedule) {
      trialBytes[1] = 1;
      if (trialBytes[2] > 59) trialBytes[2] = 0;
      if (trialBytes[3] > 59) trialBytes[3] = 0;
      if (trialBytes[5] > 23) trialBytes[5] = 9;
      if (trialBytes[6] > 23) trialBytes[6] = 18;
    } else {
      trialBytes[1] = originalSit.enabled ? 0 : 1;
    }
    final sitTarget = JwLongSitSettings(trialBytes);
    await record({
      'type': 'longSitWriteIntent',
      'before': _hex(originalSit.raw),
      'requested': _hex(sitTarget.raw),
      'originalScheduleValid': originalSit.hasValidSchedule,
      'policy': 'valid active trial; exact dormant disabled raw restored',
    });
    pending.add(() async {
      final current = await r.readLongSit(contract: contract);
      if (_equal(current.raw, originalSit.raw)) return;
      if (!_equal(current.raw, sitTarget.raw)) {
        throw StateError('External long-sit conflict during restore');
      }
      audit.permit(2, 33, originalSit.raw);
      await r.setLongSit(originalSit,
          expectedCurrent: current, contract: contract);
      await record({
        'type': 'restored',
        'operation': 'longSit',
        'raw': _hex(originalSit.raw),
        'timerRestorable': false
      });
    });
    audit.permit(2, 33, sitTarget.raw);
    final sitChange = await r.setLongSit(sitTarget,
        expectedCurrent: originalSit, contract: contract);
    await _result('setLongSit', {
      'requested': _hex(sitTarget.raw),
      'observed': _hex(sitChange.observed.raw),
      'timerRestorable': false
    });
    final profile = [0x9e, 0xaf, 0x11, 0x80];
    audit.permit(2, 16, profile);
    audit.permit(2, 5, [0, 0, 0x27, 0x10]);
    audit.permit(2, 6, [1, 0xe0]);
    await record({
      'type': 'labDataIntent',
      'operation': 'syncUserInfo',
      'gender': 1,
      'age': 30,
      'heightCm': 175,
      'weightKg': 70,
      'targetSteps': 10000,
      'targetSleepMinutes': 480,
      'originalUnavailable': true,
      'algorithmResetPossible': true
    });
    final info = await r.syncUserInfo(
        gender: 1,
        age: 30,
        heightCm: 175,
        weightKg: 70,
        targetSteps: 10000,
        targetSleepMinutes: 480,
        contract: contract);
    await _result('syncUserInfo', {
      'submissions': info.submissions
          .map((s) => {
                'command': s.command,
                'key': s.key,
                'raw': _hex(s.raw),
                'acknowledged': s.acknowledged
              })
          .toList(),
      'evidence': 'transport ACK, profile has no query/restore'
    });
    for (final kind in ['hr', 'spo2', 'temperature']) {
      final key = switch (kind) { 'hr' => 13, 'spo2' => 45, _ => 32 };
      audit.permit(5, key, [1]);
      audit.permit(5, key, [0]);
      Future<JwSubmission> control(bool on) => switch (kind) {
            'hr' => r.controlHeartRateMeasurement(on, contract: contract),
            'spo2' => r.controlSpO2Measurement(on, contract: contract),
            _ => r.controlTemperatureMeasurement(on, contract: contract)
          };
      await record({
        'type': 'ownedMeasurementIntent',
        'kind': kind,
        'recordsAuthorized': true
      });
      late JwSubmission start;
      await _ownedActivity('measurement.$kind', () async {
        start = await control(true);
        return start;
      }, (_) async {
        await delay(const Duration(seconds: 3));
        _check();
      }, () async {
        await control(false);
      });
      await _result(
          switch (kind) {
            'hr' => 'controlHeartRateMeasurement',
            'spo2' => 'controlSpO2Measurement',
            _ => 'controlTemperatureMeasurement'
          },
          {
            'acknowledged': start.acknowledged,
            'response':
                start.responseRaw == null ? null : _hex(start.responseRaw!),
            'evidence':
                'start/stop submission; physical sample accuracy unverified'
          });
    }
    try {
      await r.controlBloodPressureMeasurement(true, contract: contract);
      throw StateError('Unexpected manual BP acceptance');
    } on JwConfigurationException catch (e) {
      if (e.stage != 'unsupported') rethrow;
      await _result('controlBloodPressureMeasurement',
          {'reason': e.cause.toString(), 'wireFrames': 0},
          status: 'unsupported');
    }
    final types = r.getCachedSupportedUkSportTypes()!;
    if (types.isEmpty) throw StateError('No actual supported sport type');
    final type = types.contains(5) ? 5 : types.first;
    audit.permitSport(1, type);
    for (final a in [2, 3, 4]) {
      audit.permitSport(a, 255);
    }
    await record({
      'type': 'ownedSportIntent',
      'ukType': type,
      'newTrialRecordsAuthorized': true
    });

    await _ownedActivity<JwSportStatus>('sport', () async {
      final start = await r.startDeviceSport(type, contract: contract);
      await _result(
          'startDeviceSport', {'raw': _hex(start.raw), 'result': start.result},
          status: start.result == 0 ? 'pass' : 'deviceRejected');
      return start;
    }, (start) async {
      await delay(const Duration(seconds: 2));
      _check();
      final pause = await r.pauseDeviceSport(contract: contract);
      if (!pause.operationAccepted || pause.state != 2) {
        throw StateError('Sport pause rejected');
      }
      await _result('pauseDeviceSport', {'raw': _hex(pause.raw)});
      final resume = await r.resumeDeviceSport(contract: contract);
      if (!resume.operationAccepted || resume.state != 1) {
        throw StateError('Sport resume rejected');
      }
      await _result('resumeDeviceSport', {'raw': _hex(resume.raw)});
    }, () async {
      final stop = await r.stopDeviceSport(contract: contract);
      if (!stop.operationAccepted || stop.state != 0) {
        throw StateError('Sport stop rejected');
      }
      await _result('stopDeviceSport',
          {'raw': _hex(stop.raw), 'trialHistoryMayPersist': true});
    },
        created: (start) =>
            start.operationAccepted &&
            start.result == 0 &&
            start.state == 1 &&
            start.sportType == type);
    for (final name in [
      'setSocialReminder',
      'setDisturb',
      'setHeartRateReminder'
    ]) {
      await _result(
          name,
          {
            'reason': name == 'setHeartRateReminder'
                ? 'Shared FTL unsafe current contract'
                : 'Pairing risk excluded from hardware authorization',
            'wireFrames': 0
          },
          status: 'excluded');
    }
  }

  Future<void> _restore() async {
    restorePending = pending.isNotEmpty || unresolvedActivities.isNotEmpty;
    if (pending.isEmpty) return;
    if (!r.session.isOpen) {
      recoveryUsed = true;
      await record({'type': 'recoveryReconnect', 'device': device});
      await port.disconnect();
      await _connect();
    }
    final failures = <String>[];
    for (final restore in pending.reversed) {
      try {
        await restore();
      } catch (e) {
        failures.add(e.toString());
        await record(
            {'type': 'independentRestoreFailure', 'error': e.toString()});
      }
    }
    if (failures.isNotEmpty) {
      throw StateError('Independent restore failures: ${failures.join('; ')}');
    }
    pending.clear();
    restorePending = unresolvedActivities.isNotEmpty;
  }

  Future<void> _restart() async {
    if (config.remainingBaselineFile == null) {
      throw StateError('Restart requires original remaining result');
    }
    final file = File(config.remainingBaselineFile!);
    if (await file.length() > 1024 * 1024) {
      throw StateError('Baseline too large');
    }
    final b = jsonDecode(await file.readAsString()) as Map;
    if (b['schemaVersion'] != 5 ||
        b['status'] != 'pass' ||
        b['exitCode'] != 0 ||
        b['remainingWireAudit'] is! Map ||
        (b['remainingWireAudit'] as Map)['status'] != 'pass' ||
        b['remainingDevice'] is! Map ||
        b['remainingStaticRaw'] is! Map) {
      throw StateError('Invalid remaining restart baseline');
    }
    for (final e in device!.entries) {
      if ((b['remainingDevice'] as Map)[e.key] != e.value) {
        throw StateError('Restart device attribution differs');
      }
    }
    final saved = b['remainingStaticRaw'] as Map;
    final wrist = await r.readTurnOverWrist(contract: contract);
    final heat = await r.queryHeatStressReminder(contract: contract);
    staticRaw['wrist'] = _hex(wrist.raw);
    staticRaw['heat'] = _hex(heat.raw);
    if (saved.containsKey('longSit')) {
      if (!config.labAuthorized) {
        throw StateError(
            'Runtime-mutating long-sit restart requires existing lab authorization');
      }
      staticRaw['longSit'] =
          _hex((await r.readLongSit(contract: contract)).raw);
    }
    for (final e in saved.entries) {
      if (staticRaw[e.key] != e.value) {
        throw StateError('Restart static value differs ${e.key}');
      }
    }
    await _result('independentRestart',
        {'staticRetained': true, 'baselineMode': b['mode']});
  }

  Future<Map<String, Object?>> run() async {
    StreamSubscription? frames, alerts;
    String? error;
    var code = 0;
    try {
      if (config.mode == 'remaining-lab' && !config.labAuthorized) {
        throw StateError(
            'Explicit dedicated-test-device lab authorization flag required');
      }
      frames = port.outgoingFrames.listen((f) {
        final e = audit.observe(f);
        unawaited(record(e).catchError((Object failure) {
          audit.violation ??= 'Wire journal failed: $failure';
        }));
      });
      alerts = port.immediateAlertAttempts.listen((a) {
        final e = audit.observeAlert(a);
        unawaited(record(e).catchError((Object failure) {
          audit.violation ??= 'IAS journal failed: $failure';
        }));
      });
      await port.prepareReadOnlyIdentity(config.expectedIdentitySha256!);
      await _scan();
      await _connect();
      await _observe();
      if (config.mode == 'remaining-routine') await _routine();
      if (config.mode == 'remaining-lab') await _lab();
      if (config.mode == 'remaining-restart') await _restart();
    } catch (e) {
      error = e.toString();
      code = 1;
      await record({
        'type': 'failure',
        'error': error,
        if (e is JwConfigurationException) 'stage': e.stage,
        if (e is JwConfigurationException) 'raw': _hex(e.raw),
      });
    } finally {
      try {
        await _restore();
      } catch (e) {
        error = '${error ?? ''}; restore pending: $e';
        code = 1;
        restorePending = true;
        await record({'type': 'restoreFailure', 'error': e.toString()});
      }
      try {
        await port.disconnect();
      } catch (e) {
        error ??= e.toString();
        code = 1;
      }
      await frames?.cancel();
      await alerts?.cancel();
      try {
        await port.close();
      } catch (e) {
        error ??= e.toString();
        code = 1;
      }
    }
    if (audit.violation != null) {
      code = 1;
      error ??= audit.violation;
    }
    final result = <String, Object?>{
      'schemaVersion': 5,
      'mode': config.mode,
      'status': code == 0 ? 'pass' : 'fail',
      'exitCode': code,
      'remainingDevice': device,
      'remainingResults': results,
      'remainingWireAudit': audit.summary,
      'remainingStaticRaw': staticRaw,
      'restorePending': restorePending,
      'recoveryUsed': recoveryUsed,
      'remainingUnresolvedActivities': unresolvedActivities.toList()..sort(),
      'identitySha256': config.expectedIdentitySha256,
      'exclusions': [
        'notification/DND pairing',
        'high-HR shared FTL',
        'manual BP bit33 false'
      ],
      if (error != null) 'error': error
    };
    await record(
        {'type': 'finished', 'status': result['status'], 'exitCode': code});
    return result;
  }
}
