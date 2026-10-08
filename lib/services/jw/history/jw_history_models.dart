import 'dart:convert';
import 'package:crypto/crypto.dart';

enum JwHistoryType {
  steps,
  sleep,
  heartTemperature,
  bloodPressure,
  exercise,
  bloodOxygen,
  hrv,
  pressure,
  metabolism,
  readiness
}

enum JwHistoryPhase {
  idle,
  starting,
  receivingTraditional,
  receivingModern,
  committing,
  confirming,
  completed,
  failed,
  cancelled,
  disconnected
}

class JwHistoryOptions {
  final Duration idleTimeout, totalTimeout;
  final int maxQueuedBytes;
  const JwHistoryOptions(
      {this.idleTimeout = const Duration(seconds: 30),
      this.totalTimeout = const Duration(seconds: 1800),
      this.maxQueuedBytes = 32 * 1024 * 1024});
  void validate() {
    if (idleTimeout <= Duration.zero ||
        totalTimeout < idleTimeout ||
        maxQueuedBytes < 244) {
      throw ArgumentError('Invalid history limits');
    }
  }
}

/// A canonical representation shared by record identity and journal checksums.
String jwHistoryCanonicalJson(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k as String).toList()..sort();
      return {for (final key in keys) key: sorted(v[key])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return jsonEncode(sorted(value));
}

String jwHistoryDigest(Object? value) =>
    sha256.convert(utf8.encode(jwHistoryCanonicalJson(value))).toString();

class JwHistoryRecord {
  final String deviceKey, sourceIdentity, sourceTimeBasis, day, rawHex;
  final String firstSeenBatch, recordId, rawSha256;
  final JwHistoryType type;
  final int key, wireVersion, firstSeenOrdinal;
  final Map<String, Object?> values, sourceTime;
  final Map<String, bool> validity;
  JwHistoryRecord(
      {required this.deviceKey,
      required this.type,
      required this.key,
      required this.wireVersion,
      required this.sourceIdentity,
      required this.sourceTimeBasis,
      required this.day,
      required this.rawHex,
      required this.firstSeenBatch,
      required this.firstSeenOrdinal,
      required Map<String, Object?> values,
      required Map<String, Object?> sourceTime,
      required Map<String, bool> validity})
      : values = Map.unmodifiable(values),
        sourceTime = Map.unmodifiable(sourceTime),
        validity = Map.unmodifiable(validity),
        rawSha256 = sha256.convert([
          for (var i = 0; i < rawHex.length; i += 2)
            int.parse(rawHex.substring(i, i + 2), radix: 16)
        ]).toString(),
        recordId = jwHistoryDigest([
          deviceKey,
          type.name,
          sourceIdentity,
          sha256.convert([
            for (var i = 0; i < rawHex.length; i += 2)
              int.parse(rawHex.substring(i, i + 2), radix: 16)
          ]).toString()
        ]);

  factory JwHistoryRecord.fromJson(Map<String, Object?> json) {
    try {
      final raw = json['rawHex'] as String;
      if (raw.isEmpty ||
          raw.length.isOdd ||
          !RegExp(r'^[0-9a-f]+$').hasMatch(raw)) {
        throw const FormatException('History raw hex');
      }
      final row = JwHistoryRecord(
          deviceKey: json['deviceKey'] as String,
          type: JwHistoryType.values.byName(json['type'] as String),
          key: json['key'] as int,
          wireVersion: json['wireVersion'] as int,
          sourceIdentity: json['sourceIdentity'] as String,
          sourceTimeBasis: json['sourceTimeBasis'] as String,
          day: json['day'] as String,
          rawHex: raw,
          firstSeenBatch: json['firstSeenBatch'] as String,
          firstSeenOrdinal: json['firstSeenOrdinal'] as int,
          values: Map<String, Object?>.from(json['values'] as Map),
          sourceTime: Map<String, Object?>.from(json['sourceTime'] as Map),
          validity: Map<String, bool>.from(json['validity'] as Map));
      if (row.recordId != json['recordId'] ||
          row.rawSha256 != json['rawSha256']) {
        throw const FormatException('History identity/raw checksum');
      }
      return row;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('History record schema: $e');
    }
  }

  Map<String, Object?> toJson() => {
        'recordId': recordId,
        'deviceKey': deviceKey,
        'type': type.name,
        'key': key,
        'wireVersion': wireVersion,
        'sourceTimeBasis': sourceTimeBasis,
        'sourceIdentity': sourceIdentity,
        'sourceTime': sourceTime,
        'day': day,
        'rawHex': rawHex,
        'rawSha256': rawSha256,
        'values': values,
        'validity': validity,
        'firstSeenBatch': firstSeenBatch,
        'firstSeenOrdinal': firstSeenOrdinal
      };
}

class JwHistoryAppendResult {
  final Set<String> insertedIds, existingIds;
  JwHistoryAppendResult(Iterable<String> inserted, Iterable<String> existing)
      : insertedIds = Set.unmodifiable(inserted),
        existingIds = Set.unmodifiable(existing);
}

class JwHistoryBatchCommit {
  final String batchId, deviceKey;
  final List<String> recordIds;
  final Map<String, Object?> summary;
  JwHistoryBatchCommit(
      {required this.batchId,
      required this.deviceKey,
      required Iterable<String> recordIds,
      Map<String, Object?> summary = const {}})
      : recordIds = List.unmodifiable(recordIds),
        summary = Map.unmodifiable(summary);
  Map<String, Object?> toJson() => {
        'batchId': batchId,
        'deviceKey': deviceKey,
        'recordIds': recordIds,
        'summary': summary
      };
}

class JwHistoryPage {
  final List<JwHistoryRecord> records, latestBySourceIdentity;
  final Set<String> partialRecordIds;
  final int total;
  JwHistoryPage(
      {required Iterable<JwHistoryRecord> records,
      required Iterable<JwHistoryRecord> latestBySourceIdentity,
      required Iterable<String> partialRecordIds,
      required this.total})
      : records = List.unmodifiable(records),
        latestBySourceIdentity = List.unmodifiable(latestBySourceIdentity),
        partialRecordIds = Set.unmodifiable(partialRecordIds);
}

class JwHistoryInventory {
  final List<String> recordIds;
  final Map<String, int> counts;
  final Map<String, String> ackByBatch;
  final Map<String, String> batchFailures;
  final int recoveredTails;
  final Map<String, List<String>> daysByType;
  JwHistoryInventory(
      {required Iterable<String> recordIds,
      required Map<String, int> counts,
      required Map<String, String> ackByBatch,
      this.recoveredTails = 0,
      Map<String, String> batchFailures = const {},
      Map<String, List<String>> daysByType = const {}})
      : recordIds = List.unmodifiable(recordIds.toList()..sort()),
        counts = Map.unmodifiable(counts),
        ackByBatch = Map.unmodifiable(ackByBatch),
        batchFailures = Map.unmodifiable(batchFailures),
        daysByType = Map.unmodifiable({
          for (final e in daysByType.entries)
            e.key: List<String>.unmodifiable(e.value)
        });
  int get recordCount => recordIds.length;
  String get digest => jwHistoryDigest(recordIds);
  Map<String, Object?> toJson() => {
        'recordIds': recordIds,
        'recordCount': recordCount,
        'digest': digest,
        'counts': counts,
        'daysByType': daysByType,
        'ackByBatch': ackByBatch,
        'batchFailures': batchFailures,
        'recoveredTails': recoveredTails
      };
}

class JwHistoryTypeStats {
  final int received, uniqueInBatch, newlyPersisted, deduplicated, quarantined;
  final int? expectedCount;
  const JwHistoryTypeStats(
      {this.received = 0,
      this.uniqueInBatch = 0,
      this.newlyPersisted = 0,
      this.deduplicated = 0,
      this.quarantined = 0,
      this.expectedCount});
  Map<String, Object?> toJson() => {
        'received': received,
        'uniqueInBatch': uniqueInBatch,
        'newlyPersisted': newlyPersisted,
        'deduplicated': deduplicated,
        'quarantined': quarantined,
        'expectedCount': expectedCount
      };
}

class JwHistoryProgress {
  final String batchId;
  final JwHistoryPhase phase;
  final Map<JwHistoryType, JwHistoryTypeStats> counts;
  final Set<int> expectedMarkers, observedMarkers;
  final bool startReceived, traditionalEndReceived;
  final String? failureStage, error;
  JwHistoryProgress(
      {required this.batchId,
      required this.phase,
      required Map<JwHistoryType, JwHistoryTypeStats> counts,
      required Iterable<int> expectedMarkers,
      required Iterable<int> observedMarkers,
      required this.startReceived,
      required this.traditionalEndReceived,
      this.failureStage,
      this.error})
      : counts = Map.unmodifiable(counts),
        expectedMarkers = Set.unmodifiable(expectedMarkers),
        observedMarkers = Set.unmodifiable(observedMarkers);
  Map<String, Object?> toJson() => {
        'batchId': batchId,
        'phase': phase.name,
        'counts': {
          for (final e in counts.entries) e.key.name: e.value.toJson()
        },
        'expectedMarkers': expectedMarkers.toList()..sort(),
        'observedMarkers': observedMarkers.toList()..sort(),
        'startReceived': startReceived,
        'traditionalEndReceived': traditionalEndReceived,
        'failureStage': failureStage,
        'error': error
      };
}

class JwHistoryResult extends JwHistoryProgress {
  final bool wireRoundComplete,
      localCommitComplete,
      applicationAckTransportDelivered;
  final String countValidation;
  JwHistoryResult(
      {required super.batchId,
      required super.phase,
      required super.counts,
      required super.expectedMarkers,
      required super.observedMarkers,
      required super.startReceived,
      required super.traditionalEndReceived,
      super.failureStage,
      super.error,
      required this.wireRoundComplete,
      required this.localCommitComplete,
      required this.applicationAckTransportDelivered,
      required this.countValidation});
  bool get deviceDatasetExhaustive => false;
  static const firmwareLimitations = [
    'Modern streams have no announced totals; a normal marker can follow an early sender failure.',
    'Firmware advances modern read/restore cursors and S200 END advances traditional restore bookmarks without host confirmation; lossless reconnect replay is not guaranteed.',
    'Application confirmation advances traditional and HRV watermarks for future reclamation; no L2 FTL confirmation is available.'
  ];
  @override
  Map<String, Object?> toJson() => {
        ...super.toJson(),
        'wireRoundComplete': wireRoundComplete,
        'localCommitComplete': localCommitComplete,
        'applicationAckTransportDelivered': applicationAckTransportDelivered,
        'deviceDatasetExhaustive': false,
        'countValidation': countValidation,
        'ackScope': [
          'steps',
          'sleep',
          'heartTemperature',
          'bloodPressure',
          'exercise',
          'bloodOxygen',
          'hrv'
        ],
        'firmwareLimitations': firmwareLimitations
      };
}

class JwHistoryException implements Exception {
  final String stage;
  final JwHistoryResult result;
  JwHistoryException(this.stage, this.result);
  @override
  String toString() => 'JW history $stage: ${result.error}';
}
