import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/launcher/app_catalog.dart' show AppId;

/// 当前 Launcher 之上激活的应用；`null` 表示用户正在 Launcher 页面。
/// 由 Launcher push `<App>AppRoot` 前设为对应 [AppId]。断连回退与
/// 共享 widget（如设置页）可据此感知当前应用上下文。
/// 不用于 BLE 业务过滤——过滤仍走 ScanPage 参数。
final currentAppProvider = StateProvider<AppId?>((_) => null);
