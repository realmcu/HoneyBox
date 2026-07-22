# 应用启动器（App Launcher）设计

- **日期**：2026-07-22
- **分支**：master
- **状态**：设计已确认，待实现
- **背景 spec**：本项目当前 APK 打开即进入 BLE 扫描页（`ScanPage`）。产品希望在 APK 打开后先展示一个"应用选择"入口，让用户先选择进入哪个应用（eBadge、Watch、仪表盘、…），再进入该应用自己的扫描/连接/功能流程。

---

## 1. 目标与范围

### 目标
把 APK 首屏从"直接进入 BLE 扫描"改为"应用选择器（Launcher）"。用户流程：

```
打开 APK
   ↓
应用启动器（新首页，卡片列表）
   ↓ 点击某张卡片
选定应用的 Root（连接状态门）
   ↓ 未连接
该应用的扫描页（按设备类型过滤 BLE）
   ↓ 连接成功
该应用的功能页
```

### 在范围
- 新增 `AppLauncherPage`（新的 `home:`），以卡片列表呈现所有应用
- 把现有 eBadge 完整流程降级为 Launcher 的一个入口，代码几乎不动
- 新增 Watch、仪表盘（Dashboard）应用的最小骨架：应用根 + 基础扫描页（设备类型过滤后的空 UI）
- 首页作为返回根：`popUntil((r) => r.isFirst)` 与断连回退，都回到 Launcher
- 每个应用独立的 BLE 扫描过滤（按设备名前缀）
- 每个应用离开时清理自己的连接状态，避免"进入 Watch 却还连着 eBadge"

### 不在范围（另开 spec）
- Watch 与仪表盘的完整功能实现
- 应用的动态加载/插件化
- Launcher 的个性化（拖拽排序、置顶、隐藏、皮肤）
- 多设备并发连接（当前仍是单连接）

---

## 2. 架构

### 2.1 结构总览

```
main → MaterialApp
        ├── home: AppLauncherPage          ← 新根
        │
        ├── 卡片: eBadge      → EBadgeAppRoot     (= 原 AppRoot)
        ├── 卡片: Watch       → WatchAppRoot      (新)
        ├── 卡片: Dashboard   → DashboardAppRoot  (新)
        └── 卡片: …           → 未来扩展
```

- **Launcher 层无 BLE 状态**：纯选择器，不订阅 `connectedDeviceProvider`。
- **每个应用一个 `<App>AppRoot`**：内部是原 `AppRoot` 那种"连接状态门"——未连接 → 显示自家扫描页，已连接 → 显示自家功能主页。
- **共享底层**：`BleManager`、`BleProvider`、设置、缓存管理等继续全局共享；应用层只是在其上加**设备类型过滤**与**功能路由分组**。

### 2.2 目录结构（新增文件加粗）

```
lib/
├── app.dart                          ← 修改：home 改为 AppLauncherPage；路由分组
├── main.dart
├── pages/
│   ├── launcher/                     ← 新增
│   │   ├── **app_launcher_page.dart**
│   │   ├── **widgets/**
│   │   │   └── **app_card.dart**
│   │   └── **app_catalog.dart**      ← 应用元数据静态清单
│   ├── ebadge/                       ← 新增（薄壳）
│   │   └── **ebadge_app_root.dart**  ← 从原 AppRoot 迁入
│   ├── watch/                        ← 新增
│   │   ├── **watch_app_root.dart**
│   │   └── **watch_scan_page.dart**
│   ├── dashboard/                    ← 新增
│   │   ├── **dashboard_app_root.dart**
│   │   └── **dashboard_scan_page.dart**
│   ├── scan/                         ← 现有：ScanPage 参数化，接收设备过滤前缀
│   ├── device/ image/ danmaku/ video/ slideshow/ stream/ wifi/
│   ├── chip_config/ ota/ settings/ shared/
│   └── ...
├── providers/
│   └── ble_provider.dart             ← 修改：新增 currentAppProvider（当前所在应用）
└── services/
```

### 2.3 应用元数据

不引入注册表抽象（YAGNI），但用一个**静态数据清单**集中管理应用信息，让 Launcher 渲染卡片列表时读它，也让"新增一个应用"改动收敛在一个地方。

```dart
// lib/pages/launcher/app_catalog.dart
enum AppId { ebadge, watch, dashboard }

class AppEntry {
  final AppId id;
  final String title;         // "eBadge"
  final String subtitle;      // "电子胸牌调试与内容管理"
  final IconData icon;        // 图标（先用 Material 内置，后续可换成 svg/png）
  final Color accent;         // 卡片强调色
  final String deviceFilter;  // BLE 扫描名前缀过滤，如 "eBadge" / "Watch" / "Dashboard"
  final bool implemented;     // 是否已完全实现（false = 仅骨架）
}

const kAppCatalog = <AppEntry>[
  AppEntry(id: AppId.ebadge,    title: 'eBadge',    ..., deviceFilter: 'eBadge',    implemented: true),
  AppEntry(id: AppId.watch,     title: 'Watch',     ..., deviceFilter: 'Watch',     implemented: false),
  AppEntry(id: AppId.dashboard, title: '仪表盘',    ..., deviceFilter: 'Dashboard', implemented: false),
];
```

未来加应用：`AppId` 加一项，`kAppCatalog` 加一行，Launcher 自动多一张卡；再加一个 `<App>AppRoot`。

---

## 3. 关键组件

### 3.1 `AppLauncherPage`（新首页）

**职责**：以卡片列表展示 `kAppCatalog`，点击后 `Navigator.push` 到对应的 `<App>AppRoot`。

**UI**：
- Scaffold + AppBar：标题"选择应用"，右上角 overflow 菜单（设置/关于/缓存管理，复用现有 `AppDrawer` 的部分入口）
- 主体：`ListView` 竖向卡片列表，每张卡 `AppCard`
- 布局符合"卡片列表"决定：图标 + 标题 + 副标题一句话
- 未实现应用（`implemented: false`）卡片右上角贴一个"预览"角标，但**可点击**——进入其骨架扫描页，符合"都需要基本的扫描页"

**行为**：
- 无 BLE 订阅、无扫描
- 点击卡片：`Navigator.push(MaterialPageRoute(builder: (_) => <App>AppRoot()))`，同时更新 `currentAppProvider` 以便下层扫描/断连逻辑读取

**示意**：
```
┌────────────────────────────────────┐
│  选择应用                       ⋮ │
├────────────────────────────────────┤
│  ┌──────────────────────────────┐ │
│  │ 🎫  eBadge                   │ │
│  │     电子胸牌调试与内容管理    │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ ⌚  Watch          [预览]     │ │
│  │     智能手表配对与调试        │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ 📊  仪表盘        [预览]     │ │
│  │     车载仪表盘调试            │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
```

### 3.2 `EBadgeAppRoot`（原 `AppRoot` 平移）

**几乎不变**：把 `lib/app.dart` 里那个 `AppRoot` 类整体移到 `lib/pages/ebadge/ebadge_app_root.dart`，改名 `EBadgeAppRoot`。所有既有语义保留：
- 未连接 → `ScanPage(deviceFilter: 'eBadge')`（`ScanPage` 参数化，见 3.5）
- 已连接 → `DevicePage`
- 断连监听 → `popUntil` 到 first route（现在的 first route 是 `AppLauncherPage`，符合"首页是根"）

### 3.3 `WatchAppRoot` / `DashboardAppRoot`（骨架）

结构与 `EBadgeAppRoot` 一致，但：
- **未连接** → 对应的 `WatchScanPage` / `DashboardScanPage`，本质是复用参数化后的 `ScanPage` + 不同的 `deviceFilter`
- **已连接** → 先临时用一个"功能开发中"的占位页（`Scaffold` + Text + 断开按钮），后续在独立 spec 中替换
- 断连监听同 EBadge：回到 Launcher

### 3.4 `AppDrawer` 调整（**分两阶段**）

现有 `AppDrawer` 里有若干与 eBadge 强绑定的入口（如 chip_config、OTA）以及通用入口（设置、缓存）。

**阶段一（本 spec 必做）**：在 Launcher AppBar 挂一个**独立的 overflow 菜单**（内联在 `AppLauncherPage` 里，不复用 Drawer），条目为通用入口（设置、缓存管理、关于）。现有 `AppDrawer` 保持不变，仍完整挂在 eBadge 应用内。用户在 Launcher 也能进设置。

**阶段二（可延后到独立 spec）**：拆分 `AppDrawer` → `EBadgeDrawer`（应用私有入口 chip_config/OTA）+ `CommonMenu`（通用条目）；Launcher 的 overflow 菜单改为复用 `CommonMenu`，消除重复。

分两阶段是为了控制这个 spec 的改动面：本次先让 Launcher 跑通，Drawer 内部拆分是后续维护性改进。

### 3.5 `ScanPage` 参数化

现有 `ScanPage` 内部硬编码了 `_kDefaultFilter = 'eBadge'`。改动：
```dart
class ScanPage extends ConsumerStatefulWidget {
  final String defaultDeviceFilter;
  final String appTitle;           // AppBar 标题："eBadge 设备" / "Watch 设备"
  const ScanPage({
    super.key,
    this.defaultDeviceFilter = 'eBadge',
    this.appTitle = 'eBadge',
  });
  ...
}
```
- 保留用户可清空过滤器看全部设备的能力（现有行为不变）
- 各应用的 Root 传入自己的过滤前缀
- Watch/Dashboard 的骨架扫描页直接 `return ScanPage(defaultDeviceFilter: 'Watch', appTitle: 'Watch');`，**零重复代码**

### 3.6 `currentAppProvider`（新 Riverpod state）

```dart
final currentAppProvider = StateProvider<AppId?>((_) => null);
```
- 进入某应用时设为对应的 `AppId`
- 回到 Launcher 时设为 `null`

**当前用途**（有限但值得存在）：
1. 断连回滚时读出当前 app 拼出 route name（见 4.3）
2. 便于在共享 widget（如设置页）里显示"当前所在应用"上下文
3. 单元测试断言导航状态

**不用于业务过滤**：设备类型过滤走 `ScanPage` 构造参数（见 3.5），因为 provider 全局 state 不该被 push/pop 的 UI 分支读来做业务判定——参数直传更内聚，符合 KISS。

---

## 4. 数据流与生命周期

### 4.1 打开 APK

```
main() → runApp(EbadgeApp)
       → MaterialApp(home: AppLauncherPage)
       → Launcher 渲染 3 张卡（读 kAppCatalog）
       → 无 BLE 扫描、无权限询问
```

### 4.2 选择 eBadge

```
点击 eBadge 卡
  → currentAppProvider = AppId.ebadge
  → Navigator.push(EBadgeAppRoot)
  → EBadgeAppRoot 监听 connectedDeviceProvider
    ├─ null → ScanPage(defaultDeviceFilter: 'eBadge')
    │        → 用户操作扫描、连接
    └─ !null → DevicePage → 用户从 Drawer 进入 image/video/…
```

### 4.3 断连回滚

**背景**：原实现里 `AppRoot` 是 first route，断连时 `popUntil((r) => r.isFirst)` 弹回到它 → 因未连接自动显示扫描页。改造后 first route 变成 `AppLauncherPage`，如果照原样弹到 first，用户就会被弹回 Launcher，脱离所在应用——不符合意图。

**做法**：Launcher push `<App>AppRoot` 时用 `MaterialPageRoute(settings: RouteSettings(name: '/<app>-root'), builder: …)`。断连回退按 route name 匹配：

```dart
Navigator.of(context).popUntil((r) => r.settings.name == '/${currentApp}-root');
```

流程：

```
BleManager 断连事件
  → connectedDeviceProvider 变 null
  → 当前 <App>AppRoot 的 ref.listen 触发：
      Navigator.of(context).popUntil((r) => r.settings.name == '/<app>-root')
      SnackBar('设备已断开')
  → 弹回到 <App>AppRoot（Launcher 之上第一个匹配 name 的路由）
  → <App>AppRoot 再次 build，走"未连接分支"→ 显示扫描页
```

### 4.4 用户主动返回 Launcher

- Android 系统返回键：一路 pop → 最终到 `<App>AppRoot` 再 pop → 回 Launcher
- 到 Launcher 时清理：`currentAppProvider = null`；若还有连接，调用 `bleNotifier.disconnect()`（避免"在 Launcher 但仍占着 BLE"）

用 `WillPopScope` / `PopScope` 在 `<App>AppRoot` 上拦截：pop 前 disconnect + reset transferProgress + 清 currentApp。

---

## 5. 错误处理

| 场景 | 处理 |
|---|---|
| 用户在 Launcher 反复点同一张卡 | Navigator 已在栈顶则忽略（用 `pushReplacement` 或前置检查） |
| 用户在应用内部按返回时正在传输 | 弹二次确认（复用现有的传输中断确认逻辑，如果有；否则新增一个 Dialog） |
| BLE 权限未授予 | 首次进入某个需要 BLE 的应用（eBadge/Watch/Dashboard）时才申请，Launcher 自己不申请 |
| 未实现应用的骨架扫描页扫到设备并连接 | 允许连接，但功能主页显示"该应用功能开发中"占位；用户能断开返回 |
| Launcher 加载时 `kAppCatalog` 为空 | 显示 empty state（不该发生，但代码保护） |

---

## 6. 测试

延续项目现有测试约定（Flutter 单元 + widget 测试），最小测试集：

### 6.1 Widget 测试
- `AppLauncherPage` 渲染 `kAppCatalog.length` 张卡
- 点击某张卡触发 `Navigator.push` 到对应 Root（用 `NavigatorObserver` mock 验证）
- 未实现的应用卡显示"预览"角标
- Launcher AppBar overflow 菜单条目正确

### 6.2 单元测试
- `currentAppProvider` 状态切换正确
- `AppEntry` 数据完整性（每个条目有非空 title/deviceFilter/icon）

### 6.3 集成测试（手动 + 后续补脚本）
- 打开 APK → 看到 Launcher（不进扫描）
- 选 eBadge → 走完扫描/连接/传输完整链路（回归测试原 eBadge 流程）
- 选 Watch → 看到过滤后的扫描页（假设有 Watch 设备则能连；无则空）
- 从任何页面按返回 → 最终回到 Launcher
- 连接后断开 → 回到该应用的扫描页（不是 Launcher）

---

## 7. 迁移与向后兼容

- 现有用户升级后：**首次打开会看到 Launcher 而不是扫描页**，是行为变更，需在下一次 release 说明写清。
- 现有命名路由（`/image` `/danmaku` 等）**不改**：它们本来就是从 `DevicePage` 里 push 的，属于 eBadge 应用内部路由，路径不变可继续工作。Watch/Dashboard 未来的路由用 `/watch/*` 命名空间，避免冲突。
- Provider 全部保留，`connectedDeviceProvider` 语义不变。

---

## 8. 风险

| 风险 | 缓解 |
|---|---|
| 断连回退 `popUntil` 语义变更引入回归 | 显式给 `<App>AppRoot` 打 route name，`popUntil` 按 name 匹配而不是 `isFirst` |
| 用户误以为"预览"卡是完成的应用，抱怨功能缺失 | 卡片角标 + 进入后主页占位提示都写清 |
| BLE 状态跨应用泄漏（例如从 eBadge 直接切到 Watch 而没断） | 在 `<App>AppRoot` 的 `PopScope`/`dispose` 阶段调 disconnect |
| `AppDrawer` 拆分改动面广 | 分两步：先只加 Launcher 保持 Drawer 原样；后一个 commit 再拆 Drawer |

---

## 9. 实现顺序（后续 plan 会展开）

1. 参数化 `ScanPage`（`defaultDeviceFilter` / `appTitle`）+ 回归 eBadge 走通
2. 新增 `app_catalog.dart` + `AppLauncherPage` + `AppCard` + Launcher AppBar 内联 overflow 菜单（阶段一，不动 Drawer）
3. 迁移 `AppRoot` → `EBadgeAppRoot`（新文件），修改 `app.dart` 让 `home: AppLauncherPage`；push 时打 route name `/ebadge-root`
4. 修断连 `popUntil` 语义：从 `isFirst` 改为按 route name 匹配
5. 新增 `WatchAppRoot` / `DashboardAppRoot`（复用 `ScanPage` 参数，route name `/watch-root`、`/dashboard-root`）+ 占位功能页
6. 手动回归 + 补 widget 测试
7. （可延后）Drawer 拆分（阶段二）：`AppDrawer` → `EBadgeDrawer` + `CommonMenu`；Launcher 复用 `CommonMenu`

---

## 10. 未来演进（不做但要记住）

- 当第 4 个真实应用（不含 eBadge 三个）落地时，考虑抽象 `AppDescriptor` 接口，把 `<App>AppRoot` + `deviceFilter` + Drawer 挂载统一
- 若应用数量超过 6-8 个，Launcher 改成网格 + 分类
- 若出现"同一 APK 内多设备并发连接"需求（例如同时连 eBadge 和 Watch），需重构 `BleManager` 支持多会话——现阶段先不做
