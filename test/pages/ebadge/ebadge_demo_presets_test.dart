import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/pages/ebadge/ebadge_demo_presets.dart';
import 'package:honeybox/services/image_jpeg.dart';
import 'package:honeybox/services/raster.dart';

// 每档真编一遍,拿到 466×466 的裸 JFIF 长度。走的就是调试页 _encodeDemoJpeg 的同一
// 条路(decode → cover 裁切到 466 → baseline 4:2:0),否则量出来的数没有参照意义。
Future<int> _encodedLength(EBadgeDemoPreset p) async {
  final bytes = await File(p.asset).readAsBytes();
  final src = await decodeUiImage(Uint8List.fromList(bytes));
  try {
    final rgba = await cropResizeToRgba(
      src,
      targetW: kEBadgeDemoImageSize,
      targetH: kEBadgeDemoImageSize,
    );
    return encodeBaselineJpegYuv420(
      rgba.rgba,
      kEBadgeDemoImageSize,
      kEBadgeDemoImageSize,
      quality: p.quality,
    ).length;
  } finally {
    src.dispose();
  }
}

void main() {
  test('每档的示例图资源都存在', () async {
    for (final p in kEBadgeDemoPresets) {
      expect(await File(p.asset).exists(), isTrue,
          reason: '${p.slug} 档指向的 ${p.asset} 不存在');
    }
  });

  // slug 进文件名(wifi_demo_<slug>.bin)。重了的话两档会在设备上覆盖同一个文件,
  // 屏上显示的到底是哪一次的结果就说不清了 —— 而这正是分档想要看清的东西。
  test('slug 互不相同,且只含文件名安全字符', () {
    final seen = <String>{};
    for (final p in kEBadgeDemoPresets) {
      expect(seen.add(p.slug), isTrue, reason: 'slug 重复:${p.slug}');
      expect(p.slug, matches(RegExp(r'^[a-z0-9_]+$')),
          reason: 'slug 会进文件名,只允许小写字母/数字/下划线:${p.slug}');
    }
  });

  test('quality 在 IJG 1..100 范围内', () {
    for (final p in kEBadgeDemoPresets) {
      expect(p.quality, inInclusiveRange(1, 100), reason: p.slug);
    }
  });

  // 档位表的用途就是「按体积从小到大逐档试,看设备在哪一档开始失败」,顺序反了或有
  // 两档实际体积相当,这个用法就失效了。这里核的是 approxBytes 自身单调。
  test('approxBytes 严格递增 —— 表的顺序就是调试顺序', () {
    for (int i = 1; i < kEBadgeDemoPresets.length; i++) {
      expect(
        kEBadgeDemoPresets[i].approxBytes,
        greaterThan(kEBadgeDemoPresets[i - 1].approxBytes),
        reason: '${kEBadgeDemoPresets[i].slug} 不比前一档大',
      );
    }
  });

  // 最小档和最大档要真拉开量级,否则「分档测不同大小」名不副实。
  test('最大档至少是最小档的 10 倍', () {
    final lo = kEBadgeDemoPresets.first.approxBytes;
    final hi = kEBadgeDemoPresets.last.approxBytes;
    expect(hi / lo, greaterThanOrEqualTo(10.0), reason: '$lo B → $hi B');
  });

  // 关键的一条:标签上的「~8K」是给人看的**实测**量级,调试时据此选档、据此判断设备
  // 在哪个量级上开始失败。示例图被换掉或编码器改了参数,这个数就会悄悄失真,而失真
  // 的标签比没有标签更坏 —— 所以真编一遍逐档核对。
  //
  // 容差 5%:编码结果是确定的,但 cover 裁切走 Canvas,不同平台的重采样可能有极小
  // 差异,卡到逐字节会在别的机器上无故变红。
  test('approxBytes 与实际编码长度一致(±5%),标签量级不失真', () async {
    for (final p in kEBadgeDemoPresets) {
      final actual = await _encodedLength(p);
      final drift = (actual - p.approxBytes).abs() / p.approxBytes;
      expect(
        drift,
        lessThan(0.05),
        reason: '${p.slug}(${p.label}):表里写 ${p.approxBytes} B,'
            '实际编出 $actual B —— 请按实测值更新 approxBytes 和标签',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  // 标签里的「~6K / ~115K」必须和 approxBytes 对得上。上面那条盯的是 approxBytes
  // 与真实编码,这条盯的是标签与 approxBytes —— 只改了数没改标签同样会误导人。
  test('标签里的 K 数与 approxBytes 相符', () {
    for (final p in kEBadgeDemoPresets) {
      final m = RegExp(r'~(\d+)K').firstMatch(p.label);
      expect(m, isNotNull, reason: '${p.slug} 的标签应含「~<数字>K」:${p.label}');
      final labelled = int.parse(m!.group(1)!) * 1024;
      // 标签是取整到 K 的,给 1K 的取整余量 + 8% 的相对余量。
      final slack = 1024 + p.approxBytes * 0.08;
      expect(
        (labelled - p.approxBytes).abs(),
        lessThanOrEqualTo(slack),
        reason: '${p.slug} 标签说 ${m.group(1)}K,但 approxBytes=${p.approxBytes} B',
      );
    }
  });
}
