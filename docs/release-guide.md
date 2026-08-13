# 发布流程（Release Guide）

本文档说明 `honeybox` 发布新版本的完整流程。应用内「检查更新」由用户**自行选择更新
来源**（GitHub 或 Gitee），两个源都需要该处有 **Release + tag + `.apk` 资产**才能
被检测到并下载。

正常发布分两步：**改版本号 → 打 tag → 推送**，之后**手动把 APK 传到 Gitee**。
推送 `vX.Y.Z` tag 后，GitHub Actions（`.github/workflows/flutter-ci.yml`）会自动构建
Release APK、创建 **GitHub** Release 并附上 `HoneyBox.apk`，同时把代码与 tag 同步到
Gitee。

> ⚠️ **Gitee Release 的 APK 需要手动上传**，CI 不再自动传。原因：GitHub 托管 runner
> 到 Gitee 的上行实测仅 12–14 KB/s，百余 MB 的 APK 需要两三个小时且经常中断，曾导致
> release job 反复失败（v0.8.14 被 cancel、v0.8.15 上传中断）。因此该步骤已从 CI 移除。
> 不传的后果：App 里选「从 Gitee 更新」的用户**检测不到新版本**（选 GitHub 的不受影响）。

> 以发布 `0.8.16` 为例，将命令中的版本号替换为实际版本即可。

## 前置条件

- 已安装 Flutter，`flutter doctor` 通过（仅本地构建/验证时需要；CI 会自行安装）。
- 仓库 remote 为 GitHub `realmcu/HoneyBox`（凭证已配置，可正常 `git push`）。
- CI 自动发布无需额外配置 `GITHUB_TOKEN`：`flutter-ci.yml` 的 release job 使用
  GitHub Actions 内置的 `GITHUB_TOKEN`（`permissions: contents: write`）创建
  GitHub Release。
- 已在 **GitHub 仓库 Settings → Secrets and variables → Actions** 配置名为
  `GITEE_TOKEN` 的 secret（Gitee 个人访问令牌，需 push 代码权限），供 CI 把代码与
  tag 同步到 Gitee。⚠️ 令牌切勿写入代码/提交/日志。

  **关于 token 安全存储与日志脱敏：**

  - **加密存储**：secret 添加到 GitHub 仓库后以加密方式存储，网页上不再显示原文，
    只能覆盖或删除，无法查看。
  - **自动脱敏**：workflow 通过 `${{ secrets.GITEE_TOKEN }}` 引用。GitHub Actions
    对 secret 值有自动脱敏机制，凡出现在运行日志中的 token 原文一律被替换为 `***`，
    不会在日志里泄露。
  - **已规避常见泄露点**：本 CI 不使用 `set -x`；token 仅用于 `git push` 的远端 URL
    认证，不落日志。
  - **最小权限 + 短有效期**：建议给该 token 仅授予 push 代码所需的最小权限，并设置
    较短的有效期，以降低万一泄露时的影响范围。

## 1. 修改版本号（两处，务必一致）

| 文件 | 字段 | 说明 |
| --- | --- | --- |
| `pubspec.yaml` | `version: X.Y.Z+N` | `N` 为 versionCode，每次发布 **递增** |
| `lib/app_info.dart` | `static String version = 'X.Y.Z';` | 仅作 pre-init 兜底，运行时由 package_info_plus 覆盖 |

两处的 `X.Y.Z` 必须完全一致，否则界面显示与更新判断会错乱。

## 2. 提交、打 tag、推送

```powershell
$ver = "0.8.16"
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
4. `release`：仅在 `refs/tags/v*` 时触发：
   - 创建 GitHub Release，附 `HoneyBox.apk`（App 选「从 GitHub 更新」时用的就是它）；
   - 用 `GITEE_TOKEN` 把 tag 与 master push 到 Gitee `realmcu/HoneyBox`（两边代码同步）；
   - **不再**创建 Gitee Release、不再上传 APK 到 Gitee —— 见下一节手动步骤。

进度查看：<https://github.com/realmcu/HoneyBox/actions>。全部绿灯后，GitHub Release 会
出现在 <https://github.com/realmcu/HoneyBox/releases>。

> ⚠️ 资产名 **必须**为 `HoneyBox.apk`（客户端匹配第一个以 `.apk` 结尾的资产名，
> 不区分大小写）。CI 已按此命名；手动上传到 Gitee 时务必保持一致，否则客户端找不到
> APK、不会提示更新。
>
> 注：GitHub Release 会附带 Windows 构建的一批散文件（`.dll` / `.dat` 等），其中只有
> `HoneyBox.apk` 一个 `.apk`，客户端能正确选中它。

## 4. 手动上传 APK 到 Gitee（常规必需步骤）

CI 不再自动传，需手动完成，否则选「从 Gitee 更新」的用户检测不到新版。

### 4.1 取得 APK

从 CI 产物或 GitHub Release 下载，避免本地重新构建（保证与发布产物字节一致）：

```powershell
$ver = "0.8.16"
gh release download "v$ver" --repo realmcu/HoneyBox --pattern "HoneyBox.apk" --dir .
```

### 4.2 算出 SHA-256

```powershell
(Get-FileHash -Algorithm SHA256 ".\HoneyBox.apk").Hash.ToLower()
```

### 4.3 建 Gitee Release 并上传

打开 <https://gitee.com/realmcu/HoneyBox/releases/new>，基于已由 CI 推送的 `vX.Y.Z`
tag 创建 Release：

- **标题**：`HoneyBox vX.Y.Z`
- **附件**：上传 `HoneyBox.apk`（文件名必须一致）
- **Release notes**：单独一行写入上一步的哈希，客户端会据此做强校验

```
SHA-256: <64 位小写 hex>
```

### 4.4 确认

```powershell
Invoke-RestMethod "https://gitee.com/api/v5/repos/realmcu/HoneyBox/releases/latest" |
  Select-Object tag_name, @{n='apk';e={($_.assets | Where-Object { $_.name -like '*.apk' }).name}}
```

`tag_name` 应为新版本、`apk` 应为 `HoneyBox.apk`。

## 5. 验证「检查更新」

客户端逻辑见 `lib/services/update_service.dart`：点「检查更新」后先让用户选源
（`UpdateSource.github` / `UpdateSource.gitee`），再读该源 `releases/latest` 的
`tag_name`（去 `v` 前缀）与第一个 `.apk` 资产下载链接。两个源都要能查到才算发布完整。

```powershell
# GitHub 源（CI 自动发布，正常应立即可用）
Invoke-RestMethod "https://api.github.com/repos/realmcu/HoneyBox/releases/latest" |
  Select-Object tag_name, @{n='apk';e={($_.assets | Where-Object { $_.name -like '*.apk' }).name}}

# Gitee 源（需先完成第 4 节的手动上传）
Invoke-RestMethod "https://gitee.com/api/v5/repos/realmcu/HoneyBox/releases/latest" |
  Select-Object tag_name, @{n='apk';e={($_.assets | Where-Object { $_.name -like '*.apk' }).name}}
```

- ⚠️ 只打 tag、不上传 APK（或资产名不对），该源的用户 **不会** 收到更新提示。
- ⚠️ 发布前务必确认 `pubspec.yaml` 的版本号已 bump（见第 1 节）。若 APK 内部版本低于
  tag 版本，装了新版的用户会**反复收到更新提示**（v0.8.15 曾漏 bump，APK 内部仍报
  0.8.14，导致更新后仍提示有新版）。

## 6. SHA-256 强校验

客户端行为：若 Release notes（body）中声明了 SHA-256，下载与「复用本地已下载包」时都会
比对哈希；未声明则回退到「文件大小 + ZIP 魔数」弱校验。

两个源目前的实际情况：

| 源 | SHA-256 | 校验强度 |
| --- | --- | --- |
| GitHub | 无（CI 生成的 release notes 不含哈希） | 大小 + ZIP 魔数（弱校验） |
| Gitee | 手动上传时按第 4.2 节写入 | 哈希比对（强校验） |

在 Release notes 中单独一行写入（大小写、连字符不敏感，正则从 body 中提取 64 位 hex）：

```
SHA-256: <64 位小写 hex>
```

相关实现：`update_service.dart` 的 `_parseSha256` / `cachedApk` / `downloadApk`
中的 `expectedSha256`。

## 附：发布检查清单

1. `pubspec.yaml` 版本号 + build number 已递增，`lib/app_info.dart` 同步
2. 提交、打 `vX.Y.Z` tag、推送
3. CI 全绿，GitHub Release 已带 `HoneyBox.apk`
4. **手动**在 Gitee 建 Release、上传 `HoneyBox.apk`、notes 写入 `SHA-256`
5. 两个源的 `releases/latest` 都能查到新 tag 与 APK
