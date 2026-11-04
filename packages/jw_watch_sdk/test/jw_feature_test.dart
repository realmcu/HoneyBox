import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('feature support distinguishes discovery from device support', () {
    const unknown = JWFeatureSupport(
      feature: JWFeature.measurements,
      availability: JWFeatureAvailability.unknown,
    );
    const unsupported = JWFeatureSupport(
      feature: JWFeature.measurements,
      availability: JWFeatureAvailability.unsupported,
      reason: 'Firmware does not report manual measurement support',
    );

    expect(unknown.isSupported, isFalse);
    expect(unsupported.isSupported, isFalse);
    expect(unsupported.reason, isNotEmpty);
  });
}
