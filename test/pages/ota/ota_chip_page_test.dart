import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ota/ota_chip_page.dart';

void main() {
  testWidgets('offers the RTL8773G normal OTA entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OtaChipPage()));
    expect(find.text('RTL8773G'), findsOneWidget);
    expect(find.text('eBadge / Watch 普通 OTA'), findsOneWidget);
    expect(find.text('RTL8762D'), findsOneWidget);
  });
}
