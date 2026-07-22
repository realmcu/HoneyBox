# App Launcher 手动回归测试报告

**日期**: 2026-07-22
**设备**: <填写型号>
**Flutter/Dart**: 3.35.7 / 3.9.2
**Build**: `flutter build apk --debug` — 由 Task 5 / Task 7 / Task 8 三次烟测确认通过

## 结果

| # | 场景 | 结果 | 备注 |
|---|---|---|---|
| 1 | 首页显示 Launcher（"选择应用"，3 张卡：eBadge、Watch [预览]、仪表盘 [预览]，未弹 BLE 权限） | ⬜ | |
| 2 | eBadge 完整流程（点卡 → 扫描页标题"eBadge · 扫描设备"，过滤 'eBadge' → 连接 → DevicePage → Drawer 子页 image/video/danmaku 均正常） | ⬜ | |
| 3 | eBadge 断连回退（手动断开 → 回到 eBadge 扫描页 [非 Launcher] + SnackBar "设备已断开"） | ⬜ | |
| 4 | 返回 Launcher（连按返回键 → 从 eBadge 扫描页返回到 Launcher） | ⬜ | |
| 5 | Watch 骨架扫描页（点卡 → "Watch · 扫描设备"，过滤 'Watch'；清空过滤可看到所有 BLE 设备） | ⬜ | |
| 6 | Dashboard 骨架扫描页（同上，过滤 'Dashboard'，标题"仪表盘 · 扫描设备"） | ⬜ | |
| 7 | Launcher overflow 菜单（右上角 → 设置 / 缓存管理 / 芯片配置 三项均能正确 push） | ⬜ | |
| 8 | 深层页面返回栈（eBadge → image → 返回 → DevicePage → 返回 → Launcher） | ⬜ | |

## 备注 / 已知问题

- 骨架应用（Watch / Dashboard）连接后走 `AppPlaceholderPage`（"功能开发中"页 + 断开按钮），非 `DevicePage`——符合设计。
- Task 7 的 code review 指出 `currentAppProvider` 侧写在自动化测试中无守护（MEDIUM finding）；本次回归可通过侧观察后续 spec 里读该 provider 的功能来间接验证。

## 结论

⬜ 全部通过，可以合并
⬜ 部分未通过，见备注
