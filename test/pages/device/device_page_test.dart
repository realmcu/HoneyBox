import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/device/device_page.dart';
import 'package:honeybox/pages/device/widgets/action_card.dart';
import 'package:honeybox/services/device_type_store.dart';
import 'package:honeybox/theme/app_theme.dart';

/// 功能选择界面的交互:顶部设备栏可点 → 切类型 → 卡片跟着换。
///
/// 绑定表读写走 `getApplicationSupportDirectory`(平台通道),在 widget 测试里必然
/// 失败 —— [DeviceTypeBindingStore] 对此是「尽力而为」,失败退回默认类型,所以这些
/// 用例跑的就是「没绑过」那条路,正好是首次连接的真实情形。
void main() {
  setUp(() {
    // 默认的 800×600 测试窗口装不下 Demo 的三行卡片,而 GridView 只构建可见
    // 区域 —— 不放大窗口,后面的卡片根本不存在,`find.byType` 会漏掉它们。
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(400, 900);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget buildPage({String deviceId = 'AA:BB:CC:DD:EE:FF'}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: DevicePage(deviceName: 'eBadge', deviceId: deviceId),
        // 功能页本身不是这里的测试对象;给个占位页,让「点卡片会导航」能跑通。
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(child: Text('page:${settings.name}')),
          ),
        ),
      ),
    );
  }

  List<String> cardTitles(WidgetTester tester) => tester
      .widgetList<ActionCard>(find.byType(ActionCard))
      .map((c) => c.title)
      .toList();

  /// 设备栏里的那个设备名。
  ///
  /// 不直接用 `find.text('eBadge')`:AppBar 标题也叫这个,两处会撞在一起。
  Finder deviceNameInBar() => find.descendant(
        of: find.byType(InkWell),
        matching: find.text('eBadge'),
      );

  /// 点设备栏上的下拉箭头打开类型面板。
  ///
  /// 认箭头而不是认文字:栏里的按钮标签就是**当前类型名**,面板一打开同一个名字
  /// 会再出现一次,`find.text` 那时就不唯一了。
  Future<void> openTypeSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
  }

  group('默认类型', () {
    testWidgets('连接后按 Demo 列卡片 —— 有业务功能,没有协议调试', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(cardTitles(tester), [
        '图片',
        '弹幕',
        '视频 / GIF',
        '多图轮播',
        '拍照投屏',
        'OTA 升级',
      ]);
      expect(find.text('协议调试'), findsNothing);
      // 栏里就一个值:当前类型名。没有「设备类型」这种标签,也没有重复一遍的
      // 副标题(需求:按钮直接是类型名,不额外显示一次)。
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('设备类型'), findsNothing);
    });

    testWidgets('设备栏仍然是「WiFi 配网」左侧的那一块', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      final bar = tester.getCenter(find.text('Demo'));
      final wifi = tester.getCenter(find.text('WiFi 配网'));
      expect(bar.dx, lessThan(wifi.dx));
    });

    // 设备名去掉过一次(顶部只留类型名),但它得回来 —— 类型说的是「按哪一类列
    // 功能」,认的是「这是哪台机器」,冷启动后连着两台不同样机时只有它能区分。
    testWidgets('设备类型下面仍然是设备名', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      final type = tester.getRect(find.text('Demo'));
      final name = tester.getRect(deviceNameInBar());
      expect(name.top, greaterThan(type.top), reason: '设备名在类型名的下一行');
      expect(name.left, closeTo(type.left, 0.5), reason: '两行左对齐');
    });

    // 设备栏和功能网格之间那条线。它同时是「栏到这里结束、下面是内容」的分界,
    // 少了它整块就糊在一起。
    testWidgets('设备栏下方有通到屏幕两侧的分隔线', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      final divider = find.byType(Divider);
      expect(divider, findsOneWidget);

      final rect = tester.getRect(divider);
      expect(rect.left, 0, reason: '贴着屏幕左边');
      expect(rect.right,
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
          reason: '贴着屏幕右边');

      // 位置也要对:在设备名下面、第一张卡片上面。
      expect(rect.top, greaterThan(tester.getRect(deviceNameInBar()).bottom));
      expect(rect.bottom, lessThan(tester.getRect(find.text('图片')).top));
    });
  });

  group('切换类型', () {
    testWidgets('点设备栏弹出选择,选 Mi 之后只列协议调试', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      await openTypeSheet(tester);
      // 面板标题居中显示,且不再挂那句「选择后自动记住…」的说明。
      final title = tester.widget<Text>(find.text('设备类型'));
      expect(title.textAlign, TextAlign.center);
      expect(find.textContaining('选择后自动记住'), findsNothing);

      await tester.tap(find.text('Mi'));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), ['协议调试']);
      // 设备栏跟着变成当前类型 —— 它就是那个下拉按钮的标签。
      expect(find.text('Mi'), findsOneWidget);
      expect(find.text('Demo'), findsNothing);
    });

    testWidgets('切回 Demo 时业务卡片回来', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      await openTypeSheet(tester);
      await tester.tap(find.text('Mi'));
      await tester.pumpAndSettle();
      expect(cardTitles(tester), ['协议调试']);

      await openTypeSheet(tester);
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), hasLength(6));
      expect(cardTitles(tester), contains('图片'));
    });

    // 关掉面板什么都没选 = 不改。否则点错一下就莫名其妙换了类型,而用户看不出
    // 「刚才那一下其实生效了」。
    testWidgets('取消选择不改类型', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      final before = cardTitles(tester);

      await openTypeSheet(tester);
      // 点面板外的遮罩关闭。
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(cardTitles(tester), before);
      expect(find.text('Demo'), findsOneWidget);
    });

    // 「WiFi 配网」是独立动作,不能因为落在设备栏那一行里就跟着切类型 ——
    // 它该走自己的路由。
    testWidgets('点 WiFi 配网走配网页，不弹类型面板', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.text('WiFi 配网'));
      await tester.pumpAndSettle();

      expect(find.text('page:/wifi'), findsOneWidget);
      expect(find.text('设备类型'), findsNothing);
    });
  });

  // 点卡片还是要按**当前类型**的目录跳转 —— 切换只是换了对哪几张卡,不是把卡片
  // 变成装饰。
  testWidgets('点卡片跳到对应的路由', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(find.text('page:/image'), findsOneWidget);
  });

  // 绑定表落在平台通道上,测试环境里读写都会失败。这条钉的是「存不下也不能把
  // 界面搞坏/把类型卡住」—— 类型是本地状态,记忆只是便利。
  testWidgets('绑定存不下来时类型切换照样生效', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();

    await openTypeSheet(tester);
    await tester.tap(find.text('Mi'));
    await tester.pumpAndSettle();

    expect(cardTitles(tester), ['协议调试']);
    expect(find.text('Mi'), findsOneWidget);
    expect(DeviceType.values, contains(DeviceType.mi));
  });
}
