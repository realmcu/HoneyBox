import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ota/ota_progress.dart';

void main() {
  test('formats OTA elapsed time', () {
    expect(formatOtaDuration(const Duration(seconds: 5)), '00:05');
    expect(formatOtaDuration(const Duration(seconds: 116)), '01:56');
    expect(formatOtaDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03');
    expect(formatOtaDuration(const Duration(seconds: -1)), '00:00');
  });

  test('estimates transfer speed from package size and progress', () {
    final speed = otaTransferSpeedKBps(
      firmwareBytes: 1565216,
      progress: 1,
      elapsed: const Duration(milliseconds: 116861),
    );
    expect(speed, closeTo(13.08, 0.1));
    expect(formatOtaSpeed(speed), '13.1 KB/s');
    expect(formatOtaSpeed(2048), '2.00 MB/s');
  });

  test('does not report speed without a measurable transfer', () {
    expect(
        otaTransferSpeedKBps(
          firmwareBytes: 1000,
          progress: 0,
          elapsed: const Duration(seconds: 1),
        ),
        isNull);
    expect(
        otaTransferSpeedKBps(
          firmwareBytes: 1000,
          progress: 0.5,
          elapsed: const Duration(milliseconds: 400),
        ),
        isNull);
    expect(formatOtaSpeed(null), '—');
  });
}
