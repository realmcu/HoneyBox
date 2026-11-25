import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../services/image_jpeg.dart';
import 'ebadge_demo_presets.dart';

/// 协议调试页 §6 同屏推流用的固定测试帧(4 帧循环)。
///
/// 边长**默认**与 Wi-Fi 传图档位统一为 [kEBadgeDemoImageSize] —— 设备圆屏的物理
/// 分辨率。§6.2 的 14 字节流头**不带宽高**,设备只能按 JPEG 自身的 SOF 尺寸解,发
/// 别的尺寸就把「设备缩放对不对」也混进这条链路的变量里了 —— 所以默认值必须落在
/// 设备原生尺寸上。
///
/// 之所以仍然可调(见 [prepare] 的 `size`):排障时「是不是像素太多」是个必须能
/// 单独排除的变量,把边长减半,单帧体积约降到四分之一,若掉帧随之消失,瓶颈就落在
/// 带宽/单帧体积上而不是协议时序上。
///
/// **为什么现场用 Canvas 画 + 纯 Dart 编码,而不是内嵌 base64 或走原生**:
///
/// - 466×466 内嵌 base64 会把源文件撑到几十 KB 的乱码,改一笔图案就得重新生成,
///   没法读也没法审;
/// - 放 assets 要动 `pubspec.yaml` 的资源清单,而这是纯调试数据,不该进产物;
/// - 用不着 `CameraEncoder` 的原生编码器:本类的整个用途就是**不依赖相机**地给出
///   固定画面。想用相机作帧源走 [EBadgeStreamCameraSource],那是并列的另一个源。
///
/// 用 [encodeBaselineJpegYuv420](纯 Dart,项目里已有)编码,不引入新依赖,也不碰
/// 原生。四帧只编一次([prepare]),之后每 tick 只是取数组元素。
///
/// 内容:黑底 + 一个半幅白块按「左上→右上→左下→右下」四格轮转,块上印着帧序号。
/// 选这个图案是因为**丢帧和卡帧一眼可辨** —— 白块该转不转就是卡了,跳格就是丢帧;
/// 换成静态图或纯色,推 100 帧和推 1 帧在设备上长得一模一样。
///
/// 大片纯黑纯白压得很狠,466×466 每帧实测约 6.4 KB(同尺寸照片要 8–24 KB),
/// 10 fps 下码率约 63 KB/s,TCP 不会成为瓶颈 —— 出问题就能归因到协议时序本身。
abstract class EBadgeStreamDemoFrames {
  static const int count = 4;

  /// 一帧的画布边长,**默认**与传图档位共用同一个常量。
  ///
  /// 它只是缺省值:[prepare] 收了一个可选的 `size`,实际用的边长以那次调用为准 ——
  /// 调试台允许按像素调 (见 [EBadgeDebugConfig.streamSize])。
  static const int width = kEBadgeDemoImageSize;
  static const int height = kEBadgeDemoImageSize;

  /// IJG 质量档。图案是纯黑纯白的硬边,75 已经看不出块效应,再高只是白涨体积。
  static const int quality = 75;

  static List<Uint8List>? _cache;

  /// [_cache] 对应的边长。它只在 [prepare] **成功**之后才更新 —— 跟着 `_cache`
  /// 走,两者必须描述同一批字节。提前改它的话,一次失败的编码会让「尺寸」和
  /// 「帧数组」对不上,而下一次 [prepare] 就会把旧尺寸的四帧当成新尺寸直接复用。
  static int _cachedSize = width;

  static Future<List<Uint8List>>? _pending;

  /// 四帧是否已就绪。界面据此说明「首帧要先编码」。
  static bool get ready => _cache != null;

  /// 已编好的那四帧的边长([ready] 为真时才有意义)。
  static int get cachedSize => _cachedSize;

  /// 预编四帧。**推流前必须先 await 它** —— 编码要走 Canvas(异步)且四帧合计几十
  /// 毫秒到几百毫秒(边长翻倍则约四倍),而 [at] 是同步的,拿不到就只能跳过那一 tick。
  ///
  /// [size] 与已缓存的那一档相同时复用现有结果;**不同则重编**。不重编的话,用户
  /// 把边长改小后界面读数变了、推出去的还是旧尺寸,而设备屏上除了「没变化」看不出
  /// 任何异常 —— 这条链路最难查的就是这种「设置没生效」。
  ///
  /// 重编期间 [_cache] 会被清空(于是 [at] 返回 null、会话跳过这几 tick),而不是
  /// 继续供着旧尺寸的帧:宁可让画面停一下,也不能让「设置说 256、推的却是 466」
  /// 这种不一致出现。
  static Future<List<Uint8List>> prepare({int size = width}) {
    if (_cache != null && _cachedSize == size) {
      return Future.value(_cache!);
    }
    // 同一尺寸的重入(界面重画、连点两次)复用正在进行的那一次。
    final pending = _pending;
    if (pending != null && _pendingSize == size) return pending;
    _cache = null;
    _pendingSize = size;
    return _pending = _build(size);
  }

  /// 正在编的那一次对应的边长,用来判断能不能复用 [pending]。
  static int? _pendingSize;

  /// 取第 [i] 帧(自动取模,调用方不必管越界)。尚未 [prepare] 完成时返回 null,
  /// 会话会把这一 tick 当作「没有新画面」跳过(§6.2 的 size 是 payload 长度,
  /// 推空帧没有意义)。
  static Uint8List? at(int i) {
    final f = _cache;
    if (f == null) return null;
    return f[i % f.length];
  }

  static Future<List<Uint8List>> _build(int size) async {
    try {
      final out = <Uint8List>[];
      for (var i = 0; i < count; i++) {
        out.add(await _encodeFrame(i, size));
      }
      // 尺寸只在这里更新:它和 `_cache` 必须同时生效,见 [cachedSize]。
      _cachedSize = size;
      return _cache = out;
    } catch (_) {
      // 编码失败就把 Future 撤掉,否则一次偶发失败会让「重试」永远拿到同一个已失败
      // 的 Future,按多少次都起不来。
      if (_pendingSize == size) _pending = null;
      rethrow;
    }
  }

  static Future<Uint8List> _encodeFrame(int index, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final double w = size.toDouble();
    final double h = size.toDouble();

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    // 四格轮转:0 左上、1 右上、2 左下、3 右下。
    final double bw = w / 2;
    final double bh = h / 2;
    final double bx = (index % 2) * bw;
    final double by = (index ~/ 2) * bh;
    final ui.Rect block = ui.Rect.fromLTWH(bx, by, bw, bh);
    canvas.drawRect(block, ui.Paint()..color = const ui.Color(0xFFFFFFFF));

    // 序号印在白块中间,黑字 —— 卡帧时白块位置不变,但只要序号还在跳就说明是设备
    // 侧在重复显示同一格,而不是我们停止了推送。
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: bh * 0.6,
      fontWeight: ui.FontWeight.w700,
    ))
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
      ..addText('$index');
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: bw));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(bx, by + (bh - paragraph.height) / 2),
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final ByteData? bd =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    picture.dispose();
    if (bd == null) {
      throw StateError('测试帧像素读取失败');
    }
    return encodeBaselineJpegYuv420(
      bd.buffer.asUint8List(),
      size,
      size,
      quality: quality,
    );
  }
}
