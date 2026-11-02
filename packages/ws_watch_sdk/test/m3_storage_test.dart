import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/db/database.dart';
import 'package:ws_watch_sdk/src/storage/device_store.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';

void main() {
  test('identity survives database close, upsert and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('ws-m3-');
    final file = File('${directory.path}/devices.sqlite');
    WSDriftDeviceStore open() =>
        WSDriftDeviceStore(WSDatabase(NativeDatabase(file)));
    var store = open();
    try {
      final ids = await Future.wait(
          List.generate(8, (_) => store.defaultUserId('watch')));
      expect(ids.toSet(), hasLength(1));
      final id = ids.first;
      await store.close();
      store = open();
      expect(await store.defaultUserId('watch'), id);
      final info = WSDeviceInfo.fromBytes(
          [0, 1, 1, 2, 3, 0, 100, 1, 1, 1, 17, 34, 51, 68, 85, 102, 0]);
      final caps = WSCapabilities.fromBytes(List.filled(16, 0));
      await store.saveReady('watch', 'explicit-user', info, caps);
      await store.saveReady('watch', 'explicit-user', info, caps);
      await store.close();
      store = open();
      final rows = await store.database.select(store.database.devices).get();
      expect(rows, hasLength(1));
      expect(rows.single.userId, 'explicit-user');
      expect(rows.single.btMac, '11:22:33:44:55:66');
      expect(rows.single.capabilitiesRaw, List.filled(16, 0));
      expect(rows.single.lastConnectedAt, isNotNull);
    } finally {
      await store.close();
      await directory.delete(recursive: true);
    }
  });

  test('device info bounds and unknown capability bits remain explicit', () {
    for (final bytes in [
      <int>[],
      List.filled(16, 0),
      [...List.filled(16, 0), 33],
      [...List.filled(16, 0), 1]
    ]) {
      expect(() => WSDeviceInfo.fromBytes(bytes), throwsFormatException);
    }
    expect(() => WSCapabilities.fromBytes([0]), throwsFormatException);
    final caps = WSCapabilities.fromBytes(List.filled(16, 255));
    for (final feature in WSFeature.values) {
      expect(caps.supportOf(feature), WSFeatureSupport.unknown);
    }
    expect(() => caps.raw[0] = 0, throwsUnsupportedError);
  });
}
