import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/providers/ble_provider.dart';
import 'package:honeybox/providers/jw_device_provider.dart';
import 'package:honeybox/services/ble_manager.dart' as bm;
import 'package:honeybox/services/jw/jw_codec.dart';
import 'package:honeybox/services/jw/jw_identity_store.dart';
import 'package:honeybox/services/jw/jw_models.dart';
import 'package:honeybox/services/jw/jw_transport.dart';
import 'package:honeybox/validation/jw_sdk_acceptance_main.dart';
import '../helpers/fake_jw_transport.dart';
import '../helpers/jw_device_script.dart';

class FixtureManager implements bm.BleManager {
  final FakeJwTransport transport;
  final changes = StreamController<bm.BleState>.broadcast(sync: true);
  FixtureManager(this.transport);
  @override
  Stream<bm.BleState> get onStateChanged => changes.stream;
  @override
  JwTransport get jwTransport => transport;
  @override
  int get mtu => transport.mtu;
  @override
  void stopScan() {}
  @override
  Future<bool> connect(String id, String name, {bool allowJw = false}) async =>
      true;
  @override
  Future<void> disconnect() async {
    await transport.disconnect();
  }

  @override
  void dispose() {
    unawaited(changes.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late File identity;
  late FakeJwTransport transport;
  late ProviderContainer container;
  late JwProductionAcceptancePort port;
  late String digest;
  late StreamSubscription<JwFrame> audit;
  late List<JwFrame> outgoing;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw_production_readonly_');
    identity = File('${dir.path}/jw_identity_v1.json');
    final record = await JwIdentityStore(identity).loadOrCreate();
    digest = sha256.convert(record.wireUserId).toString();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => call.method == 'getApplicationSupportDirectory'
                ? dir.path
                : null);
    transport = FakeJwTransport();
    installJwDeviceScript(transport);
    final manager = FixtureManager(transport);
    container = ProviderContainer(
        overrides: [bleManagerProvider.overrideWithValue(manager)]);
    port = JwProductionAcceptancePort((_) async {}, container: container);
    outgoing = [];
    audit = port.outgoingFrames.listen(outgoing.add);
    await port.prepareReadOnlyIdentity(digest);
  });
  tearDown(() async {
    await port.disconnect();
    await port.close();
    await audit.cancel();
    await transport.dispose();
    await dir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });
  Future<void> connectAndJournalWait() async {
    await port.connect(ScanDevice(
        deviceId: '64:1A:B2:B8:00:3A',
        name: 'S200',
        rssi: -40,
        jwCandidate: true));
    await container.read(jwRepositoryProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  List<JwMessage> appFrames(List<JwFrame> frames) => frames
      .where((f) => !f.ack)
      .map((f) => JwCodec.decodeL2(f.payload))
      .toList();
  Future<void> initializeAllowFailure() async {
    try {
      await port.initialize();
    } on StateError {/* missing login reply expected */}
  }

  test(
      'production connection journal delay cannot initialize before explicit audit guard',
      () async {
    await connectAndJournalWait();
    expect(transport.writes, isEmpty);
    expect(outgoing, isEmpty);
  });
  test(
      'production audit observes every initialization write despite provider event ticks',
      () async {
    await connectAndJournalWait();
    await port.initialize();
    expect(port.state.phase, JwDevicePhase.loggedIn);
    expect(outgoing.length, transport.writes.length);
    expect(
        appFrames(outgoing).map((m) => '${m.command}/${m.fields.single.key}'),
        ['2/54', '6/61', '2/79', '3/3']);
  });
  test('production identity deletion after prepare cannot create file or login',
      () async {
    await identity.delete();
    await connectAndJournalWait();
    await initializeAllowFailure();
    expect(await identity.exists(), isFalse);
    expect(port.state.phase, JwDevicePhase.identityUnavailable);
    expect(appFrames(transport.sent).where((m) => m.command == 3), isEmpty);
  });
  test(
      'production changed identity after prepare cannot transmit replacement login',
      () async {
    final replacement =
        await JwIdentityStore(File('${dir.path}/replacement.json'))
            .loadOrCreate();
    await File('${dir.path}/replacement.json').copy(identity.path);
    expect(sha256.convert(replacement.wireUserId).toString(), isNot(digest));
    await connectAndJournalWait();
    await initializeAllowFailure();
    expect(port.state.phase, JwDevicePhase.identityUnavailable);
    expect(appFrames(transport.sent).where((m) => m.command == 3), isEmpty);
  });
}
