import 'package:flutter_test/flutter_test.dart';
import 'package:ws_watch_sdk/ws_watch_sdk.dart';
import 'package:ws_watch_demo/src/debug/debug_capture.dart';

void main() {
  test('strict hex parsers reject partial bytes and invalid addresses', () {
    expect(parseDebugHex('01 ab\nFF'), [1, 171, 255]);
    expect(parseDebugHex(''), isEmpty);
    expect(parseHexByte('0x0f', max: 15), 15);
    for (final value in ['0', 'gg', '0x01', '01,02']) {
      expect(() => parseDebugHex(value), throwsFormatException);
    }
    expect(() => parseHexByte('10', max: 15), throwsFormatException);
  });
  test(
      'capture enforces count/byte bounds, pause discards, export keeps metadata',
      () async {
    final watch = WSWatch();
    final capture =
        DemoDebugCapture(watch, maxFrames: 2, maxReports: 2, maxBytes: 800);
    WSFrameEvent frame(int seq) => WSFrameEvent(
        direction: WSFrameDirection.tx,
        kind: WSFrameKind.data,
        seq: seq,
        raw: [1, 2],
        connectionGeneration: 7,
        traceId: 'trace',
        requestId: '7:$seq');
    for (var i = 0; i < 8; i++) {
      capture.addFrame(frame(i));
    }
    expect(capture.frames, hasLength(2));
    expect(capture.droppedFrames, 6);
    capture.addReport(WSDeviceReport(
        address: null,
        kind: WSReportKind.unknown,
        data: [0xff],
        connectionGeneration: 7));
    capture.addReport(WSDeviceReport(
        address: null, kind: WSReportKind.dropped, data: [0xaa]));
    expect(capture.retainedBytes, lessThanOrEqualTo(800));
    final before = capture.frames.length;
    capture.setPaused(true);
    capture.addFrame(frame(99));
    expect(capture.frames, hasLength(before));
    expect(capture.skipped, 1);
    capture.setPaused(false);
    capture.addFrame(WSFrameEvent(
        direction: WSFrameDirection.rx,
        kind: WSFrameKind.crcError,
        raw: List.filled(1000, 0)));
    expect(capture.retainedBytes, lessThanOrEqualTo(800));
    final text = capture.exportText();
    expect(text, contains('UNMATCHED REPORTS'));
    expect(text, contains('unknown'));
    expect(text, contains('dropped'));
    expect(text, contains('generation=7'));
    capture.clear();
    expect(capture.frames, isEmpty);
    expect(capture.reports, isEmpty);
    expect(capture.retainedBytes, 0);
    capture.dispose();
    await watch.dispose();
  });
  test('action traces retain elapsed/result/errors and stay bounded', () async {
    final watch = WSWatch();
    final capture = DemoDebugCapture(watch);
    for (var i = 0; i < 25; i++) {
      expect(await capture.run('read', () async => i), i);
    }
    await expectLater(
        capture.run('failed', () async => throw StateError('boom')),
        throwsStateError);
    expect(capture.actions, hasLength(20));
    expect(capture.actions.first.error.toString(), contains('StateError'));
    expect(capture.actions.first.elapsed, greaterThanOrEqualTo(Duration.zero));
    expect(capture.actions.map((a) => a.traceId).toSet(), hasLength(20));
    capture.dispose();
    await watch.dispose();
  });
}
