import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../services/ota/rtl87x3g_ota_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}honeybox_rtl87x3g_ota.log',
  );
  log.writeAsStringSync('', flush: true);
  void writeLog(String line) {
    stdout.writeln(line);
    log.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }

  const deviceId = String.fromEnvironment('DEVICE_ID');
  const imagePath = String.fromEnvironment('IMAGE_PATH');
  if (deviceId.isEmpty || imagePath.isEmpty) {
    writeLog('DEVICE_ID and IMAGE_PATH are required');
    exitCode = 2;
    return;
  }

  writeLog('OTA_SMOKE_START device=$deviceId image=$imagePath');
  final platform = Rtl87x3gOtaPlatform();
  final finished = Completer<void>();
  final subscription = platform.events.listen((event) {
    writeLog('OTA_EVENT ${event.toString()}');
    if (event['done'] == true && !finished.isCompleted) {
      finished.complete();
    }
  });
  try {
    await platform.prepare(
      deviceId,
      sessionId: 'smoke-${DateTime.now().millisecondsSinceEpoch}',
    );
    await platform.start(imagePath);
    await finished.future.timeout(const Duration(minutes: 12));
    writeLog('OTA_SMOKE_OK');
  } catch (error, stack) {
    writeLog('OTA_SMOKE_FAIL $error');
    writeLog(stack.toString());
    exitCode = 1;
  } finally {
    writeLog('OTA_SMOKE_EXIT code=$exitCode');
    await subscription.cancel();
    await Future<void>.delayed(const Duration(seconds: 1));
    exit(exitCode);
  }
}
