import 'dart:convert';

import 'package:flutter/services.dart';

/// 协议调试页 §6 同屏推流用的固定测试帧(4 帧循环)。
///
/// **为什么内嵌 base64 而不是放 assets 或现场编码**:
///
/// - 放 assets 要动 `pubspec.yaml` 的资源清单,而这是纯调试数据,不该进产物的
///   资源目录;
/// - 现场编码要么引入 `package:image`(纯 Dart JPEG 编码,慢且是新依赖),要么
///   去调 `CameraEncoder` 的原生编码器 —— 后者正是**必须避开**的那条路:拍照
///   投屏的 GL/编码链路有自己的会话状态,协议调试页碰它就会互相干扰。
///
/// 内容:64×64,黑底 + 一个 32×32 白块按「左上→右上→左下→右下」四格轮转,块上
/// 印着帧序号。选这个图案是因为**丢帧和卡帧一眼可辨** —— 白块该转不转就是卡了,
/// 跳格就是丢帧;换成静态图或纯色,推 100 帧和推 1 帧在设备上长得一模一样。
///
/// 每帧约 0.8–0.9 KB,20 fps 下码率 ~18 KB/s,不会让 TCP 成为瓶颈,便于把问题
/// 归因到协议时序本身。
abstract class EBadgeStreamDemoFrames {
  /// 解码后的 4 帧 JPEG 字节。首次访问时解一次,之后复用 —— 推流每 tick 都要取
  /// 一帧,现场解 base64 会在 20 fps 下白烧 CPU。
  static List<Uint8List> get frames => _cache ??= _b64
      .map((s) => Uint8List.fromList(base64Decode(s.replaceAll('\n', ''))))
      .toList(growable: false);

  static List<Uint8List>? _cache;

  /// 取第 [i] 帧(自动取模,调用方不必管越界)。
  static Uint8List at(int i) {
    final f = frames;
    return f[i % f.length];
  }

  static const int count = 4;

  /// 一帧的画布尺寸,写在提示文案里用。
  static const int width = 64;
  static const int height = 64;

  static const List<String> _b64 = [
    // 帧 0:白块在左上
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAA0JCgsKCA0LCwsPDg0QFCEVFBISFCgdHhghMC'
        'oyMS8qLi00O0tANDhHOS0uQllCR05QVFVUMz9dY1xSYktTVFH/2wBDAQ4PDxQRFCcVFSdR'
        'Ni42UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUV'
        'H/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL'
        '/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0f'
        'AkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1'
        'dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1N'
        'XW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQF'
        'BgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRob'
        'HBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVm'
        'Z2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExc'
        'bHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD06mTTRW8R'
        'lnlSKNeruwUD8TT643W1Gr+NLTSpixtYl3MgJAJwWP8AQVE5ctrbs6cNQVabTdkk2/RHW2'
        '9zb3UZktp45kBwWjcMM+mRUtcXBCmgeOYbS0ylrdRjMe4kDrjr7j9TXaUQlzIeJoKk4uLu'
        'pK6PmKiiirOUKKKKAPp2uOuT9k+JEEkpCpPGApPupA/UV2NZ2saLZazCsd0jBl+5Ihwy+u'
        'P/AK9Z1It2a6HXhK0aU2p7STT+Zgaj/pXxFsUiO4wxjfjnbjc3P5j867CsrRvD9hoxdrYO'
        '8j8GSQgtj0GAOK1adOLiteuoYurCo4xhtFW9T5ioooqzkCiiigAooooAKKKKACiiigAooo'
        'oAKKKKACiiigAooooAKKKKAP/Z',
    // 帧 1:白块在右上
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAA0JCgsKCA0LCwsPDg0QFCEVFBISFCgdHhghMC'
        'oyMS8qLi00O0tANDhHOS0uQllCR05QVFVUMz9dY1xSYktTVFH/2wBDAQ4PDxQRFCcVFSdR'
        'Ni42UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUV'
        'H/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL'
        '/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0f'
        'AkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1'
        'dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1N'
        'XW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQF'
        'BgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRob'
        'HBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVm'
        'Z2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExc'
        'bHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDzCiiigAoo'
        'ooA+naKK57xHdatJcJpelQ4aWPdJcf8APMEkde3Q89fTmpnLlVzWjSdWfKnbzZuQXNvcb/'
        'Injl2Ha2xw20+hx0qWuP8Ah1/x4Xn/AF1H8q7CiEuaKZpi6KoVpUk72PmKiiiqOYKKKKAP'
        'p2g9DRRSewHH/Dr/AI8Lz/rqP5V2FZui6LbaLDLHbPK4kYMfMIP8gK0qmCcYpM68bVjWry'
        'qQ2Z8xUUUVZyBRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQB/9k=',
    // 帧 2:白块在左下
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAA0JCgsKCA0LCwsPDg0QFCEVFBISFCgdHhghMC'
        'oyMS8qLi00O0tANDhHOS0uQllCR05QVFVUMz9dY1xSYktTVFH/2wBDAQ4PDxQRFCcVFSdR'
        'Ni42UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUV'
        'H/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL'
        '/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0f'
        'AkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1'
        'dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1N'
        'XW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQF'
        'BgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRob'
        'HBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVm'
        'Z2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExc'
        'bHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDzCiiigAoo'
        'ooAKKKKACiiigAooooAKKKKACiiigAooooA+najnnhtojLPKkUY6s7BQPxNSVzmqeHrjV/'
        'EEVxeSo2nRLgQh23HjnjGBk+/QCpk2vhRtQhCcv3krJf1ZeZvW91bXaF7a4imUHBaNwwB/'
        'Cpa4ZLeDSvHttbaWSkboFljDFsZBJHPsAa7mlCXMjTFUI0XFxd1JXV9z5ioooqzlCiiigD'
        '6drn/FGvPpiJZ2a+Zfz8IAM7AeM47n0H/6j0FYGp+E7DVL+S8uJ7oSPjIR1wMDHGVrOopN'
        'WidWEdFVeavsvzGeGPDraaWvr1zJfyg7snOzPJ57n1P/AOs9FXO2Xg3TbK8huop7ovEwZQ'
        'zLjI9flroqdNWja1h4yoqtTnU+a/la3luz5ioooqzkCiiigD//2Q==',
    // 帧 3:白块在右下
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAA0JCgsKCA0LCwsPDg0QFCEVFBISFCgdHhghMC'
        'oyMS8qLi00O0tANDhHOS0uQllCR05QVFVUMz9dY1xSYktTVFH/2wBDAQ4PDxQRFCcVFSdR'
        'Ni42UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUV'
        'H/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL'
        '/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0f'
        'AkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1'
        'dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1N'
        'XW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQF'
        'BgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRob'
        'HBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVm'
        'Z2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExc'
        'bHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDzCiiigAoo'
        'ooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigD6dqOe4htojLcTRxRjjdIwUfm'
        'akrB1rQYdR1CO+v7o/Y7dDmAKQMckncD9Og7VM20tDajGEp2qOy9Lv0RtW9xBdR+ZbzRzJ'
        'nG6Ngwz9RUlcT4XiU+J7qfSUkXSQu0ls4Y4HTPOc/jj6121KEuaNzTFUFQqcqd9E/NX6Pz'
        'PmKiiirOUKKKKAPp2sm51qxXV10a5iffMMZdV8tgR069+nTrWtWZrGhWOsooukYSLwskZw'
        'wHp9PrUT5re6b0HS5/3t7eXR9znJY4bL4hW0WmqsQZAJo4uF6HIwPYA/rXbVlaP4f0/Riz'
        '2yO0rDBkkOWx6dgK1aVOLitTXGVo1ZRUNeVWu92f/Z',
  ];
}
