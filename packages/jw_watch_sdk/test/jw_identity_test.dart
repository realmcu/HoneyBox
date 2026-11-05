import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('pads short hex user ids to 32 digits', () {
    expect(
      JWIdentity('123456').value,
      '${'0' * 26}123456',
    );
    expect(JWIdentity.normalize('123456'), JWIdentity('123456').value);
  });

  test('truncates hex longer than 32 digits', () {
    final long = '${'a' * 33}';
    expect(JWIdentity(long).value, 'a' * 32);
  });

  test('ignores non-hex separators before normalize', () {
    expect(
      JWIdentity('12:34:56').value,
      '${'0' * 26}123456',
    );
  });

  test('rejects empty or non-hex input', () {
    expect(() => JWIdentity(''), throwsArgumentError);
    expect(() => JWIdentity('   '), throwsArgumentError);
    expect(() => JWIdentity('mnop'), throwsArgumentError);
  });

  test('wire bytes are 32 ASCII code units', () {
    expect(JWIdentity('A' * 32).bytes, hasLength(32));
  });
}
