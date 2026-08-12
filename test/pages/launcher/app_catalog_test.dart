import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/launcher/app_catalog.dart';

void main() {
  group('kAppCatalog', () {
    test('contains exactly ebadge, watch, dashboard in this order', () {
      expect(kAppCatalog.map((e) => e.id).toList(),
          [AppId.ebadge, AppId.watch, AppId.dashboard]);
    });

    test('every entry has non-empty title, subtitle, deviceFilter', () {
      for (final e in kAppCatalog) {
        expect(e.title, isNotEmpty, reason: '${e.id} title empty');
        expect(e.subtitle, isNotEmpty, reason: '${e.id} subtitle empty');
        expect(e.deviceFilter, isNotEmpty, reason: '${e.id} filter empty');
        expect(e.icon, isA<IconData>());
      }
    });

    test('ebadge and dashboard are implemented, watch is not', () {
      final map = {for (final e in kAppCatalog) e.id: e.implemented};
      expect(map[AppId.ebadge], isTrue);
      expect(map[AppId.watch], isFalse);
      expect(map[AppId.dashboard], isTrue);
    });

    test('device filters are the exact spec values', () {
      final byId = {for (final e in kAppCatalog) e.id: e.deviceFilter};
      expect(byId[AppId.ebadge], 'eBadge');
      expect(byId[AppId.watch], 'Watch');
      expect(byId[AppId.dashboard], 'Dashboard');
    });
  });

  group('routeNameFor', () {
    test('maps each AppId to the spec-defined route name', () {
      expect(routeNameFor(AppId.ebadge), '/ebadge-root');
      expect(routeNameFor(AppId.watch), '/watch-root');
      expect(routeNameFor(AppId.dashboard), '/dashboard-root');
    });
  });
}
