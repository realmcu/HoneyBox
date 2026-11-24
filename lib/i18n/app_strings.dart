import 'package:flutter/material.dart';

import '../pages/device/device_features.dart';
import 'watch_strings.dart';
import '../pages/launcher/app_catalog.dart';
import '../services/file_cache.dart';

/// Every user-visible string of the app.
///
/// Same model as the native dashboard (`android/mapfeature/.../i18n`): one
/// abstract class, one object per language, resolved once per frame through
/// [AppStringsScope]. Adding a language is one new subclass; the compiler
/// flags every missing member.
///
/// Still-unmigrated screens keep their literals for now — this class grows
/// module by module.
abstract class AppStrings {
  const AppStrings();

  /// Copy for the calling widget's language.
  static AppStrings of(BuildContext context) => AppStringsScope.of(context);

  String appTitle(AppId id);
  String appSubtitle(AppId id);
  String featureTitle(DeviceFeatureId id);
  String cacheKindLabel(CacheKind kind);

  /// Watch app copy (its own group, see `watch_strings.dart`).
  WatchStrings get watch;

  /// "<kind> cache" used as a card / preview title.
  String cacheKindTitle(String label);

  // ── Launcher feedback and app-switch dialog ─────────────────────────────

  String get openMapFailed;
  String get mapUnsupported;
  String openMapFailedWith(Object error);
  String get switchAppTitle;
  String switchAppBody(String connectedName, String targetName);
  String get disconnectAndOpen;
  String featureInProgress(String title);

  String get cancel;
  String get confirm;
  String get delete;
  String get clear;
  String get stop;
  String get disconnect;
  String get open;
  String get retry;
  String get languageTooltip;
  String get languageFollowSystem;
  String get languageChinese;
  String get languageEnglish;
  String get launcherTitle;
  String get menuQiniuFiles;
  String get menuQiniuConfig;
  String get menuChipConfig;
  String get menuCheckUpdate;
  String get drawerChipConfig;
  String get drawerSettings;
  String get settingsTitle;
  String get settingsSectionStorage;
  String get settingsSectionBluetooth;
  String get settingsSectionDebug;
  String get settingsCacheLimit;
  String settingsUsedOf(String used, int limitMB);
  String get settingsManageCache;
  String settingsManageCacheUsed(String used);
  String get settingsManageCacheHint;
  String get settingsGattClear;
  String get settingsGattClearNoDevice;
  String settingsGattClearWith(String deviceName);
  String get settingsGattClearDialogTitle;
  String get settingsGattClearDialogBody;
  String get settingsGattClearDone;
  String get settingsGattClearFailed;
  String get settingsDebugMode;
  String get settingsDebugModeBody;
  String get updateIosOnly;
  String get updateMacOnly;
  String updateCheckFailed(Object error);
  String updateUpToDate(String version);
  String updateFoundTitle(String version);
  String updateConfirmBody(String currentVersion);
  String get updateDownloadInstall;
  String get updateLater;
  String updateAlreadyTitle(String version);
  String get updateAlreadyBody;
  String get updateContinueInstall;
  String get updateRedownload;
  String updateDownloadFailed(Object error);
  String get updateUnknownError;
  String get updateNeedInstallPermission;
  String updateCannotOpenInstaller(String message);
  String get updatePickTitle;
  String get updatePickBody;
  String get updateFromGithub;
  String get updateFromGitee;
  String get updateChecking;
  String get updateDownloadingTitle;
  String get updateDownloading;
  String get scanConnectFailed;
  String get scanSubtitle;
  String get scanSavedHistory;
  String get scanScan;
  String get scanConnect;
  String get scanSelect;
  String get scanFilterHint;
  String get scanOnlyConnectable;
  String get scanOnlyNamed;
  String get scanSortBySignal;
  String get scanLocationOff;
  String get scanWhy;
  String get scanWhyTitle;
  String get scanWhyBody;
  String get scanTurnOn;
  String scanSearching(String appName);
  String get scanPullToRescan;
  String get scanNoDevices;
  String get scanEnsureOn;
  String scanNoMatch(String filter);
  String get scanRescan;
  String manufacturerTag(String key, String value);
  String get tagConnectable;
  String get tagNotConnectable;
  String get tagDebug;
  String get unknownDevice;
  String get cacheUncompressed;
  String cacheFrames(int count);
  String cacheImages(int count);
  String get cacheNoThumbnail;
  String get cacheLoadTooltip;
  String cachePick(String label);
  String cacheEmptyFor(String label);
  String get cacheReplace;
  String get cacheCancelLoad;
  String cachePreview(String label);
  String get cacheTabContent;
  String get cacheTabThumbnail;
  String get cacheVideoNoPreview;
  String get cachePlay;
  String get cachePause;
  String get cacheClearAll;
  String get cacheClearAllBody;
  String get cacheTitle;
  String get cacheEmpty;
  String cacheCount(int count);
  String get cacheLabelAll;
  String get cacheLabelCarousel;
  String get deviceWifiSetup;
  String get deviceNoFeatures;
  String get deviceTypeLabel;
  String get deviceNoFeatureShort;
  String get featureImage;
  String get featureDanmaku;
  String get featureVideo;
  String get featureSlideshow;
  String get featureStream;
  String get featureOta;
  String get featureDebug;
  String get exportThumbnail;
  String get exportCancelled;
  String exportDone(String fileName);
  String exportFailed(Object error);
  String get sendToDevice;
  String get sendSuccess;
  String get sendFailed;
  String get disconnectTitle;
  String get disconnectBody;
  String get paletteTitle;
  String placeholderInProgress(String appName);
  String placeholderConnected(String deviceName);
  String get placeholderDefault;
}

/// Simplified Chinese copy. Kept byte-identical to the literals it replaces.
class ZhStrings extends AppStrings {
  const ZhStrings();

  @override
  String appTitle(AppId id) => switch (id) {
        AppId.ebadge => 'eBadge',
        AppId.watch => 'Watch',
        AppId.dashboard => 'Dashboard',
        AppId.capture => '数据采集',
        AppId.ota => 'OTA',
      };

  @override
  String appSubtitle(AppId id) => switch (id) {
        AppId.ebadge => '电子胸牌调试与内容管理',
        AppId.watch => '智能手表配对与调试',
        AppId.dashboard => '高德地图模拟导航与仪表投屏',
        AppId.capture => '多设备 BLE 原始数据采集与配置管理',
        AppId.ota => '按芯片类型选择固件升级方案',
      };

  @override
  String featureTitle(DeviceFeatureId id) => switch (id) {
        DeviceFeatureId.image => featureImage,
        DeviceFeatureId.danmaku => featureDanmaku,
        DeviceFeatureId.video => featureVideo,
        DeviceFeatureId.slideshow => featureSlideshow,
        DeviceFeatureId.stream => featureStream,
        DeviceFeatureId.ota => featureOta,
        DeviceFeatureId.debug => featureDebug,
      };

  @override
  WatchStrings get watch => const ZhWatchStrings();

  @override
  String cacheKindTitle(String label) => '$label缓存';

  @override
  String get openMapFailed => '无法打开地图功能';

  @override
  String get mapUnsupported => '当前平台不支持地图功能';

  @override
  String openMapFailedWith(Object error) => '无法打开地图功能：$error';

  @override
  String get switchAppTitle => '切换应用';

  @override
  String switchAppBody(String connectedName, String targetName) =>
      '当前已连接 $connectedName。打开 $targetName 前会先断开当前设备。';

  @override
  String get disconnectAndOpen => '断开并打开';

  @override
  String featureInProgress(String title) => '$title 功能开发中';

  @override
  String cacheKindLabel(CacheKind kind) => switch (kind) {
        CacheKind.image => featureImage,
        CacheKind.danmaku => featureDanmaku,
        CacheKind.video => '视频',
      };

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get delete => '删除';

  @override
  String get clear => '清除';

  @override
  String get stop => '停止';

  @override
  String get disconnect => '断开';

  @override
  String get open => '打开';

  @override
  String get retry => '重试';

  @override
  String get languageTooltip => '语言';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get launcherTitle => '选择应用';

  @override
  String get menuQiniuFiles => '七牛云文件';

  @override
  String get menuQiniuConfig => '七牛云配置';

  @override
  String get menuChipConfig => '芯片配置';

  @override
  String get menuCheckUpdate => '检查更新';

  @override
  String get drawerChipConfig => '芯片配置';

  @override
  String get drawerSettings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionStorage => '存储';

  @override
  String get settingsSectionBluetooth => '蓝牙';

  @override
  String get settingsSectionDebug => '调试';

  @override
  String get settingsCacheLimit => '本地缓存上限';

  @override
  String settingsUsedOf(String used, int limitMB) => '已用 $used / $limitMB MB';

  @override
  String get settingsManageCache => '管理本地缓存';

  @override
  String settingsManageCacheUsed(String used) => '当前已用 $used';

  @override
  String get settingsManageCacheHint => '查看并删除已缓存的文件';

  @override
  String get settingsGattClear => '清除服务缓存';

  @override
  String get settingsGattClearNoDevice => '需先连接设备。用于设备升级固件后 App 仍识别不到新功能的情况。';

  @override
  String settingsGattClearWith(String deviceName) =>
      '设备升级固件后若 App 仍提示不支持某功能(如投屏),点此重新读取 $deviceName 的服务表。不一定成功 —— 部分机型会忽略该操作。';

  @override
  String get settingsGattClearDialogTitle => '清除服务缓存？';

  @override
  String get settingsGattClearDialogBody =>
      'App 将丢弃 Android 为这台设备缓存的服务表，并重新读取一次。\\n\\n期间与设备的通信会短暂中断，请勿在传输文件或投屏时操作。\\n\\n注意：部分机型不支持该操作，清除可能不生效。若清除后仍识别不到新功能，可到系统设置里清除「蓝牙」应用的数据，或先取消配对再重新连接。';

  @override
  String get settingsGattClearDone =>
      '已重新读取服务表。若功能仍不可用，请断开后重新连接，或在系统设置里清除「蓝牙」应用数据';

  @override
  String get settingsGattClearFailed => '操作失败：设备可能已断开，或该机型不支持清除缓存';

  @override
  String get settingsDebugMode => '调试模式';

  @override
  String get settingsDebugModeBody =>
      '扫描列表首行会出现虚拟设备 eBadge-debug,用于无实物调试 UI 及交互。虚拟连接不会发送任何真实数据。';

  @override
  String get updateIosOnly => 'iOS 版本请通过原安装渠道更新';

  @override
  String get updateMacOnly => 'macOS 版本请通过原安装渠道更新';

  @override
  String updateCheckFailed(Object error) => '检查更新失败：$error';

  @override
  String updateUpToDate(String version) => '当前已是最新版本（v$version）';

  @override
  String updateFoundTitle(String version) => '发现新版本 v$version';

  @override
  String updateConfirmBody(String currentVersion) =>
      '当前版本 v$currentVersion，是否下载并安装最新版本？';

  @override
  String get updateDownloadInstall => '下载并安装';

  @override
  String get updateLater => '以后再说';

  @override
  String updateAlreadyTitle(String version) => '已下载 v$version';

  @override
  String get updateAlreadyBody => '检测到本地已有校验通过的安装包，可直接安装，无需重新下载。';

  @override
  String get updateContinueInstall => '继续安装';

  @override
  String get updateRedownload => '重新下载';

  @override
  String updateDownloadFailed(Object error) => '下载失败：$error';

  @override
  String get updateUnknownError => '未知错误';

  @override
  String get updateNeedInstallPermission => '需要“安装未知应用”权限才能完成更新';

  @override
  String updateCannotOpenInstaller(String message) => '无法启动安装程序：$message';

  @override
  String get updatePickTitle => '检查更新';

  @override
  String get updatePickBody => '请选择更新来源。GitHub 通常最新；GitHub 无法访问时可改用 Gitee。';

  @override
  String get updateFromGithub => '从 GitHub 更新';

  @override
  String get updateFromGitee => '从 Gitee 更新';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String get updateDownloadingTitle => '正在下载更新';

  @override
  String get updateDownloading => '下载中…';

  @override
  String get scanConnectFailed => '连接失败，请重试';

  @override
  String get scanSubtitle => '扫描设备';

  @override
  String get scanSavedHistory => '已保存历史';

  @override
  String get scanScan => '扫描';

  @override
  String get scanConnect => '连接';

  @override
  String get scanSelect => '选择';

  @override
  String get scanFilterHint => '按名称或地址过滤';

  @override
  String get scanOnlyConnectable => '仅可连接';

  @override
  String get scanOnlyNamed => '仅有名称';

  @override
  String get scanSortBySignal => '信号强度排序';

  @override
  String get scanLocationOff => '定位未开启';

  @override
  String get scanWhy => '说明';

  @override
  String get scanWhyTitle => '为什么需要定位？';

  @override
  String get scanWhyBody =>
      'Android 系统将扫描蓝牙(BLE)设备视为可能推断位置的行为，因此必须开启系统「定位」服务，App 才能搜索到附近的设备。\\n\\n本 App 仅用它来完成蓝牙扫描，不会收集或上传你的地理位置。';

  @override
  String get scanTurnOn => '去开启';

  @override
  String scanSearching(String appName) => '正在搜索附近的 $appName 设备…';

  @override
  String get scanPullToRescan => '下拉可重新扫描';

  @override
  String get scanNoDevices => '未发现设备';

  @override
  String get scanEnsureOn => '请确保设备已开启并靠近手机';

  @override
  String scanNoMatch(String filter) => '没有匹配「$filter」的设备，可清除过滤条件';

  @override
  String get scanRescan => '重新扫描';

  @override
  String manufacturerTag(String key, String value) => '厂商 $key: $value';

  @override
  String get tagConnectable => '可连接';

  @override
  String get tagNotConnectable => '不可连接';

  @override
  String get tagDebug => '调试';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get cacheUncompressed => '未压缩';

  @override
  String cacheFrames(int count) => '$count 帧';

  @override
  String cacheImages(int count) => '$count 图';

  @override
  String get cacheNoThumbnail => '无缩略图';

  @override
  String get cacheLoadTooltip => '载入缓存';

  @override
  String cachePick(String label) => '选择$label缓存';

  @override
  String cacheEmptyFor(String label) => '暂无$label缓存';

  @override
  String get cacheReplace => '更换缓存';

  @override
  String get cacheCancelLoad => '取消载入';

  @override
  String cachePreview(String label) => '预览$label缓存';

  @override
  String get cacheTabContent => '内容';

  @override
  String get cacheTabThumbnail => '缩略图';

  @override
  String get cacheVideoNoPreview => '视频缓存 · 无法预览';

  @override
  String get cachePlay => '播放';

  @override
  String get cachePause => '暂停';

  @override
  String get cacheClearAll => '清空缓存';

  @override
  String get cacheClearAllBody => '将删除全部本地缓存文件，此操作不可恢复。';

  @override
  String get cacheTitle => '本地缓存';

  @override
  String get cacheEmpty => '暂无缓存';

  @override
  String cacheCount(int count) => '共 $count 项';

  @override
  String get cacheLabelAll => '全部';

  @override
  String get cacheLabelCarousel => '多图轮播';

  @override
  String get deviceWifiSetup => 'WiFi 配网';

  @override
  String get deviceNoFeatures => '该设备类型暂无可用功能';

  @override
  String get deviceTypeLabel => '设备类型';

  @override
  String get deviceNoFeatureShort => '暂无功能';

  @override
  String get featureImage => '图片';

  @override
  String get featureDanmaku => '弹幕';

  @override
  String get featureVideo => '视频 / GIF';

  @override
  String get featureSlideshow => '多图轮播';

  @override
  String get featureStream => '拍照投屏';

  @override
  String get featureOta => 'OTA 升级';

  @override
  String get featureDebug => '协议调试';

  @override
  String get exportThumbnail => '导出缩略图';

  @override
  String get exportCancelled => '已取消导出';

  @override
  String exportDone(String fileName) => '已导出: $fileName';

  @override
  String exportFailed(Object error) => '导出失败: $error';

  @override
  String get sendToDevice => '发送到设备';

  @override
  String get sendSuccess => '发送成功';

  @override
  String get sendFailed => '发送失败';

  @override
  String get disconnectTitle => '断开连接';

  @override
  String get disconnectBody => '确认断开设备连接?';

  @override
  String get paletteTitle => '调色板';

  @override
  String placeholderInProgress(String appName) => '$appName 功能开发中';

  @override
  String placeholderConnected(String deviceName) => '已连接：$deviceName';

  @override
  String get placeholderDefault => '功能开发中，敬请期待';
}

/// English copy.
class EnStrings extends AppStrings {
  const EnStrings();

  @override
  String appTitle(AppId id) => switch (id) {
        AppId.ebadge => 'eBadge',
        AppId.watch => 'Watch',
        AppId.dashboard => 'Dashboard',
        AppId.capture => 'Capture',
        AppId.ota => 'OTA',
      };

  @override
  String appSubtitle(AppId id) => switch (id) {
        AppId.ebadge => 'Badge debugging and content management',
        AppId.watch => 'Watch pairing and debugging',
        AppId.dashboard => 'AMap simulated navigation and meter casting',
        AppId.capture =>
          'Raw BLE capture and configuration for several devices',
        AppId.ota => 'Pick the firmware upgrade path by chip type',
      };

  @override
  String featureTitle(DeviceFeatureId id) => switch (id) {
        DeviceFeatureId.image => featureImage,
        DeviceFeatureId.danmaku => featureDanmaku,
        DeviceFeatureId.video => featureVideo,
        DeviceFeatureId.slideshow => featureSlideshow,
        DeviceFeatureId.stream => featureStream,
        DeviceFeatureId.ota => featureOta,
        DeviceFeatureId.debug => featureDebug,
      };

  @override
  WatchStrings get watch => const EnWatchStrings();

  @override
  String cacheKindTitle(String label) => '$label cache';

  @override
  String get openMapFailed => 'Could not open the map';

  @override
  String get mapUnsupported => 'The map is not available on this platform';

  @override
  String openMapFailedWith(Object error) => 'Could not open the map: $error';

  @override
  String get switchAppTitle => 'Switch app';

  @override
  String switchAppBody(String connectedName, String targetName) =>
      '$connectedName is connected. Opening $targetName disconnects it first.';

  @override
  String get disconnectAndOpen => 'Disconnect and open';

  @override
  String featureInProgress(String title) => '$title · under construction';

  @override
  String cacheKindLabel(CacheKind kind) => switch (kind) {
        CacheKind.image => 'Images',
        CacheKind.danmaku => 'Danmaku',
        CacheKind.video => 'Video',
      };

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get stop => 'Stop';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get open => 'Open';

  @override
  String get retry => 'Retry';

  @override
  String get languageTooltip => 'Language';

  @override
  String get languageFollowSystem => 'Follow system';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get launcherTitle => 'Apps';

  @override
  String get menuQiniuFiles => 'Qiniu files';

  @override
  String get menuQiniuConfig => 'Qiniu settings';

  @override
  String get menuChipConfig => 'Chip configuration';

  @override
  String get menuCheckUpdate => 'Check for updates';

  @override
  String get drawerChipConfig => 'Chip configuration';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionStorage => 'Storage';

  @override
  String get settingsSectionBluetooth => 'Bluetooth';

  @override
  String get settingsSectionDebug => 'Debug';

  @override
  String get settingsCacheLimit => 'Local cache limit';

  @override
  String settingsUsedOf(String used, int limitMB) => 'Used $used / $limitMB MB';

  @override
  String get settingsManageCache => 'Manage local cache';

  @override
  String settingsManageCacheUsed(String used) => 'Currently using $used';

  @override
  String get settingsManageCacheHint => 'Review and delete cached files';

  @override
  String get settingsGattClear => 'Clear service cache';

  @override
  String get settingsGattClearNoDevice =>
      'Connect a device first. Use this when the app still misses features after a firmware update.';

  @override
  String settingsGattClearWith(String deviceName) =>
      'If a feature (such as casting) is still reported missing after a firmware update, tap to re-read the service table of $deviceName. Not guaranteed: some ROMs ignore it.';

  @override
  String get settingsGattClearDialogTitle => 'Clear the service cache?';

  @override
  String get settingsGattClearDialogBody =>
      'The app discards the service table Android cached for this device and reads it again.\\n\\nCommunication is briefly interrupted, so do not do this while transferring files or casting.\\n\\nNote: some ROMs ignore the request. If the feature is still missing afterwards, clear the data of the system Bluetooth app, or unpair and reconnect.';

  @override
  String get settingsGattClearDone =>
      'Service table re-read. If the feature is still unavailable, disconnect and reconnect, or clear the system Bluetooth app data.';

  @override
  String get settingsGattClearFailed =>
      'Failed: the device may be disconnected, or this ROM does not support clearing the cache.';

  @override
  String get settingsDebugMode => 'Debug mode';

  @override
  String get settingsDebugModeBody =>
      'A virtual eBadge-debug device appears at the top of the scan list for UI testing without hardware. It never sends real data.';

  @override
  String get updateIosOnly =>
      'Update iOS builds through the original install channel';

  @override
  String get updateMacOnly =>
      'Update macOS builds through the original install channel';

  @override
  String updateCheckFailed(Object error) => 'Update check failed: $error';

  @override
  String updateUpToDate(String version) => 'Already up to date (v$version)';

  @override
  String updateFoundTitle(String version) => 'Version v$version is available';

  @override
  String updateConfirmBody(String currentVersion) =>
      'Current version is v$currentVersion. Download and install the latest?';

  @override
  String get updateDownloadInstall => 'Download and install';

  @override
  String get updateLater => 'Later';

  @override
  String updateAlreadyTitle(String version) => 'v$version already downloaded';

  @override
  String get updateAlreadyBody =>
      'A verified package is already on this device; install it without downloading again.';

  @override
  String get updateContinueInstall => 'Install now';

  @override
  String get updateRedownload => 'Download again';

  @override
  String updateDownloadFailed(Object error) => 'Download failed: $error';

  @override
  String get updateUnknownError => 'unknown error';

  @override
  String get updateNeedInstallPermission =>
      'The install-unknown-apps permission is required to finish the update';

  @override
  String updateCannotOpenInstaller(String message) =>
      'Could not start the installer: $message';

  @override
  String get updatePickTitle => 'Check for updates';

  @override
  String get updatePickBody =>
      'Pick an update source. GitHub is usually newest; use Gitee when GitHub is unreachable.';

  @override
  String get updateFromGithub => 'Update from GitHub';

  @override
  String get updateFromGitee => 'Update from Gitee';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateDownloadingTitle => 'Downloading update';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get scanConnectFailed => 'Connection failed, please retry';

  @override
  String get scanSubtitle => 'Scan devices';

  @override
  String get scanSavedHistory => 'Saved history';

  @override
  String get scanScan => 'Scan';

  @override
  String get scanConnect => 'Connect';

  @override
  String get scanSelect => 'Select';

  @override
  String get scanFilterHint => 'Filter by name or address';

  @override
  String get scanOnlyConnectable => 'Connectable only';

  @override
  String get scanOnlyNamed => 'Named only';

  @override
  String get scanSortBySignal => 'Sort by signal';

  @override
  String get scanLocationOff => 'Location is off';

  @override
  String get scanWhy => 'Why?';

  @override
  String get scanWhyTitle => 'Why does it need location?';

  @override
  String get scanWhyBody =>
      'Android treats BLE scanning as potentially revealing location, so the system location service must be on before the app can find nearby devices.\\n\\nThe app only uses it for scanning and never collects or uploads your location.';

  @override
  String get scanTurnOn => 'Turn on';

  @override
  String scanSearching(String appName) =>
      'Searching for nearby $appName devices…';

  @override
  String get scanPullToRescan => 'Pull down to scan again';

  @override
  String get scanNoDevices => 'No devices found';

  @override
  String get scanEnsureOn =>
      'Make sure the device is on and close to the phone';

  @override
  String scanNoMatch(String filter) =>
      'No device matches $filter; clear the filter';

  @override
  String get scanRescan => 'Scan again';

  @override
  String manufacturerTag(String key, String value) => 'Vendor $key: $value';

  @override
  String get tagConnectable => 'Connectable';

  @override
  String get tagNotConnectable => 'Not connectable';

  @override
  String get tagDebug => 'Debug';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get cacheUncompressed => 'Uncompressed';

  @override
  String cacheFrames(int count) => '$count frames';

  @override
  String cacheImages(int count) => '$count images';

  @override
  String get cacheNoThumbnail => 'No thumbnail';

  @override
  String get cacheLoadTooltip => 'Load from cache';

  @override
  String cachePick(String label) => 'Choose cache: $label';

  @override
  String cacheEmptyFor(String label) => 'No cache yet: $label';

  @override
  String get cacheReplace => 'Replace cache';

  @override
  String get cacheCancelLoad => 'Cancel load';

  @override
  String cachePreview(String label) => 'Preview cache: $label';

  @override
  String get cacheTabContent => 'Content';

  @override
  String get cacheTabThumbnail => 'Thumbnail';

  @override
  String get cacheVideoNoPreview => 'Video cache · preview unavailable';

  @override
  String get cachePlay => 'Play';

  @override
  String get cachePause => 'Pause';

  @override
  String get cacheClearAll => 'Clear cache';

  @override
  String get cacheClearAllBody =>
      'Deletes every local cache file. This cannot be undone.';

  @override
  String get cacheTitle => 'Local cache';

  @override
  String get cacheEmpty => 'No cache yet';

  @override
  String cacheCount(int count) => '$count items';

  @override
  String get cacheLabelAll => 'All';

  @override
  String get cacheLabelCarousel => 'Carousel';

  @override
  String get deviceWifiSetup => 'Wi-Fi setup';

  @override
  String get deviceNoFeatures => 'No features for this device type';

  @override
  String get deviceTypeLabel => 'Device type';

  @override
  String get deviceNoFeatureShort => 'No features';

  @override
  String get featureImage => 'Images';

  @override
  String get featureDanmaku => 'Danmaku';

  @override
  String get featureVideo => 'Video / GIF';

  @override
  String get featureSlideshow => 'Slideshow';

  @override
  String get featureStream => 'Camera cast';

  @override
  String get featureOta => 'OTA update';

  @override
  String get featureDebug => 'Protocol console';

  @override
  String get exportThumbnail => 'Export thumbnails';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String exportDone(String fileName) => 'Exported: $fileName';

  @override
  String exportFailed(Object error) => 'Export failed: $error';

  @override
  String get sendToDevice => 'Send to device';

  @override
  String get sendSuccess => 'Sent';

  @override
  String get sendFailed => 'Send failed';

  @override
  String get disconnectTitle => 'Disconnect';

  @override
  String get disconnectBody => 'Disconnect the device?';

  @override
  String get paletteTitle => 'Palette';

  @override
  String placeholderInProgress(String appName) =>
      '$appName is under construction';

  @override
  String placeholderConnected(String deviceName) => 'Connected: $deviceName';

  @override
  String get placeholderDefault => 'Under construction, coming soon';
}

/// Provides the copy for the current language to the widget tree.
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStringsScope>()?.strings ??
      const ZhStrings();

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings.runtimeType != strings.runtimeType;
}
