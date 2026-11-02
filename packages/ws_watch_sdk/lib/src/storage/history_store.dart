import 'package:drift/drift.dart';
import '../db/database.dart';
import '../model/history.dart';
import '../model/sync.dart';
import '../model/wall_clock.dart';

class WSHistoryScope {
  const WSHistoryScope(
      {required this.deviceId,
      required this.userId,
      required this.syncedAt,
      required this.tzOffsetMinutes});
  final String deviceId, userId;
  final DateTime syncedAt;
  final int tzOffsetMinutes;
}

class WSHistoryWriteResult {
  const WSHistoryWriteResult(this.committed, this.inserted, this.duplicates);
  final int committed, inserted, duplicates;
}

abstract interface class WSHistoryStore {
  Future<WSHistoryWriteResult> writeHistory(
      WSHistoryScope scope, List<WSHistorySample> samples);
  Future<List<WSStepRecord>> querySteps(WSRecordQuery query);
  Future<List<WSHeartRateRecord>> queryHeartRate(WSRecordQuery query);
  Future<int> deleteSteps(WSRecordQuery query);
  Future<int> deleteHeartRate(WSRecordQuery query);
  Future<void> saveSyncLog(WSSyncLog log);
  Future<List<WSSyncLog>> querySyncLogs(
      String deviceId, String? userId, int limit);
}

mixin WSDriftHistoryStore implements WSHistoryStore {
  WSDatabase get database;
  @override
  Future<WSHistoryWriteResult> writeHistory(
          WSHistoryScope scope, List<WSHistorySample> samples) =>
      database.transaction(() async {
        var inserted = 0;
        for (final sample in samples) {
          if (sample is WSStepSample) {
            final t = database.stepRecords;
            final existing = await (database.select(t)
                  ..where((t) =>
                      t.deviceId.equals(scope.deviceId) &
                      t.userId.equals(scope.userId) &
                      t.recordTime.equals(sample.recordTime.seconds)))
                .getSingleOrNull();
            if (existing == null) inserted++;
            await database.into(t).insertOnConflictUpdate(
                StepRecordsCompanion.insert(
                    id: existing == null
                        ? const Value.absent()
                        : Value(existing.id),
                    deviceId: scope.deviceId,
                    userId: scope.userId,
                    recordTime: sample.recordTime.seconds,
                    mode: sample.mode,
                    steps: Value(sample.steps ?? existing?.steps),
                    bucketMinutes: sample.bucketMinutes,
                    averageHeartRate: Value(
                        sample.averageHeartRate ?? existing?.averageHeartRate),
                    flags: sample.flags,
                    caloriesDeciKcal: Value(
                        sample.caloriesDeciKcal ?? existing?.caloriesDeciKcal),
                    distanceMeters: Value(
                        sample.distanceMeters ?? existing?.distanceMeters),
                    tzOffsetMinutes: scope.tzOffsetMinutes,
                    syncedAt: scope.syncedAt.millisecondsSinceEpoch,
                    raw: sample.raw));
          } else if (sample is WSHeartRateSample) {
            final t = database.heartRateRecords;
            final existing = await (database.select(t)
                  ..where((t) =>
                      t.deviceId.equals(scope.deviceId) &
                      t.userId.equals(scope.userId) &
                      t.recordTime.equals(sample.recordTime.seconds)))
                .getSingleOrNull();
            if (existing == null) inserted++;
            await database.into(t).insertOnConflictUpdate(
                HeartRateRecordsCompanion.insert(
                    id: existing == null
                        ? const Value.absent()
                        : Value(existing.id),
                    deviceId: scope.deviceId,
                    userId: scope.userId,
                    recordTime: sample.recordTime.seconds,
                    bpm: Value(sample.bpm ?? existing?.bpm),
                    sourceKey: sample.sourceKey,
                    tzOffsetMinutes: scope.tzOffsetMinutes,
                    syncedAt: scope.syncedAt.millisecondsSinceEpoch,
                    raw: sample.raw));
          }
        }
        return WSHistoryWriteResult(
            samples.length, inserted, samples.length - inserted);
      });
  Expression<bool> _where(WSRecordQuery q, GeneratedColumn<String> device,
      GeneratedColumn<String> user, GeneratedColumn<int> time) {
    Expression<bool> filter = device.equals(q.deviceId);
    if (q.userId != null) filter &= user.equals(q.userId!);
    if (q.from != null) filter &= time.isBiggerOrEqualValue(q.from!.seconds);
    if (q.to != null) filter &= time.isSmallerThanValue(q.to!.seconds);
    return filter;
  }

  Future<List<StepRecord>> _steps(WSRecordQuery q) {
    final t = database.stepRecords;
    final select = database.select(t)
      ..where((t) => _where(q, t.deviceId, t.userId, t.recordTime))
      ..orderBy([
        (t) => OrderingTerm(
            expression: t.recordTime,
            mode: q.descending ? OrderingMode.desc : OrderingMode.asc),
        (t) => OrderingTerm(
            expression: t.id,
            mode: q.descending ? OrderingMode.desc : OrderingMode.asc)
      ]);
    if (q.limit != null) select.limit(q.limit!);
    return select.get();
  }

  Future<List<HeartRateRecord>> _heartRate(WSRecordQuery q) {
    final t = database.heartRateRecords;
    final select = database.select(t)
      ..where((t) => _where(q, t.deviceId, t.userId, t.recordTime))
      ..orderBy([
        (t) => OrderingTerm(
            expression: t.recordTime,
            mode: q.descending ? OrderingMode.desc : OrderingMode.asc),
        (t) => OrderingTerm(
            expression: t.id,
            mode: q.descending ? OrderingMode.desc : OrderingMode.asc)
      ]);
    if (q.limit != null) select.limit(q.limit!);
    return select.get();
  }

  @override
  Future<List<WSStepRecord>> querySteps(WSRecordQuery q) async =>
      (await _steps(q))
          .map((r) => WSStepRecord(
              id: r.id,
              deviceId: r.deviceId,
              userId: r.userId,
              tzOffsetMinutes: r.tzOffsetMinutes,
              syncedAt: DateTime.fromMillisecondsSinceEpoch(r.syncedAt),
              sample: WSStepSample(
                  recordTime: WSWallClock.fromSeconds(r.recordTime),
                  raw: r.raw,
                  mode: r.mode,
                  steps: r.steps,
                  bucketMinutes: r.bucketMinutes,
                  averageHeartRate: r.averageHeartRate,
                  flags: r.flags,
                  caloriesDeciKcal: r.caloriesDeciKcal,
                  distanceMeters: r.distanceMeters)))
          .toList(growable: false);
  @override
  Future<List<WSHeartRateRecord>> queryHeartRate(WSRecordQuery q) async =>
      (await _heartRate(q))
          .map((r) => WSHeartRateRecord(
              id: r.id,
              deviceId: r.deviceId,
              userId: r.userId,
              tzOffsetMinutes: r.tzOffsetMinutes,
              syncedAt: DateTime.fromMillisecondsSinceEpoch(r.syncedAt),
              sample: WSHeartRateSample(
                  recordTime: WSWallClock.fromSeconds(r.recordTime),
                  raw: r.raw,
                  bpm: r.bpm)))
          .toList(growable: false);
  @override
  Future<int> deleteSteps(WSRecordQuery q) => database.transaction(() async {
        final rows = await _steps(q);
        if (rows.isEmpty) return 0;
        return (database.delete(database.stepRecords)
              ..where((t) => t.id.isIn(rows.map((r) => r.id))))
            .go();
      });
  @override
  Future<int> deleteHeartRate(WSRecordQuery q) =>
      database.transaction(() async {
        final rows = await _heartRate(q);
        if (rows.isEmpty) return 0;
        return (database.delete(database.heartRateRecords)
              ..where((t) => t.id.isIn(rows.map((r) => r.id))))
            .go();
      });
  @override
  Future<void> saveSyncLog(WSSyncLog log) async {
    final t = database.syncLogs;
    final row = SyncLogsCompanion.insert(
        deviceId: log.deviceId,
        userId: log.userId,
        syncId: log.syncId,
        startedAt: log.startedAt.millisecondsSinceEpoch,
        endedAt: log.endedAt.millisecondsSinceEpoch,
        announcedJson: log.announcedJson,
        receivedJson: log.receivedJson,
        deviceResultCode: Value(log.deviceResultCode),
        confirmation: log.confirmation.name,
        result: log.result.name,
        reason: Value(log.reason));
    await database
        .into(t)
        .insert(row, onConflict: DoUpdate((_) => row, target: [t.syncId]));
  }

  @override
  Future<List<WSSyncLog>> querySyncLogs(
      String deviceId, String? userId, int limit) async {
    final select = database.select(database.syncLogs)
      ..where((t) =>
          t.deviceId.equals(deviceId) &
          (userId == null ? const Constant(true) : t.userId.equals(userId)))
      ..orderBy([
        (t) => OrderingTerm.desc(t.startedAt),
        (t) => OrderingTerm.desc(t.id)
      ])
      ..limit(limit);
    return (await select.get())
        .map((r) => WSSyncLog(
            deviceId: r.deviceId,
            userId: r.userId,
            syncId: r.syncId,
            startedAt: DateTime.fromMillisecondsSinceEpoch(r.startedAt),
            endedAt: DateTime.fromMillisecondsSinceEpoch(r.endedAt),
            announcedJson: r.announcedJson,
            receivedJson: r.receivedJson,
            deviceResultCode: r.deviceResultCode,
            confirmation: WSSyncConfirmation.values.byName(r.confirmation),
            result: WSSyncStatus.values.byName(r.result),
            reason: r.reason))
        .toList(growable: false);
  }
}
