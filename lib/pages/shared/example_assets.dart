import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 内置示例资源清单，随 App 一起打包在 `assets/example/` 下。
///
/// 图片页用 [images]（静态 PNG）；视频页用 [videos]（MOV 短视频）+ [gifs]
/// （GIF 动图）——视频页同时支持这两类。
class ExampleAssets {
  ExampleAssets._();

  static const List<String> images = [
    'assets/example/img/badge-preset-image-1.png',
    'assets/example/img/badge-preset-image-2.png',
    'assets/example/img/badge-preset-image-3.png',
    'assets/example/img/badge-preset-image-4.png',
    'assets/example/img/badge-preset-image-5.png',
    'assets/example/img/badge-preset-image-6.png',
    'assets/example/img/badge-preset-image-7.png',
    'assets/example/img/badge-preset-image-8.png',
    'assets/example/img/badge-preset-image-9.png',
    'assets/example/img/badge-preset-image-10.png',
  ];

  static const List<String> videos = [
    'assets/example/video/badge-preset-video-1.mov',
    'assets/example/video/badge-preset-video-2.mov',
    'assets/example/video/badge-preset-video-4.mov',
  ];

  static const List<String> gifs = [
    'assets/example/gif/badge-preset-gif-1.gif',
    'assets/example/gif/badge-preset-gif-2.gif',
    'assets/example/gif/badge-preset-gif-3.gif',
    'assets/example/gif/badge-preset-gif-4.gif',
  ];
}

/// 把打包的 [assetPath] 复制到临时目录并返回该文件——供需要真实文件路径的原生
/// 流程（视频取首帧 / 转换）使用。重名文件会被覆盖。
Future<File> materializeAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final dir = await getTemporaryDirectory();
  final name = assetPath.split('/').last;
  final file = File('${dir.path}/example_$name');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file;
}

/// 预览区下方的一排圆形示例缩略图：横向滚动，点击回调 [onTap]（索引）。
/// 圆内内容由 [thumbBuilder] 提供（图片直接用 Image.asset，视频首帧另行生成）。
class ExampleStrip extends StatelessWidget {
  final int count;
  final Widget Function(int index) thumbBuilder;
  final void Function(int index) onTap;
  final bool enabled;
  final double size;

  const ExampleStrip({
    super.key,
    required this.count,
    required this.thumbBuilder,
    required this.onTap,
    this.enabled = true,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) => GestureDetector(
            onTap: enabled ? () => onTap(i) : null,
            child: Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              // 边框画在图片之上（foregroundDecoration），而不是作为 decoration
              // 挤占内边距——否则会把图片压进内圈，最外一圈露出底色形成“黑边”。
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SizedBox.expand(child: thumbBuilder(i)),
            ),
          ),
        ),
      ),
    );
  }
}
