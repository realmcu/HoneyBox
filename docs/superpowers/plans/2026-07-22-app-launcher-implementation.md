# App Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 APK 首屏从"直接进入 BLE 扫描"改为"应用选择器"，用户先在卡片列表里选择进入哪个应用（eBadge / Watch / Dashboard），再进入该应用自己的扫描/连接/功能流程。

**Architecture:** 方案 A（详见 `docs/superpowers/specs/2026-07-22-app-launcher-design.md`）——新增 `AppLauncherPage` 作为 `MaterialApp.home`；把原 `AppRoot` 平移为 `EBadgeAppRoot`；参数化 `ScanPage` 使不同应用可复用同一扫描页并按设备名前缀过滤；Watch / Dashboard 有骨架 Root + 复用 `ScanPage` 的骨架扫描页。

**Tech Stack:** Flutter 3.35.7 / Dart 3.9.2 / flutter_riverpod 2.5.1 / permission_handler 11.3.1 / flutter_blue_plus 1.32.6。

## Global Constraints

- **不引入新依赖**：整个 spec 用现有包完成。
- **不动 `BleManager` / `bleNotifierProvider` / `connectedDeviceProvider` 的 API**：Provider 全部保留，语义不变。
- **命名路由不改**：`/image` `/danmaku` `/video` `/slideshow` `/stream` `/wifi` `/chip-config` `/settings` `/cache` `/ota` 归属 eBadge，路径不变。Watch / Dashboard 未来的路由用 `/watch/*` `/dashboard/*` 命名空间。
- **不改 Provider Scope**：`ProviderScope` 仍在 `main.dart` 顶层。
- **kAppCatalog 三个条目 ID**：`AppId.ebadge` / `AppId.watch` / `AppId.dashboard`，`deviceFilter` 分别 `'eBadge'` / `'Watch'` / `'Dashboard'`。
- **每个 `<App>AppRoot` push 时打 route name**：`/ebadge-root` / `/watch-root` / `/dashboard-root`；断连回退按 route name 匹配。
- **首页作为返回根**：从任何页面按返回最终回到 `AppLauncherPage`。
- **不合入 build 破坏性改动**：每个 Task 完成后 `flutter analyze` 必须无 error（warning 允许，但新增 error 需修复）。
- **测试放在 `test/` 目录**：现有项目还没有 test 目录，本 plan 中新增 `test/pages/launcher/` 与 `test/pages/ebadge/`。

---

## File Structure

**新增：**
- `lib/pages/launcher/app_catalog.dart` — 应用元数据静态清单 + `AppId` 枚举
- `lib/pages/launcher/app_launcher_page.dart` — 首页（应用选择器）
- `lib/pages/launcher/widgets/app_card.dart` — 单张应用卡片 widget
- `lib/pages/ebadge/ebadge_app_root.dart` — 原 `AppRoot` 平移
- `lib/pages/watch/watch_app_root.dart` — Watch 应用根
- `lib/pages/dashboard/dashboard_app_root.dart` — Dashboard 应用根
- `lib/pages/shared/app_placeholder_page.dart` — 未实现应用连接后的占位功能页
- `lib/providers/current_app_provider.dart` — 当前所在应用的 Riverpod state
- `test/pages/launcher/app_catalog_test.dart`
- `test/pages/launcher/app_launcher_page_test.dart`

**修改：**
- `lib/pages/scan/scan_page.dart` — 构造函数增加 `defaultDeviceFilter` / `appTitle` 参数；移除硬编码 `'eBadge'`
- `lib/app.dart` — `home` 改为 `AppLauncherPage`；删除内嵌 `AppRoot`（迁到 `ebadge_app_root.dart`）

**不动：** `main.dart` / `theme/*` / 所有 `services/*` / 其他 `pages/*` / `AppDrawer`（Drawer 拆分延后到独立 spec）

---

## Task 1: 参数化 ScanPage（保持 eBadge 行为不变）

**Files:**
- Modify: `lib/pages/scan/scan_page.dart:16-29,172-173`

**Interfaces:**
- Consumes: 无
- Produces: `ScanPage({String defaultDeviceFilter = 'eBadge', String appTitle = 'eBadge'})` — 供 Task 5 / Task 7 / Task 8 传参使用；默认值保持现有 eBadge 行为。

**Rationale:** 一步只做参数化，不改调用方，确保回归零风险。

- [ ] **Step 1: 修改 `ScanPage` 构造函数与内部字段**

打开 `lib/pages/scan/scan_page.dart`，将现有第 13-29 行：

```dart
/// Default name filter — the app is built for eBadge devices, so we hide the
/// noise of surrounding BLE peripherals out of the box. Clearing the filter
/// (or the chip) reveals everything.
const String _kDefaultFilter = 'eBadge';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _filterCtrl =
      TextEditingController(text: _kDefaultFilter);
  String _filter = _kDefaultFilter;
```

改成：

```dart
/// Fallback device-name filter used when a caller doesn't specify one.
const String _kFallbackFilter = 'eBadge';

class ScanPage extends ConsumerStatefulWidget {
  /// BLE-name prefix filter applied by default when the page opens.
  final String defaultDeviceFilter;

  /// AppBar title (e.g. "eBadge" / "Watch"). Used verbatim.
  final String appTitle;

  const ScanPage({
    super.key,
    this.defaultDeviceFilter = _kFallbackFilter,
    this.appTitle = 'eBadge',
  });

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _filterCtrl =
      TextEditingController(text: widget.defaultDeviceFilter);
  late String _filter = widget.defaultDeviceFilter;
```

- [ ] **Step 2: 替换 AppBar 标题为参数化标题**

第 172-173 行处，将：

```dart
appBar: AppBar(
  title: Text('扫描设备', style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
```

改为：

```dart
appBar: AppBar(
  title: Text('${widget.appTitle} · 扫描设备',
      style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
```

- [ ] **Step 3: 替换默认过滤器 Chip 判断**

第 325-327 行两处 `_kDefaultFilter` 改为 `widget.defaultDeviceFilter`：
- `selected: _filter.trim() == _kDefaultFilter,` → `selected: _filter.trim() == widget.defaultDeviceFilter,`
- `_filterCtrl.text = sel ? _kDefaultFilter : '',` → `_filterCtrl.text = sel ? widget.defaultDeviceFilter : '',`

- [ ] **Step 4: `flutter analyze` 验证**

Run:
```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/pages/scan/scan_page.dart
```
Expected: 无 error。

- [ ] **Step 5: 提交**

```bash
git add lib/pages/scan/scan_page.dart
git commit -m "refactor: 参数化 ScanPage 以支持多应用扫描过滤

- 新增 defaultDeviceFilter / appTitle 构造参数（保留默认值 eBadge）
- 硬编码 _kDefaultFilter 改为 widget.defaultDeviceFilter
- AppBar 标题改为 '<appTitle> · 扫描设备'
- 现有调用点行为不变

为后续 Launcher 让 Watch / Dashboard 复用 ScanPage 做准备。"
```

---

## Task 2: 新增 `AppId` 枚举与 `kAppCatalog` 清单

**Files:**
- Create: `lib/pages/launcher/app_catalog.dart`
- Create: `test/pages/launcher/app_catalog_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `enum AppId { ebadge, watch, dashboard }`
  - `class AppEntry { final AppId id; final String title; final String subtitle; final IconData icon; final Color accent; final String deviceFilter; final bool implemented; const AppEntry({...}); }`
  - `const List<AppEntry> kAppCatalog` — 3 项，顺序 ebadge → watch → dashboard
  - `String routeNameFor(AppId id)` → `/ebadge-root` / `/watch-root` / `/dashboard-root`

- [ ] **Step 1: 写失败的测试**

创建 `test/pages/launcher/app_catalog_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebadge_app/pages/launcher/app_catalog.dart';

void main() {
  group('kAppCatalog', () {
    test('contains exactly ebadge, watch, dashboard in this order', () {
      expect(kAppCatalog.map((e) => e.id).toList(),
          [AppId.ebadge, AppId.watch, AppId.dashboard]);
    });

    test('every entry has non-empty title, subtitle, deviceFilter', () {
      for (final e in kAppCatalog) {
        expect(e.title, isNotEmpty, reason: '${e.id} title empty');
        expect(e.subtitle, isNotEmpty, reason: '${e.id} subtitle empty');
        expect(e.deviceFilter, isNotEmpty, reason: '${e.id} filter empty');
        expect(e.icon, isA<IconData>());
      }
    });

    test('only ebadge is marked implemented', () {
      final map = {for (final e in kAppCatalog) e.id: e.implemented};
      expect(map[AppId.ebadge], isTrue);
      expect(map[AppId.watch], isFalse);
      expect(map[AppId.dashboard], isFalse);
    });

    test('device filters are the exact spec values', () {
      final byId = {for (final e in kAppCatalog) e.id: e.deviceFilter};
      expect(byId[AppId.ebadge], 'eBadge');
      expect(byId[AppId.watch], 'Watch');
      expect(byId[AppId.dashboard], 'Dashboard');
    });
  });

  group('routeNameFor', () {
    test('maps each AppId to the spec-defined route name', () {
      expect(routeNameFor(AppId.ebadge), '/ebadge-root');
      expect(routeNameFor(AppId.watch), '/watch-root');
      expect(routeNameFor(AppId.dashboard), '/dashboard-root');
    });
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter test test/pages/launcher/app_catalog_test.dart
```
Expected: 失败，报 `Target of URI doesn't exist: 'package:ebadge_app/pages/launcher/app_catalog.dart'`

- [ ] **Step 3: 实现 `app_catalog.dart`**

创建 `lib/pages/launcher/app_catalog.dart`：

```dart
import 'package:flutter/material.dart';

/// 应用启动器内可选的应用标识。新增应用时：先扩展本枚举，然后在
/// [kAppCatalog] 追加一条对应记录，最后在 lib/app.dart 的路由分发里
/// 增加对应 <App>AppRoot 的构造。
enum AppId { ebadge, watch, dashboard }

@immutable
class AppEntry {
  final AppId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String deviceFilter;
  final bool implemented;

  const AppEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.deviceFilter,
    required this.implemented,
  });
}

const List<AppEntry> kAppCatalog = <AppEntry>[
  AppEntry(
    id: AppId.ebadge,
    title: 'eBadge',
    subtitle: '电子胸牌调试与内容管理',
    icon: Icons.badge_outlined,
    accent: Color(0xFF19519C),
    deviceFilter: 'eBadge',
    implemented: true,
  ),
  AppEntry(
    id: AppId.watch,
    title: 'Watch',
    subtitle: '智能手表配对与调试',
    icon: Icons.watch_outlined,
    accent: Color(0xFF2E7D6B),
    deviceFilter: 'Watch',
    implemented: false,
  ),
  AppEntry(
    id: AppId.dashboard,
    title: '仪表盘',
    subtitle: '车载仪表盘调试',
    icon: Icons.dashboard_outlined,
    accent: Color(0xFFB0603A),
    deviceFilter: 'Dashboard',
    implemented: false,
  ),
];

String routeNameFor(AppId id) {
  switch (id) {
    case AppId.ebadge:
      return '/ebadge-root';
    case AppId.watch:
      return '/watch-root';
    case AppId.dashboard:
      return '/dashboard-root';
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter test test/pages/launcher/app_catalog_test.dart
```
Expected: `All tests passed!` (5 tests)

- [ ] **Step 5: 提交**

```bash
git add lib/pages/launcher/app_catalog.dart test/pages/launcher/app_catalog_test.dart
git commit -m "feat: 新增 AppId 枚举与 kAppCatalog 应用清单

- AppId: ebadge / watch / dashboard
- AppEntry: 元数据（title/subtitle/icon/accent/deviceFilter/implemented）
- routeNameFor(): 生成 /ebadge-root 等 route name
- 单元测试覆盖清单顺序、字段完整性、implemented 标记与 route 映射"
```

---

## Task 3: 新增 `currentAppProvider`

**Files:**
- Create: `lib/providers/current_app_provider.dart`

**Interfaces:**
- Consumes: `AppId` from Task 2
- Produces: `final currentAppProvider = StateProvider<AppId?>((_) => null);` — 表示当前所在应用；`null` 表示在 Launcher。

- [ ] **Step 1: 创建 `current_app_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/launcher/app_catalog.dart' show AppId;

/// 当前 Launcher 之上激活的应用；`null` 表示用户正在 Launcher 页面。
/// 由 Launcher push `<App>AppRoot` 前设为对应 [AppId]。断连回退与
/// 共享 widget（如设置页）可据此感知当前应用上下文。
/// 不用于 BLE 业务过滤——过滤仍走 ScanPage 参数。
final currentAppProvider = StateProvider<AppId?>((_) => null);
```

- [ ] **Step 2: `flutter analyze` 验证**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/providers/current_app_provider.dart
```
Expected: 无 error。

- [ ] **Step 3: 提交**

```bash
git add lib/providers/current_app_provider.dart
git commit -m "feat: 新增 currentAppProvider

追踪 Launcher 之上激活的应用（null 表示在 Launcher）。
供后续 <App>AppRoot 与断连回退逻辑使用。"
```

---

## Task 4: 新增占位功能页 `AppPlaceholderPage`

**Files:**
- Create: `lib/pages/shared/app_placeholder_page.dart`

**Interfaces:**
- Consumes: `bleNotifierProvider` from `providers/ble_provider.dart`
- Produces: `class AppPlaceholderPage extends ConsumerWidget { const AppPlaceholderPage({super.key, required this.appTitle, required this.deviceName}); final String appTitle; final String deviceName; ... }`

**Rationale:** Watch / Dashboard 连接后需要显示一个"功能开发中"的页面，含断开按钮。

- [ ] **Step 1: 先确认 `BleNotifier` 的断开方法名**

```bash
cd /home/wh/workspace/hmi-android-apk && grep -nE "disconnect|Future<void> [a-z]+\(\)" lib/providers/ble_provider.dart
```
记下实际方法名（预期为 `disconnect()`；如果不是，把下面 Step 2 代码里的 `.disconnect()` 替换为实际方法名）。

- [ ] **Step 2: 创建 `app_placeholder_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';

/// 骨架应用（Watch / Dashboard）连接设备后展示的临时功能页。
/// 只显示应用名与已连接设备名，并提供断开按钮。
class AppPlaceholderPage extends ConsumerWidget {
  final String appTitle;
  final String deviceName;

  const AppPlaceholderPage({
    super.key,
    required this.appTitle,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(appTitle,
            style: tt.titleLarge?.copyWith(color: cs.onPrimary)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
                size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('$appTitle 功能开发中', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text('已连接：$deviceName',
                style: tt.bodyMedium?.copyWith(color: cs.outline)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(bleNotifierProvider.notifier).disconnect(),
              icon: const Icon(Icons.link_off),
              label: const Text('断开连接'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: `flutter analyze` 验证**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/pages/shared/app_placeholder_page.dart
```
Expected: 无 error。若报 `disconnect()` 未定义，用 Step 1 找到的实际方法名替换。

- [ ] **Step 4: 提交**

```bash
git add lib/pages/shared/app_placeholder_page.dart
git commit -m "feat: 新增 AppPlaceholderPage 骨架应用占位功能页

供 Watch / Dashboard 等未实现应用在连接后显示；
含应用名 / 设备名 / 断开按钮。"
```

---

## Task 5: 迁移 `AppRoot` → `EBadgeAppRoot`

**Files:**
- Create: `lib/pages/ebadge/ebadge_app_root.dart`
- Modify: `lib/app.dart` — 删除内嵌 `AppRoot` 类

**Interfaces:**
- Consumes: `ScanPage(defaultDeviceFilter, appTitle)` from Task 1；`connectedDeviceProvider` / `transferProgressProvider`（现有）
- Produces: `class EBadgeAppRoot extends ConsumerWidget { const EBadgeAppRoot({super.key}); ... }` — 未连接时显示 `ScanPage(defaultDeviceFilter: 'eBadge', appTitle: 'eBadge')`，已连接时显示 `DevicePage`；断连时 `popUntil` 匹配 `/ebadge-root`。

- [ ] **Step 1: 创建 `ebadge_app_root.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/transfer_provider.dart';
import '../scan/scan_page.dart';
import '../device/device_page.dart';

/// eBadge 应用根：Launcher 之上的第一个页面，作为连接状态门。
/// - 未连接 → [ScanPage]（过滤 eBadge 设备名前缀）
/// - 已连接 → [DevicePage]
///
/// 断连时通过 `popUntil((r) => r.settings.name == '/ebadge-root')`
/// 弹回自己，而不弹到 Launcher。
class EBadgeAppRoot extends ConsumerWidget {
  const EBadgeAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        ref.read(transferProgressProvider.notifier).reset();
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/ebadge-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    if (connected != null) {
      return DevicePage(
        deviceName: connected.name,
        deviceId: connected.deviceId,
      );
    }
    return const ScanPage(
      defaultDeviceFilter: 'eBadge',
      appTitle: 'eBadge',
    );
  }
}
```

- [ ] **Step 2: 修改 `lib/app.dart`——把 `home:` 暂时改为 `EBadgeAppRoot`**

打开 `lib/app.dart`：

**a)** 在 top import 追加：
```dart
import 'pages/ebadge/ebadge_app_root.dart';
```

**b)** 删除以下三个 import 行（它们只被内嵌 AppRoot 使用）：
```dart
import 'providers/ble_provider.dart';
import 'providers/transfer_provider.dart';
import 'pages/scan/scan_page.dart';
```

**c)** 把 `home: const AppRoot(),` 改为：
```dart
home: const EBadgeAppRoot(),
```

**d)** 把 `default:` 分支里 `page = const AppRoot();` 改为 `page = const EBadgeAppRoot();`

**e)** 删除文件底部整个 `class AppRoot extends ConsumerWidget { ... }` 类定义（原文件末尾约 30 行）。

- [ ] **Step 3: `flutter analyze` 验证**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/app.dart lib/pages/ebadge/ebadge_app_root.dart
```
Expected: 无 error。

- [ ] **Step 4: 手动构建烟测**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter build apk --debug 2>&1 | tail -20
```
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **Step 5: 提交**

```bash
git add lib/pages/ebadge/ebadge_app_root.dart lib/app.dart
git commit -m "refactor: 将 AppRoot 迁移为 EBadgeAppRoot

将原 lib/app.dart 内嵌的 AppRoot 抽出到 lib/pages/ebadge/ebadge_app_root.dart，
改名 EBadgeAppRoot。ScanPage 通过参数传入 eBadge 过滤器与标题。
现有行为完全等价。

为后续引入 AppLauncherPage 做准备。"
```

---

## Task 6: 新增 `AppCard` widget

**Files:**
- Create: `lib/pages/launcher/widgets/app_card.dart`

**Interfaces:**
- Consumes: `AppEntry` from Task 2
- Produces: `class AppCard extends StatelessWidget { const AppCard({super.key, required this.entry, required this.onTap}); final AppEntry entry; final VoidCallback onTap; ... }`

- [ ] **Step 1: 创建 `widgets/app_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../app_catalog.dart';

/// 应用启动器里的一张卡片：图标 + 标题 + 副标题；
/// 未实现应用（`entry.implemented == false`）右上角显示"预览"角标。
class AppCard extends StatelessWidget {
  final AppEntry entry;
  final VoidCallback onTap;

  const AppCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, size: 32, color: entry.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.title, style: tt.titleMedium),
                        if (!entry.implemented) ...[
                          const SizedBox(width: 8),
                          _PreviewBadge(color: cs.outline),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  final Color color;
  const _PreviewBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('预览', style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
```

- [ ] **Step 2: `flutter analyze` 验证**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/pages/launcher/widgets/app_card.dart
```
Expected: 无 error。

- [ ] **Step 3: 提交**

```bash
git add lib/pages/launcher/widgets/app_card.dart
git commit -m "feat: 新增 AppCard 应用启动器卡片 widget

图标 + 标题 + 副标题 + 未实现应用右上角'预览'角标。"
```

---

## Task 7: 新增 `AppLauncherPage` 并切换 home

**Files:**
- Create: `lib/pages/launcher/app_launcher_page.dart`
- Create: `test/pages/launcher/app_launcher_page_test.dart`
- Modify: `lib/app.dart` — `home` 改为 `AppLauncherPage`

**Interfaces:**
- Consumes: `kAppCatalog` / `AppId` / `routeNameFor` (Task 2)、`AppCard` (Task 6)、`currentAppProvider` (Task 3)、`EBadgeAppRoot` (Task 5)
- Produces: `class AppLauncherPage extends ConsumerWidget { const AppLauncherPage({super.key}); ... }` — 渲染卡片列表；点击卡片时 `currentAppProvider = entry.id`；Navigator.push 目标 Root（route name 由 `routeNameFor` 决定）。本 Task 内 Watch/Dashboard 走临时的 `_SkeletonRoot`（即 `ScanPage`），Task 8 会替换。

- [ ] **Step 1: 写失败的 widget 测试**

创建 `test/pages/launcher/app_launcher_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ebadge_app/pages/launcher/app_launcher_page.dart';
import 'package:ebadge_app/pages/launcher/app_catalog.dart';
import 'package:ebadge_app/pages/launcher/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  testWidgets('renders one AppCard per kAppCatalog entry', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.byType(AppCard), findsNWidgets(kAppCatalog.length));
  });

  testWidgets('每个应用的 title 都出现在页面上', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    for (final e in kAppCatalog) {
      expect(find.text(e.title), findsOneWidget,
          reason: '${e.title} not rendered');
    }
  });

  testWidgets('未实现应用显示"预览"角标', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.text('预览'), findsNWidgets(2));
  });

  testWidgets('AppBar 标题为"选择应用"', (tester) async {
    await tester.pumpWidget(wrap(const AppLauncherPage()));
    expect(find.widgetWithText(AppBar, '选择应用'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter test test/pages/launcher/app_launcher_page_test.dart
```
Expected: 失败，报文件不存在。

- [ ] **Step 3: 实现 `app_launcher_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/current_app_provider.dart';
import '../ebadge/ebadge_app_root.dart';
import '../scan/scan_page.dart';
import 'app_catalog.dart';
import 'widgets/app_card.dart';

/// APK 打开时首先看到的页面。
/// 从 [kAppCatalog] 读取应用清单，展示为卡片列表。点击后 push 对应
/// `<App>AppRoot`（带 route name，供断连回退 popUntil 匹配）。
class AppLauncherPage extends ConsumerWidget {
  const AppLauncherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择应用'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => Navigator.pushNamed(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '/settings', child: Text('设置')),
              PopupMenuItem(value: '/cache', child: Text('缓存管理')),
              PopupMenuItem(value: '/chip-config', child: Text('芯片配置')),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kAppCatalog.length,
        itemBuilder: (_, i) {
          final entry = kAppCatalog[i];
          return AppCard(
            entry: entry,
            onTap: () => _launch(context, ref, entry),
          );
        },
      ),
    );
  }

  void _launch(BuildContext context, WidgetRef ref, AppEntry entry) {
    ref.read(currentAppProvider.notifier).state = entry.id;
    final name = routeNameFor(entry.id);
    Navigator.of(context).push(MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => _rootFor(entry),
    ));
  }

  /// 每个 AppId 返回对应根页面。Watch / Dashboard 暂用骨架 —— Task 8
  /// 引入 WatchAppRoot / DashboardAppRoot 后替换 switch 分支并删除
  /// _SkeletonRoot 与 ScanPage import。
  Widget _rootFor(AppEntry entry) {
    switch (entry.id) {
      case AppId.ebadge:
        return const EBadgeAppRoot();
      case AppId.watch:
      case AppId.dashboard:
        return _SkeletonRoot(entry: entry);
    }
  }
}

class _SkeletonRoot extends ConsumerWidget {
  final AppEntry entry;
  const _SkeletonRoot({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScanPage(
      defaultDeviceFilter: entry.deviceFilter,
      appTitle: entry.title,
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter test test/pages/launcher/app_launcher_page_test.dart
```
Expected: `All tests passed!` (4 tests)

- [ ] **Step 5: 把 `home` 切换到 `AppLauncherPage`**

打开 `lib/app.dart`：

**a)** import 追加：
```dart
import 'pages/launcher/app_launcher_page.dart';
```

**b)** `home: const EBadgeAppRoot(),` 改为：
```dart
home: const AppLauncherPage(),
```

`default:` 分支保留 `page = const EBadgeAppRoot();`（合理的降级 fallback）。

- [ ] **Step 6: 构建烟测**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter build apk --debug 2>&1 | tail -20
```
Expected: 构建成功。

- [ ] **Step 7: 提交**

```bash
git add lib/pages/launcher/app_launcher_page.dart lib/app.dart \
        test/pages/launcher/app_launcher_page_test.dart
git commit -m "feat: 新增 AppLauncherPage 应用启动器首页

- home: AppLauncherPage（卡片列表展示 kAppCatalog）
- 点击 eBadge 卡进入 EBadgeAppRoot（route name /ebadge-root）
- Watch / Dashboard 暂用骨架 _SkeletonRoot 进入过滤后的 ScanPage
  （Task 8 引入 WatchAppRoot / DashboardAppRoot 后替换）
- AppBar overflow 菜单集成设置 / 缓存 / 芯片配置入口
- widget 测试覆盖卡片数量、标题、预览角标、AppBar 标题"
```

---

## Task 8: 新增 `WatchAppRoot` 与 `DashboardAppRoot`

**Files:**
- Create: `lib/pages/watch/watch_app_root.dart`
- Create: `lib/pages/dashboard/dashboard_app_root.dart`
- Modify: `lib/pages/launcher/app_launcher_page.dart` — 替换 `_SkeletonRoot`；删除 `_SkeletonRoot` 类与 `ScanPage` import

**Interfaces:**
- Consumes: Task 4 `AppPlaceholderPage`；Task 1 `ScanPage(defaultDeviceFilter, appTitle)`
- Produces: `class WatchAppRoot extends ConsumerWidget` / `class DashboardAppRoot extends ConsumerWidget` — 结构对齐 `EBadgeAppRoot`；已连接时显示 `AppPlaceholderPage`；断连时 `popUntil` 匹配自己的 route name。

- [ ] **Step 1: 创建 `watch_app_root.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../scan/scan_page.dart';
import '../shared/app_placeholder_page.dart';

/// Watch 应用根：结构与 EBadgeAppRoot 一致，功能页替换为占位。
class WatchAppRoot extends ConsumerWidget {
  const WatchAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/watch-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    if (connected != null) {
      return AppPlaceholderPage(
        appTitle: 'Watch',
        deviceName: connected.name,
      );
    }
    return const ScanPage(
      defaultDeviceFilter: 'Watch',
      appTitle: 'Watch',
    );
  }
}
```

- [ ] **Step 2: 创建 `dashboard_app_root.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../scan/scan_page.dart';
import '../shared/app_placeholder_page.dart';

/// Dashboard（仪表盘）应用根：结构同 EBadgeAppRoot / WatchAppRoot。
class DashboardAppRoot extends ConsumerWidget {
  const DashboardAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ConnectedDeviceInfo?>(connectedDeviceProvider, (prev, next) {
      if (prev != null && next == null) {
        Navigator.of(context)
            .popUntil((r) => r.settings.name == '/dashboard-root');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开')),
        );
      }
    });

    final connected = ref.watch(connectedDeviceProvider);
    if (connected != null) {
      return AppPlaceholderPage(
        appTitle: '仪表盘',
        deviceName: connected.name,
      );
    }
    return const ScanPage(
      defaultDeviceFilter: 'Dashboard',
      appTitle: '仪表盘',
    );
  }
}
```

- [ ] **Step 3: 更新 `app_launcher_page.dart`，删除 `_SkeletonRoot`**

打开 `lib/pages/launcher/app_launcher_page.dart`：

**a)** import 区追加：
```dart
import '../watch/watch_app_root.dart';
import '../dashboard/dashboard_app_root.dart';
```

**b)** 从 import 区删除：
```dart
import '../scan/scan_page.dart';
```

**c)** 把 `_rootFor` 方法整段替换为：

```dart
  Widget _rootFor(AppEntry entry) {
    switch (entry.id) {
      case AppId.ebadge:
        return const EBadgeAppRoot();
      case AppId.watch:
        return const WatchAppRoot();
      case AppId.dashboard:
        return const DashboardAppRoot();
    }
  }
```

**d)** 删除文件底部整个 `class _SkeletonRoot extends ConsumerWidget { ... }` 类定义。

- [ ] **Step 4: `flutter analyze` 验证**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter analyze lib/pages/launcher lib/pages/watch lib/pages/dashboard
```
Expected: 无 error。

- [ ] **Step 5: 构建烟测**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter build apk --debug 2>&1 | tail -20
```
Expected: 构建成功。

- [ ] **Step 6: 提交**

```bash
git add lib/pages/watch/watch_app_root.dart \
        lib/pages/dashboard/dashboard_app_root.dart \
        lib/pages/launcher/app_launcher_page.dart
git commit -m "feat: 新增 WatchAppRoot 与 DashboardAppRoot

- 结构对齐 EBadgeAppRoot：未连接→过滤后的 ScanPage，已连接→AppPlaceholderPage
- 断连回退按 route name /watch-root / /dashboard-root 精准匹配
- 移除 AppLauncherPage 里过渡用的 _SkeletonRoot 与 ScanPage import"
```

---

## Task 9: 手动回归测试

**Files:**
- Create: `docs/superpowers/reports/2026-07-22-app-launcher-manual-test.md`

**Interfaces:**
- Consumes: 前 8 个 Task 的产出
- Produces: 手动验证记录

- [ ] **Step 1: 用调试模式跑真机/模拟器**

```bash
cd /home/wh/workspace/hmi-android-apk && flutter run
```

- [ ] **Step 2: 逐项回归**

按顺序验证以下场景：

1. **首页显示 Launcher**：打开 APK，看到"选择应用"页面与 3 张卡（eBadge、Watch [预览]、仪表盘 [预览]）。未弹 BLE 权限请求。
2. **进入 eBadge 完整流程**：点 eBadge → 进入扫描页（标题"eBadge · 扫描设备"，默认过滤 "eBadge"）→ 扫到并连接一个 eBadge 设备 → 进入 DevicePage → 从 Drawer 进入 image/video/danmaku 等子页均正常。
3. **eBadge 断连回退**：手动断开设备 → 回到 eBadge 扫描页（不是 Launcher），SnackBar 显示"设备已断开"。
4. **返回 Launcher**：连按返回键 → 从 eBadge 扫描页返回到 Launcher。
5. **进入 Watch 骨架**：点 Watch 卡 → 进入扫描页（标题"Watch · 扫描设备"，默认过滤 "Watch"）。清空过滤器能看到所有 BLE 设备。
6. **进入 Dashboard 骨架**：同上，过滤为 "Dashboard"。
7. **Launcher overflow 菜单**：点右上角三点 → 设置 / 缓存管理 / 芯片配置 三个入口都能正确 push 到对应页面。
8. **深层页面返回**：在 eBadge → image 页面按返回 → 回到 DevicePage → 再按返回 → 回到 Launcher。

- [ ] **Step 3: 记录结果**

创建 `docs/superpowers/reports/2026-07-22-app-launcher-manual-test.md`（若 reports 目录不存在则一并创建）：

```markdown
# App Launcher 手动回归测试报告

**日期**: 2026-07-22
**设备**: <型号>
**Flutter/Dart**: 3.35.7 / 3.9.2

## 结果

| # | 场景 | 结果 |
|---|---|---|
| 1 | 首页显示 Launcher | ✅ / ❌ |
| 2 | eBadge 完整流程 | ✅ / ❌ |
| 3 | eBadge 断连回退 | ✅ / ❌ |
| 4 | 返回 Launcher | ✅ / ❌ |
| 5 | Watch 骨架扫描页 | ✅ / ❌ |
| 6 | Dashboard 骨架扫描页 | ✅ / ❌ |
| 7 | Launcher overflow 菜单 | ✅ / ❌ |
| 8 | 深层页面返回栈 | ✅ / ❌ |

## 备注 / 已知问题

<填写>
```

- [ ] **Step 4: 提交**

```bash
git add docs/superpowers/reports/2026-07-22-app-launcher-manual-test.md
git commit -m "test: App Launcher 手动回归测试报告"
```

---

## Self-Review

**1. Spec 覆盖**：
- ✅ §1 目标与范围 → Task 5, 7, 8 共同实现"首屏改为 Launcher"
- ✅ §2.1-2.2 结构与目录 → Task 2/5/6/7/8 全部落地
- ✅ §2.3 应用元数据 → Task 2 kAppCatalog + AppEntry
- ✅ §3.1 AppLauncherPage → Task 7
- ✅ §3.2 EBadgeAppRoot → Task 5
- ✅ §3.3 Watch/Dashboard Root → Task 8 + Task 4 (占位页)
- ✅ §3.4 AppDrawer 调整（阶段一：Launcher 内联 overflow 菜单）→ Task 7 Step 3；阶段二延后（spec 明确不做）
- ✅ §3.5 ScanPage 参数化 → Task 1
- ✅ §3.6 currentAppProvider → Task 3 + Task 7 `_launch` 里设值
- ✅ §4.1-4.4 生命周期 → Task 5/7/8 断连 popUntil 逻辑
- ✅ §5 错误处理 → Task 5/8 断连回退；BLE 权限沿用 ScanPage 现有 permission_handler 逻辑
- ✅ §6 测试 → Task 2/7 单元 + widget 测试；Task 9 手动回归
- ✅ §7 迁移与兼容 → 现有路由未改；Provider 语义未改
- ✅ §8 风险缓解 → route name 匹配（Task 5/8）、预览角标（Task 6）、Drawer 拆分分阶段（Task 7 只做阶段一）

**2. 占位符扫描**：无 TBD/TODO；每个 code step 都有完整代码；测试步骤都给出具体断言。

**3. 类型一致性**：
- `AppId` 三个值 `ebadge`/`watch`/`dashboard` — Task 2/3/7/8 一致
- `AppEntry` 字段名 `id`/`title`/`subtitle`/`icon`/`accent`/`deviceFilter`/`implemented` — Task 2/6/7 一致
- Route names `/ebadge-root` / `/watch-root` / `/dashboard-root` — Task 2/5/7/8 一致
- `ScanPage` 构造参数 `defaultDeviceFilter` / `appTitle` — Task 1 定义、Task 5/7/8 使用一致
- `currentAppProvider` — Task 3 定义、Task 7 使用一致

**已知留白**：
- Task 4 里 `disconnect()` 方法名假设；Step 1 已给出 grep 兜底验证。
- Task 9 是手动回归，不是自动化 integration test（项目目前无 integration_test）。
