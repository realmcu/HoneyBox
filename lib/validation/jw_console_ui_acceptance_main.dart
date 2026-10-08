// Debug-only real UI fixture: no BLE manager or production identity store.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/watch/jw_device_page.dart';
import '../providers/ble_provider.dart' show bleManagerProvider;
import '../providers/jw_device_provider.dart';
import '../services/jw/history/jw_history_store.dart';
import '../services/jw/jw_codec.dart';
import '../services/jw/jw_device_repository.dart';
import '../services/jw/jw_identity_store.dart';
import '../services/jw/jw_session.dart';
import '../services/jw/jw_transport.dart';

Future<void> main(List<String> arguments) async {
  if (!kDebugMode || !Platform.isWindows || arguments.length != 1) {
    throw StateError(
        'Windows debug UI fixture requires an isolated output directory');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final root = Directory(arguments.single).absolute;
  await root.create(recursive: true);
  final transport =
      _SimulatedTransport(File('${root.path}/simulated-wire.jsonl'));
  final store = FileJwHistoryStore(Directory('${root.path}/simulated-history'));
  await store.open();
  final repository = JwDeviceRepository(
      session: JwSession(transport),
      transport: transport,
      identityStore:
          JwIdentityStore(File('${root.path}/simulated-identity.json')),
      platformDeviceKey: 'SIMULATED-UI-ONLY',
      historyStoreFactory: () async => store,
      ownsHistoryStore: false);
  await repository.initialize();
  final capture = GlobalKey();
  // Read-only capture of the mounted/rendered native app, never a UI action.
  developer.registerExtension('ext.jw.consoleUiSnapshot', (_, __) async {
    final boundary =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final geometry = <Map<String, Object?>>[];
    void inspect(Element element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget.key != null || widget is Text) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.hasSize && render.attached) {
          final point = render.localToGlobal(Offset.zero);
          if (point.dx.isFinite &&
              point.dy.isFinite &&
              render.size.width.isFinite &&
              render.size.height.isFinite) {
            geometry.add({
              'key': widget.key?.toString(),
              'text': widget is Text ? widget.data : null,
              'x': point.dx,
              'y': point.dy,
              'width': render.size.width,
              'height': render.size.height
            });
          }
        }
      }
      element.visitChildren(inspect);
    }

    (capture.currentContext! as Element).visitChildren(inspect);
    final view = View.of(capture.currentContext!);
    image.dispose();
    return developer.ServiceExtensionResponse.result(jsonEncode({
      'kind':
          'actual Windows Flutter rendered UI; SIMULATED transport, no physical BLE',
      'pngBase64': base64Encode(png!.buffer.asUint8List()),
      'geometry': geometry,
      'devicePixelRatio': view.devicePixelRatio,
      'logicalWidth': boundary.size.width,
      'logicalHeight': boundary.size.height
    }));
  });
  runApp(ProviderScope(
      overrides: [
        bleManagerProvider.overrideWith((ref) =>
            throw StateError('Physical BLE is disabled in this UI fixture')),
        jwDeviceProvider
            .overrideWith((ref) => JwDeviceNotifier(repository: repository)),
        jwHistoryStoreProvider.overrideWith((ref) async => store),
      ],
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => RepaintBoundary(
              key: capture,
              child: Column(children: [
                Material(
                    color: Colors.amber,
                    child: SafeArea(
                        bottom: false,
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('UI验收：模拟传输，无真实设备',
                                style:
                                    Theme.of(context).textTheme.bodyMedium)))),
                Expanded(child: child!),
              ])),
          home: const JwDevicePage(
              deviceId: 'SIMULATED-UI-ONLY', deviceName: '模拟 S200 · UI 验收'))));
}

class _SimulatedTransport implements JwTransport, JwImmediateAlertTransport {
  final File audit;
  final _rx = StreamController<Uint8List>.broadcast(sync: true);
  final _down = StreamController<void>.broadcast(sync: true);
  final _alert =
      StreamController<JwImmediateAlertAttempt>.broadcast(sync: true);
  int _sequence = 0, _batteryReads = 0, _language = 0;
  var _subscribed = false;
  List<int> _longSit = [42, 0, 255, 250, 60, 255, 254, 99];
  final _configuration = <int, List<int>>{
    0x42: [0],
    0x45: [0],
    0x4b: [10, 10],
    0x54: [50, 50],
    0x11: [0, 0],
    0x34: [0, 0],
    0x3e: [0, 0],
    0x23: [0, 0, 0, 0]
  };
  _SimulatedTransport(this.audit);
  void _record(Map<String, Object?> event) => audit.writeAsStringSync(
      '${jsonEncode({
            'kind': 'SIMULATED ONLY, no BLE',
            'utc': DateTime.now().toUtc().toIso8601String(),
            ...event
          })}\n',
      mode: FileMode.append);
  @override
  int get mtu => 247;
  @override
  Stream<Uint8List> get notifications => _rx.stream;
  @override
  Stream<void> get disconnected => _down.stream;
  @override
  Future<void> subscribe() async {
    _subscribed = true;
  }

  @override
  Future<void> disconnect() async {
    _subscribed = false;
    _down.add(null);
  }

  @override
  Future<Uint8List?> read(String uuid) async {
    _record({'gattRead': uuid});
    if (uuid == '2a19') {
      if (++_batteryReads > 1) {
        throw StateError('SIMULATED fresh battery read failure');
      }
      return Uint8List.fromList([70]);
    }
    final text = {
      '2a00': 'SIMULATED S200',
      '2a25': 'SIMULATED-SERIAL',
      '2a26': 'T005',
      '2a27': 'H001'
    }[uuid];
    return text == null ? null : Uint8List.fromList(utf8.encode(text));
  }

  void _reply(int command, int key, List<int> value) => _rx.add(JwCodec.encode(
      seq: ++_sequence,
      payload: JwCodec.encodeL2(
          command, [JwField(key, Uint8List.fromList(value))])));
  @override
  Future<void> write(Uint8List bytes, {required bool withResponse}) async {
    if (!_subscribed || !withResponse) {
      throw StateError('Simulated transport unavailable');
    }
    final frame = JwFrameDecoder().add(bytes).single;
    if (frame.ack) {
      _record({'ackFromApp': frame.seq});
      return;
    }
    final message = JwCodec.decodeL2(frame.payload),
        field = message.fields.single;
    final c = message.command, k = field.key;
    _record({'command': c, 'key': k, 'value': field.value.toList()});
    _rx.add(JwCodec.encode(seq: frame.seq, payload: Uint8List(0), ack: true));
    if (c == 2 && k == 0x36) {
      _reply(2, 0x37, [0x4d, 0xd1, 0x7d, 0xfc, 0xe3, 0x4a, 0xd8, 0x3d]);
    } else if (c == 6 && k == 0x3d) {
      _reply(6, 0x3e, [3]);
    } else if (c == 3 && k == 3) {
      _reply(3, 4, [0]);
    } else if (c == 2 && k == 0x4f) {
      _reply(2, 0x50, [_language]);
    } else if (c == 2 && k == 0x4e) {
      _language = field.value.single;
    } else if (c == 2 && k == 0x26) {
      _reply(2, 0x27, _longSit);
    } else if (c == 2 && k == 0x21) {
      _longSit = field.value.toList();
    } else if (c == 2 && k == 0x48) {
      _reply(2, 0x49, [0, 0, 0]);
    } else if (c == 2 && k == 0x2b) {
      _reply(2, 0x2c, [1]);
    } else if (c == 2 && k == 0x87) {
      _reply(2, 0x88, [0x52, 0x04, 0x80]);
    } else if (c == 2 && k == 3) {
      _reply(2, 4, []);
    } else if (c == 2 && k == 0x3b) {
      _reply(5, 0x17, [0x0f, 0x3d, 0x6b, 0xfe]);
    } else if (c == 5 && k == 0x3a) {
      _reply(5, 0x3b, List.filled(8, 0));
    } else if (c == 5 && k == 0x26) {
      _reply(5, 0x27, List.filled(4, 0));
    } else if (c == 5 && k == 0x2d) {
      _reply(5, 0x2e, [3]);
    } else if (c == 5 && k == 0x19) {
      _reply(5, 0x1a, field.value.toList());
    } else {
      final read = _configuration[k];
      if (read != null) {
        _reply(c, k + 1, read);
      } else if (_configuration.containsKey(k + 1)) {
        final old = _configuration[k + 1]!;
        _configuration[k + 1] = old.length == 2 && field.value.length == 1
            ? [field.value.single, old.last]
            : field.value.toList();
      }
    }
  }

  @override
  bool get immediateAlertAvailable => true;
  @override
  Stream<JwImmediateAlertAttempt> get immediateAlertAttempts => _alert.stream;
  @override
  Future<void> writeImmediateAlert(bool enabled) async {
    _record({'simulatedIasLevel': enabled ? 2 : 0});
    _alert.add(JwImmediateAlertAttempt(enabled ? 2 : 0, withResponse: false));
  }
}
