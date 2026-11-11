import 'dart:typed_data';

import 'honey_l2.dart';

/// Command `0x05` version 1 — history sync ([HoneyProtocol 0x05-data.rst]).
abstract final class HoneyDataCommand {
  static const int command = 0x05;
  static const int version = 1;

  static const int keySyncAll = 0x00;
  static const int keySyncActivity = 0x01;
  static const int keySyncSleep = 0x02;
  static const int keySyncHeartRate = 0x03;
  static const int keySyncBloodPressure = 0x04;
  static const int keySyncBloodOxygen = 0x05;
  static const int keySyncHrv = 0x06;
  static const int keySyncPressure = 0x07;
  static const int keySyncTemperature = 0x08;
  static const int keySyncBloodGlucose = 0x09;
  static const int keySyncSport = 0x0A;

  static const int keyDataActivity = 0x21;
  static const int keyDataSleep = 0x22;
  static const int keyDataHeartRate = 0x23;
  static const int keyDataBloodPressure = 0x24;
  static const int keyDataBloodOxygen = 0x25;
  static const int keyDataHrv = 0x26;
  static const int keyDataPressure = 0x27;
  static const int keyDataTemperature = 0x28;
  static const int keyDataBloodGlucose = 0x29;
  static const int keyDataSport = 0x2A;
  static const int keySyncStart = 0x40;
  static const int keySyncEnd = 0x41;
  static const int keySyncConfirm = 0x42;

  static HoneyL2Message syncRequest(int syncKey) => HoneyL2Message(
        command: command,
        version: version,
        key: syncKey,
        value: Uint8List(0),
      );

  static HoneyL2Message syncConfirm() => HoneyL2Message(
        command: command,
        version: version,
        key: keySyncConfirm,
        value: Uint8List(0),
      );

  static bool isDataKey(int key) => key >= 0x21 && key <= 0x2a;
}
