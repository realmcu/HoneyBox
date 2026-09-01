// ebadge_debug_config.dart
//
// 协议调试页的可记忆配置(封装开关 / 测试图档位 / 帧源 / 日志自动滚动)。
//
// 为什么要持久化:调试这条链路是**反复进出页面**的活 —— 传一次、看设备屏、退出去
// 改点别的、再进来传第二次。每次回到默认档等于每次都要重新点一遍那几个开关,而漏点
// 一个(比如忘了切回不带头)就会把上一轮的结论套到这一轮的数据上,这种错误在日志里
// 极难看出来。
//
// 单独成文件而不是塞进 `app_settings.dart`:那是全 App 的用户偏好(缓存上限、调试
// 模式),会进设置页;这里是一个调试台的现场状态,不该出现在用户设置里,也不需要
// Riverpod 那套响应式分发 —— 只有一个页面读写它。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:path_provider/path_provider.dart';

import 'ebadge_demo_presets.dart';

/// §6 推流的帧源。
///
/// 两个源问的是**不同的问题**,所以都留着:
///
/// - [builtin] 画面固定、每帧体积固定 —— 排除「画面来源」这个变量,屏上任何异常都
///   能归因到协议实现;
/// - [camera] 画面和体积都在变 —— 压真实负载下的时序(帧间隔、码率、设备解码是否
///   跟得上),这是固定帧测不出来的。
///
/// 调试顺序是先 [builtin] 确认链路通,再 [camera] 加压。
enum EBadgeStreamSource {
  builtin('内置测试帧', defaultFps: 1),
  camera('摄像头', defaultFps: 10);

  const EBadgeStreamSource(this.label, {required this.defaultFps});
  final String label;

  /// 0x08 OFFER 里请求的帧率,决定推流 tick 周期(1000/fps 毫秒)。
  ///
  /// **两个源要的帧率不一样,所以挂在枚举上而不是共用一个常量**:
  ///
  /// - [builtin] 用 **1 fps**。四帧轮转的意义是肉眼判断卡帧/丢帧,10 fps 下白块
  ///   转一圈只要 400 ms,看着就是一片闪烁,根本读不出帧号;1 fps 下每秒落一帧,
  ///   能逐帧对着设备屏确认「这一帧到了、序号对不对」。协议时序也更好读 —— 日志
  ///   里每条推帧记录间隔一秒,而不是十条挤在一起。
  /// - [camera] 保持 **10 fps**。它的用途就是加压,1 fps 压不出任何东西。
  ///
  /// **1 fps 是安全下限,不要再往下调**:§6.4 的帧超时是 3 s
  /// (`EBadgeStreamTransport.frameGapLimit`)。1 fps 下跳一个 tick 间隔就到 2 s,
  /// 连跳两个正好撞上 3 s,设备会把会话清掉 —— 现象是「推着推着自己断了」,而真因
  /// 是帧源没跟上。[builtin] 顶得住是因为它预热后 `at()` 恒非 null、不会跳 tick;
  /// [camera] 的帧槽会空,所以它绝不能用 1 fps。
  final int defaultFps;

  /// 按 [name] 反查,认不出就退回 [builtin]。
  ///
  /// 存的是名字而不是序号:序号会随枚举增删悄悄错位,把旧配置里的 0 读成另一个源,
  /// 而「我明明选的是内置帧」这种偏差在界面上看不出来。
  static EBadgeStreamSource byName(String? name) =>
      EBadgeStreamSource.values.firstWhere(
        (s) => s.name == name,
        orElse: () => EBadgeStreamSource.builtin,
      );
}

/// 摄像头源帧率滑条的下界。
///
/// 1 fps 在**摄像头源上是有风险的**(内置帧不然):内置帧预热后 `at()` 恒非 null、
/// 不会跳 tick,而摄像头的帧槽会空 —— 1 fps 下跳一个 tick 就是 2 s 间隔,连跳两个
/// 正好撞上 §6.4 的 3 s 帧超时,设备会把会话清掉。
///
/// 仍然放开到 1 是因为这是**调试台**:「设备在帧超时边缘怎么表现」本身就是要观察的
/// 现象之一,而 [EBadgeStreamTransport.frameGapLimit] 的自检会把超时如实报出来,不会
/// 变成一个查不出因由的断线。
const int kEBadgeStreamFpsMin = 1;

/// 摄像头源帧率滑条的上界。
///
/// 40 fps 远超设备实际吞吐(466×466 JPEG 每帧 20–40 KB,40 fps 就是 800–1600 KB/s),
/// 放这么高是为了**压出上限**:一路往上推,看推送侧从第几档开始攒跳帧数,那个拐点就是
/// 这条链路的真实容量。协议侧也容得下 —— 0x08 OFFER 的 fps 是 uint8(1–255)。
const int kEBadgeStreamFpsMax = 40;

/// JPEG 质量滑条的下界。再低下去 466×466 的块效应会盖住画面内容,
/// 「设备显示不对」和「本来就编得糊」就分不开了。
const int kEBadgeStreamQualityMin = 10;

/// JPEG 质量滑条的上界。IJG 质量档的定义上限。
const int kEBadgeStreamQualityMax = 100;

/// 调试页会被记住的那几个选择。
@immutable
class EBadgeDebugConfig {
  const EBadgeDebugConfig({
    this.xferWithHeader = false,
    this.demoPresetSlug = kDefaultDemoPresetSlug,
    this.streamSource = EBadgeStreamSource.builtin,
    this.autoScroll = true,
    this.cameraFps = _defaultCameraFps,
    this.cameraQuality = _defaultCameraQuality,
  });

  /// 摄像头源的默认帧率 / 质量。取自枚举与原生默认档,保持单一来源 ——
  /// 两处各写一个字面量,迟早会对不上。
  static const int _defaultCameraFps = 10;
  static const int _defaultCameraQuality = 80;

  /// §5 传图正文是否套那 16 字节设备图片头。
  ///
  /// **默认不带头**:§5.2 字面上说 payload 是「原始文件字节」,裸 JFIF 才是字面
  /// 一致的那一份,而且此时 Offer 里报的 `file_type=JPEG` 名副其实。带头是与图片页
  /// 对照用的另一种封装,要试就显式打开 —— 默认值是每轮调试的起点,起点该落在
  /// 协议写着的那一种上。
  final bool xferWithHeader;

  /// 测试图档位,存的是 [EBadgeDemoPreset.slug]。
  ///
  /// 存 slug 不存索引:[kEBadgeDemoPresets] 的顺序就是调试顺序(由小到大),将来
  /// 插一档进中间是很可能的事,而索引一旦错位,旧配置就会静默指向另一档 —— 于是
  /// 界面显示「极小 ~6K」而实际传的是别的体积,这正是最不该出错的地方。
  final String demoPresetSlug;

  /// §6 推流的帧源。
  ///
  /// 记住 [EBadgeStreamSource.camera] 是安全的:选中本身不开相机,相机只在按下
  /// 「开始推流」时才打开(也才申请权限),所以进页面不会因为上次选过摄像头就
  /// 弹权限框或点亮相机指示灯。
  final EBadgeStreamSource streamSource;

  /// 日志区是否跟着新记录自动滚到底。
  final bool autoScroll;

  /// 摄像头源请求的帧率(1–40,见 [kEBadgeStreamFpsMin] / [kEBadgeStreamFpsMax])。
  ///
  /// 只作用于 [EBadgeStreamSource.camera]。内置帧固定 1 fps —— 它的四帧轮转是给
  /// 肉眼数帧号用的,调快就只剩一片闪烁,那个源没有「可调帧率」的需求。
  ///
  /// 这个值会进 0x08 OFFER,设备可以回 decision=2 协商成更低的值。
  final int cameraFps;

  /// 摄像头源的 JPEG 质量(10–100)。
  ///
  /// 直接决定单帧体积,而单帧体积正是这条链路的瓶颈所在:466×466 在 q=80 下每帧
  /// 20–40 KB,10 fps 就要 200–400 KB/s。往下调质量是遇到推送侧背压(进度里的
  /// 「跳 N 帧」)时**最快见效**的一档旋钮,所以它得能一边推一边调。
  final int cameraQuality;

  /// 当前档位在 [kEBadgeDemoPresets] 里的下标;slug 认不出就退回第 0 档。
  ///
  /// 界面用下标(ChoiceChip 的选中态),存储用 slug,转换收在这里一处 —— 两边各自
  /// 直接读对方的表示,迟早会漏掉某个「认不出」的分支。
  int get demoPresetIndex {
    final i = kEBadgeDemoPresets.indexWhere((p) => p.slug == demoPresetSlug);
    return i < 0 ? 0 : i;
  }

  EBadgeDebugConfig copyWith({
    bool? xferWithHeader,
    String? demoPresetSlug,
    EBadgeStreamSource? streamSource,
    bool? autoScroll,
    int? cameraFps,
    int? cameraQuality,
  }) =>
      EBadgeDebugConfig(
        xferWithHeader: xferWithHeader ?? this.xferWithHeader,
        demoPresetSlug: demoPresetSlug ?? this.demoPresetSlug,
        streamSource: streamSource ?? this.streamSource,
        autoScroll: autoScroll ?? this.autoScroll,
        cameraFps: cameraFps ?? this.cameraFps,
        cameraQuality: cameraQuality ?? this.cameraQuality,
      );

  Map<String, dynamic> toJson() => {
        'xferWithHeader': xferWithHeader,
        'demoPresetSlug': demoPresetSlug,
        'streamSource': streamSource.name,
        'autoScroll': autoScroll,
        'cameraFps': cameraFps,
        'cameraQuality': cameraQuality,
      };

  /// 逐字段带默认值地读。
  ///
  /// 每个字段都单独兜底(而不是整个文件解析失败才退回默认):加了新字段之后,旧的
  /// 配置文件缺的就是那一个键,不该因此把用户其他几项选择一起丢掉。
  ///
  /// 兜底要连**类型不对**一起兜住,不能只写 `as bool?` —— 那种写法只容忍 null,遇到
  /// 手改配置留下的 `"true"` 会抛。抛出去虽然被 [EBadgeDebugConfigStore.load] 接住,
  /// 但那是整份退回默认,其余几项选择会一起丢,而这正是逐字段兜底要避免的。
  factory EBadgeDebugConfig.fromJson(Map<String, dynamic> json) {
    final slug = json['demoPresetSlug'];
    return EBadgeDebugConfig(
      xferWithHeader: _bool(json['xferWithHeader'], false),
      demoPresetSlug:
          slug is String && kEBadgeDemoPresets.any((p) => p.slug == slug)
              ? slug
              : kDefaultDemoPresetSlug,
      streamSource: EBadgeStreamSource.byName(json['streamSource'] is String
          ? json['streamSource'] as String
          : null),
      autoScroll: _bool(json['autoScroll'], true),
      cameraFps: _int(json['cameraFps'], _defaultCameraFps, kEBadgeStreamFpsMin,
          kEBadgeStreamFpsMax),
      cameraQuality: _int(json['cameraQuality'], _defaultCameraQuality,
          kEBadgeStreamQualityMin, kEBadgeStreamQualityMax),
    );
  }

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  /// 读一个整数并**夹到合法区间**。
  ///
  /// 夹而不是退回默认:存下来的是用户上次调的值,滑条上界将来若收窄(比如实测发现
  /// 40 fps 毫无意义),夹到新上界比跳回 10 更贴近他的本意。
  ///
  /// 夹这一步是必需的而不是防御性冗余:帧率会进 0x08 OFFER,而
  /// [EBadgeRequest.jpgStreamOffer] 对越界的 fps 直接抛 ArgumentError —— 一个手改
  /// 出来的 `"cameraFps": 0` 会让点「开始推流」变成崩溃而不是失败提示。
  static int _int(Object? v, int fallback, int min, int max) {
    final n = v is num ? v.toInt() : fallback;
    return n.clamp(min, max);
  }
}

/// 默认档位 = 最小的那一档。调试从最小体积开始,确认链路通了再逐档加大。
const String kDefaultDemoPresetSlug = 'xs';

/// 把 [EBadgeDebugConfig] 存到 app support 目录下的一个小 JSON 文件。
///
/// 与 `EncoderConfigStore` 同形(静态 load/save、失败一律吞掉):持久化是**尽力而为**
/// 的,存不下来最坏是下次回到默认档,不该让一个只读文件系统把调试台整个卡住。
class EBadgeDebugConfigStore {
  EBadgeDebugConfigStore._();

  static const _fileName = 'ebadge_debug_config.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 读配置;文件不存在或坏了就返回默认值。
  static Future<EBadgeDebugConfig> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const EBadgeDebugConfig();
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return EBadgeDebugConfig.fromJson(map);
    } catch (_) {
      return const EBadgeDebugConfig();
    }
  }

  /// 写配置。失败吞掉 —— 见类文档。
  static Future<void> save(EBadgeDebugConfig config) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(config.toJson()));
    } catch (_) {}
  }
}
