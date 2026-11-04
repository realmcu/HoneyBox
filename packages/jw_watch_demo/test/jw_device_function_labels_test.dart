import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_device_function_labels.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('every JWDeviceFunction has a demo Chinese label', () {
    for (final function in JWDeviceFunction.values) {
      final label = jwDeviceFunctionLabel(function);
      expect(label, isNotEmpty);
      expect(label, isNot(equals(function.name)));
    }
  });
}
