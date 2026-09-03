import 'dart:io';

import 'package:flutter/services.dart';

/// Thin bridge to a few Android system settings screens that the Flutter
/// plugins don't expose directly.
class SystemSettings {
  static const _channel = MethodChannel('ebadge/system');

  /// Open the OS location-services (GPS) settings screen so the user can turn
  /// location on — BLE scanning on Android requires it. `permission_handler`
  /// only opens the app's own settings, not this system toggle.
  static Future<void> openLocationSettings() =>
      _channel.invokeMethod('openLocationSettings');

  /// 有没有「所有文件访问权限」(`MANAGE_EXTERNAL_STORAGE`)。
  ///
  /// **三态**:`true` 有、`false` 没有、`null` 压根不适用 —— 非 Android、或系统低于
  /// Android 11(那时没有这个特殊权限这回事)。`null` 时调用方**不该**显示任何授权
  /// 入口:点了也没有对应的设置页可跳。
  ///
  /// 不走 `permission_handler` 查:它在 SDK < 30 上也会调
  /// `Environment.isExternalStorageManager()`(API 30 才有的方法),在 Android 10 上
  /// 直接 `NoSuchMethodError` —— 那是个 `Error`,Flutter 的 MethodChannel 只兜
  /// `RuntimeException`,兜不住就是崩。原生这一侧自己判 `SDK_INT`,不碰那条路。
  static Future<bool?> allFilesAccess() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>('allFilesAccess');
    } catch (_) {
      // 通道不在(单元测试、别的平台)一律当「不适用」。
      return null;
    }
  }

  /// `content://` URI → 绝对路径;解不出(或不在 Android 上)返回 null。
  ///
  /// 给的是**原文件**的路径,不是任何副本 —— 于是每次读都是它此刻的内容。但拿到路径
  /// 不等于读得到:没有 [allFilesAccess] 时分区存储照样拦,调用方要自己复核存在性。
  ///
  /// 纯字符串能算出来的形式(`file:` / `raw:` / `primary:相对路径`)不必过这一趟通道,
  /// `EBadgeDebugConfig.originalPathOf` 在 Dart 侧就解完了;这里补的是必须查
  /// MediaStore 才知道的那两类(`content://media/...`、documents 的 `msf:<数字>`)。
  static Future<String?> resolveUriPath(String? uri) async {
    if (!Platform.isAndroid || uri == null || uri.isEmpty) return null;
    try {
      return await _channel
          .invokeMethod<String>('resolveUriPath', {'uri': uri});
    } catch (_) {
      return null;
    }
  }
}
