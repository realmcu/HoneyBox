// ebadge_demo_presets.dart
//
// 协议调试页 Wi-Fi 传图用的测试图档位表。
//
// 单独成文件(而不是留在 `ebadge_debug_page.dart` 里当私有常量)是为了能测:每档的
// 「~8K」「~115K」这类标签是**实测值**,调试时要靠它判断该选哪档、以及设备是在哪个
// 量级上开始失败。示例图被换掉或编码器改了参数,标签就会悄悄失真,而失真的标签比
// 没有标签更坏 —— 所以 `test/pages/ebadge/ebadge_demo_presets_test.dart` 会真编一遍
// 逐档核对。

import 'package:flutter/foundation.dart' show immutable;

/// 一个测试图档位:选哪张示例图、用哪档 JPEG 质量。
///
/// 尺寸不进这里 —— 各档统一 [kEBadgeDemoImageSize],档位之间**只差体积**。这样
/// 「小的能过、大的不能过」就直接指向字节数/分块/超时,不会和分辨率纠缠。
@immutable
class EBadgeDemoPreset {
  const EBadgeDemoPreset({
    required this.slug,
    required this.label,
    required this.asset,
    required this.quality,
    required this.approxBytes,
  });

  /// 文件名里用的短标识(ASCII)。设备按文件名落盘,几档轮着传时同名会互相覆盖,
  /// 屏上就分不出显示的是哪一次的结果 —— 所以每档的名字必须不同。
  final String slug;

  /// 界面上的短标签,含体积量级。
  final String label;

  /// 示例图资源路径。
  final String asset;

  /// IJG 1..100 质量档。
  final int quality;

  /// 裸 JFIF 的**实测**字节数(在 [kEBadgeDemoImageSize] 下测的,不是估的)。
  ///
  /// 只用来在编码之前给界面一个数量级提示 —— 日志和进度里报的一律是真实长度。
  final int approxBytes;
}

/// 测试图统一边长。466 是设备圆屏的物理分辨率(见图片页的 `_sizePresets`),
/// 传别的尺寸设备还得自己缩放,那就把「缩放对不对」也混进这条链路的变量里了。
const int kEBadgeDemoImageSize = 466;

/// 传图测试档位,按体积从小到大排 —— 这个顺序本身就是调试顺序:先用最小的确认链路
/// 通,再逐档加大去找它在哪一档开始失败。
///
/// 体积差异同时靠**换图**和**换质量**做出来:10 张示例图都是 360×360,同一档质量下
/// 彼此已差 3 倍多(实测 q60 是 7.2K–24K),再叠上质量档就能从 6K 拉到 115K,跨越
/// 一个多数量级。纯靠质量档做不到 —— 同一张图 q30→q100 也只有 4 倍。
///
/// `s` 档(image-1 @ q60)是原先写死的那一档,留在表里且标签不变,好让改动前后的
/// 传输记录仍可直接比对。
const List<EBadgeDemoPreset> kEBadgeDemoPresets = [
  EBadgeDemoPreset(
    slug: 'xs',
    label: '极小 ~6K',
    asset: 'assets/example/img/badge-preset-image-4.png',
    quality: 30,
    approxBytes: 6191,
  ),
  EBadgeDemoPreset(
    slug: 's',
    label: '小 ~8K',
    asset: 'assets/example/img/badge-preset-image-1.png',
    quality: 60,
    approxBytes: 8189,
  ),
  EBadgeDemoPreset(
    slug: 'm',
    label: '中 ~16K',
    asset: 'assets/example/img/badge-preset-image-9.png',
    quality: 60,
    approxBytes: 16051,
  ),
  EBadgeDemoPreset(
    slug: 'l',
    label: '大 ~24K',
    asset: 'assets/example/img/badge-preset-image-8.png',
    quality: 60,
    approxBytes: 24129,
  ),
  EBadgeDemoPreset(
    slug: 'xl',
    label: '超大 ~51K',
    asset: 'assets/example/img/badge-preset-image-8.png',
    quality: 92,
    approxBytes: 51193,
  ),
  EBadgeDemoPreset(
    slug: 'xxl',
    label: '最大 ~115K',
    asset: 'assets/example/img/badge-preset-image-8.png',
    quality: 100,
    approxBytes: 115435,
  ),
];
