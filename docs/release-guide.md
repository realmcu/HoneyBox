# 发布流程（Release Guide）

本文档说明 `honeybox` 发布新版本的完整流程。应用内「检查更新」依赖 GitHub 上的
**Release + tag + `.apk` 资产**，缺一不可，因此请严格按步骤操作。

正常发布只需**改版本号 → 打 tag → 推送**：推送 `vX.Y.Z` tag 后，GitHub Actions
（`.github/workflows/flutter-ci.yml`）会自动构建 Release APK 并创建 GitHub Release，
无需手动上传。手动建 Release 仅作 CI 不可用时的兜底。

> 以发布 `0.8.4` 为例，将命令中的版本号替换为实际版本即可。

## 前置条件

- 已安装 Flutter，`flutter doctor` 通过（仅本地构建/验证时需要；CI 会自行安装）。
- 仓库 remote 为 GitHub `realmcu/HoneyBox`（凭证已配置，可正常 `git push`）。
- CI 自动发布无需任何令牌：`flutter-ci.yml` 的 release job 使用 GitHub Actions
  内置的 `GITHUB_TOKEN`（`permissions: contents: write`）创建 Release。

## 1. 修改版本号（两处，务必一致）

| 文件 | 字段 | 说明 |
| --- | --- | --- |
| `pubspec.yaml` | `version: X.Y.Z+N` | `N` 为 versionCode，每次发布 **递增** |
| `lib/app_info.dart` | `static String version = 'X.Y.Z';` | 仅作 pre-init 兜底，运行时由 package_info_plus 覆盖 |

两处的 `X.Y.Z` 必须完全一致，否则界面显示与更新判断会错乱。

## 2. 提交、打 tag、推送

```powershell
$ver = "0.8.4"
git add -A
git commit -m "chore: 版本号升至 $ver"
git tag -a "v$ver" -m "v$ver"
git push origin master "v$ver"
```

tag 命名固定为 `vX.Y.Z`（带 `v` 前缀），客户端会去掉 `v` 再比较版本。

## 3. 等待 CI 自动发布

推送 `vX.Y.Z` tag 后，`.github/workflows/flutter-ci.yml` 会自动：

1. `analyze` / `lint`：静态检查、测试、格式与 CI 策略检查。
2. `build-android`：`flutter build apk --release`，产物重命名为 **`HoneyBox.apk`**。
3. `build-windows`：构建 Windows x64。
4. `release`：仅在 `refs/tags/v*` 时触发，下载上述产物并用
   `softprops/action-gh-release` 创建名为 `HoneyBox vX.Y.Z` 的 Release，
   附带 `HoneyBox.apk` 等资产（`generate_release_notes: true` 自动汇总 commit）。

进度查看：<https://github.com/realmcu/HoneyBox/actions>。全部绿灯后，Release 会
出现在 <https://github.com/realmcu/HoneyBox/releases>。

> ⚠️ 资产名 **必须**为 `HoneyBox.apk`（客户端按小写 `honeybox.apk` 精确匹配）。CI
> 已按此命名；若手动上传，务必保持一致，否则客户端找不到 APK、不会提示更新。

## 4.（兜底）手动创建 GitHub Release

仅当 CI 不可用时使用。先本地构建：

```powershell
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
# Release 使用 debug 签名（android/app/build.gradle 中 signingConfig = signingConfigs.debug），可直接安装
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" `
          "build\app\outputs\flutter-apk\HoneyBox.apk"
```

### 方式 A：`gh` CLI（推荐）

```powershell
$ver = "0.8.4"
gh release create "v$ver" `
  "build\app\outputs\flutter-apk\HoneyBox.apk" `
  --repo realmcu/HoneyBox `
  --title "HoneyBox v$ver" `
  --notes "本次更新内容……"
```

### 方式 B：网页手动

打开 <https://github.com/realmcu/HoneyBox/releases/new>，基于已推送的 `vX.Y.Z`
tag 创建 Release，并在附件中上传 `HoneyBox.apk`。

## 5. 验证「检查更新」

- 客户端逻辑见 `lib/services/update_service.dart`：读取 `releases/latest` 的 `tag_name`
  （去掉 `v` 前缀）与名为 `honeybox.apk` 的资产下载链接。
- 验证（`gh` CLI）：

```powershell
gh release view --repo realmcu/HoneyBox --json tagName,assets `
  --jq '{tag: .tagName, apk: [.assets[].name]}'
```

  返回的 `tag` 应为最新版本，`apk` 列表中应包含 `HoneyBox.apk`。
- ⚠️ 只打 tag、不上传 APK（或资产名不对），老版本 **不会** 提示更新。

## 6. SHA-256 强校验

客户端已兼容强校验：若 Release notes（body）中声明了 SHA-256，下载与「复用本地已下载包」
时都会比对哈希；未声明则回退到「文件大小 + ZIP 魔数」弱校验。

CI 自动生成的 notes 不含 SHA-256，如需强校验请手动编辑 Release notes 追加。生成哈希：

```powershell
(Get-FileHash -Algorithm SHA256 "build\app\outputs\flutter-apk\HoneyBox.apk").Hash.ToLower()
```

在 Release notes 中单独一行写入（大小写、连字符不敏感，正则从 body 中提取 64 位 hex）：

```
SHA-256: <上一步得到的 64 位小写 hex>
```

相关实现：`update_service.dart` 的 `_parseSha256` / `cachedApk` / `downloadApk`
中的 `expectedSha256`。

## 附：已发布 tag

`v0.8.0`、`v0.8.2`、`v0.8.3`（无 `v0.8.1`）。
