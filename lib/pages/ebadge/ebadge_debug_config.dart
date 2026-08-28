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
  builtin('内置测试帧'),
  camera('摄像头');

  const EBadgeStreamSource(this.label);
  final String label;

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

/// 调试页会被记住的那几个选择。
@immutable
class EBadgeDebugConfig {
  const EBadgeDebugConfig({
    this.xferWithHeader = false,
    this.demoPresetSlug = kDefaultDemoPresetSlug,
    this.streamSource = EBadgeStreamSource.builtin,
    this.autoScroll = true,
  });

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
  }) =>
      EBadgeDebugConfig(
        xferWithHeader: xferWithHeader ?? this.xferWithHeader,
        demoPresetSlug: demoPresetSlug ?? this.demoPresetSlug,
        streamSource: streamSource ?? this.streamSource,
        autoScroll: autoScroll ?? this.autoScroll,
      );

  Map<String, dynamic> toJson() => {
        'xferWithHeader': xferWithHeader,
        'demoPresetSlug': demoPresetSlug,
        'streamSource': streamSource.name,
        'autoScroll': autoScroll,
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
    );
  }

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
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
