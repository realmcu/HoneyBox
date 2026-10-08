import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/jw_gatt_profile.dart';

void main() {
  final chars = {JwGattProfile.tx, JwGattProfile.rx};
  bool match(String s, Set<String> c,
          {bool write = true, bool notify = true, bool allow = true}) =>
      JwGattProfile.matches(s, c,
          txWrite: write, rxNotify: notify, allowJw: allow);
  test('only the complete enabled JW service can select the protocol', () {
    expect(match(JwGattProfile.service, chars), isTrue);
    expect(
        match(JwGattProfile.service.toUpperCase(), {'FF02', 'FF03'}), isTrue);
    expect(match('FD50', chars), isFalse);
    expect(match('FFC0', chars), isFalse);
    expect(match(JwGattProfile.service, {JwGattProfile.tx}), isFalse);
    expect(match(JwGattProfile.service, chars, write: false), isFalse);
    expect(match(JwGattProfile.service, chars, notify: false), isFalse);
    expect(match(JwGattProfile.service, chars, allow: false), isFalse);
    expect(
        JwGattProfile.matches(JwGattProfile.service, chars,
            txWrite: true, rxNotify: true),
        isFalse);
  });
}
