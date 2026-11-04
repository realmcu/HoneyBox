import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/src/protocol/cmd_02_settings.dart';
import 'package:ws_watch_sdk/src/transport/connection_factory.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'scenarios.dart';

const config = WSConfig(
    simulationEnabled: true,
    link: WSLinkConfig(ackTimeout: Duration(milliseconds: 20), maxRetries: 2),
    session: WSSessionConfig(replyTimeout: Duration(milliseconds: 25)));
void main() {
  for (final nack in [false, true]) {
    test(
        'simulator ${nack ? 'ERR' : 'lost'} ACK retransmits; no duplicate execution',
        () async {
      final h = await WSPreparedSimulation.open(config: config, mtu: 23);
      final faults = SimFaultScript(h.device.transport);
      if (nack) {
        faults.errorAcks = 1;
      } else {
        faults.dropAcks = 1;
      }
      final reports = <WSDeviceReport>[];
      final events = <WSFrameEvent>[];
      h.debug.reports.listen(reports.add);
      h.debug.frames.listen(events.add);
      await h.session.send(WSSettingsProtocol.setLanguage, 7);
      expect(await h.session.query(WSSettingsProtocol.getLanguage, null), 7);
      expect(events.any((e) => e.kind == WSFrameKind.retry), isTrue);
      expect(reports.where((r) => r.kind == WSReportKind.notification),
          hasLength(1));
      faults.dispose();
      await h.dispose();
    });
  }
  test('simulator can drop the wire mid-exchange', () async {
    final h = await WSPreparedSimulation.open(config: config);
    final faults = SimFaultScript(h.device.transport)..disconnectOnFrame = true;
    await expectLater(h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSDisconnectedException>()));
    faults.dispose();
    await h.dispose();
  });
  test('late simulator response does not close the live session after timeout',
      () async {
    final h = await WSPreparedSimulation.open(config: config);
    h.device.replyDelay = const Duration(milliseconds: 60);
    await expectLater(h.session.query(WSSettingsProtocol.getLanguage, null),
        throwsA(isA<WSTimeoutException>()));
    expect(h.session.isClosed, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    h.device.replyDelay = Duration.zero;
    expect(await h.session.query(WSSettingsProtocol.getLanguage, null), 1);
    await h.dispose();
  });
}
