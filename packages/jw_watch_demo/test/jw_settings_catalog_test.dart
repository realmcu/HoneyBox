import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_settings_catalog.dart';

void main() {
  test('settings catalog covers WatchDetail groups and statuses', () {
    final groups = jwSettingsCatalog();
    expect(groups.map((g) => g.id), [
      JwSettingsGroupId.shortcuts,
      JwSettingsGroupId.settings,
      JwSettingsGroupId.other,
    ]);

    final ids = groups.expand((g) => g.items).map((i) => i.id).toSet();
    expect(ids.contains(JwSettingsItemId.healthMonitoring), isTrue);
    expect(ids.contains(JwSettingsItemId.unitSettings), isTrue);
    expect(ids.contains(JwSettingsItemId.watchFace), isTrue);
    expect(ids.contains(JwSettingsItemId.firmwareUpdate), isTrue);
    expect(ids.contains(JwSettingsItemId.eventRemind), isTrue);
    expect(ids.contains(JwSettingsItemId.alarm), isTrue);
    expect(ids.contains(JwSettingsItemId.doNotDisturb), isFalse);
    expect(ids.contains(JwSettingsItemId.disconnect), isFalse);
    expect(
      groups.expand((g) => g.items).any((i) => i.title == '标签闹钟'),
      isFalse,
    );

    final event = groups
        .expand((g) => g.items)
        .firstWhere((i) => i.id == JwSettingsItemId.eventRemind);
    expect(event.implStatus, JwSettingsImplStatus.sdkReady);

    final titles =
        groups.expand((g) => g.items).map((i) => i.title).toSet();
    expect(titles.contains('女性健康'), isFalse);
    expect(titles.contains('生理周期'), isFalse);
    expect(titles.contains('电子卡片'), isFalse);
    expect(titles.contains('字库升级'), isFalse);
    expect(titles.contains('重置设备密码'), isFalse);
    expect(titles.contains('倒计时'), isFalse);
    expect(titles.contains('秒表'), isFalse);
    expect(titles.contains('隐藏健康功能'), isFalse);
    expect(titles.contains('时制'), isFalse);
    expect(titles.contains('单位设置'), isTrue);
    expect(titles.contains('屏幕与显示'), isTrue);
    expect(titles.contains('健康与监测'), isTrue);

    final health = groups
        .expand((g) => g.items)
        .firstWhere((i) => i.id == JwSettingsItemId.healthMonitoring);
    expect(health.subtitle, isNull);
    expect(health.apiCode, isNull);

    final unit = groups
        .expand((g) => g.items)
        .firstWhere((i) => i.id == JwSettingsItemId.unitSettings);
    expect(unit.apiCode, isNotNull);
    expect(unit.subtitle, isNull);

    final watchFace = groups
        .expand((g) => g.items)
        .firstWhere((i) => i.id == JwSettingsItemId.watchFace);
    expect(watchFace.implStatus, JwSettingsImplStatus.deferredThisSprint);

    final clearData = groups
        .expand((g) => g.items)
        .firstWhere((i) => i.id == JwSettingsItemId.clearData);
    expect(clearData.implStatus, JwSettingsImplStatus.sdkReady);
    expect(clearData.apiCode, isNotNull);

    expect(jwSettingsImplStatusLabel(JwSettingsImplStatus.sdkReady), isNull);
    expect(
      jwSettingsImplStatusLabel(JwSettingsImplStatus.sdkUnsupported),
      'SDK 未支持',
    );
  });
}
