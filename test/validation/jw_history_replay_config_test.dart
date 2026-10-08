import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/validation/jw_sdk_acceptance.dart';

void main() {
  test('history replay accepts pinned existing identity and capability profile',
      () {
    final c = AcceptanceConfig(
        outputDirectory: 'unused',
        address: '64:1A:B2:B8:00:3A',
        mode: 'history-replay',
        expectedIdentitySha256: 'd' * 64,
        expectedFunctions: '4dd17dfce34ad83d',
        expectedFactory: 3);
    expect(c.mode, 'history-replay');
  });
  test('history replay refuses unpinned mutation target', () {
    expect(
        () => AcceptanceConfig(
            outputDirectory: 'unused',
            address: '64:1A:B2:B8:00:3A',
            mode: 'history-replay'),
        throwsArgumentError);
  });
}
