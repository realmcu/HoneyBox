import 'dart:typed_data';

abstract interface class JwTransport {
  int get mtu;
  Stream<Uint8List> get notifications;
  Stream<void> get disconnected;
  Future<void> subscribe();
  Future<void> write(Uint8List frame, {required bool withResponse});
  Future<Uint8List?> read(String uuid);
  Future<void> disconnect();
}

class JwImmediateAlertAttempt {
  final int level;
  final bool withResponse;
  const JwImmediateAlertAttempt(this.level, {required this.withResponse});
}

/// Optional, specifically discovered standard IAS endpoint. No generic GATT writer.
abstract interface class JwImmediateAlertTransport {
  bool get immediateAlertAvailable;
  Stream<JwImmediateAlertAttempt> get immediateAlertAttempts;
  Future<void> writeImmediateAlert(bool enabled);
}
