# 发布流程（Release Guide）

本文档说明 `ebadge_app` 发布新版本的完整流程。应用内「检查更新」依赖 Gitee 上的
**Release + tag + `.apk` 资产**，缺一不可，因此请严格按步骤操作。

> 以发布 `0.8.4` 为例，将命令中的版本号替换为实际版本即可。

## 前置条件

- 已安装 Flutter，`flutter doctor` 通过。
- 仓库 remote 为 Gitee `realmcu/hmi-android-apk`（https，凭证已缓存在 Windows 凭据管理器）。
- 已配置用户环境变量 `GITEE_TOKEN`（Gitee 个人访问令牌，用于 API 自动建 Release 上传 APK）。
  - 校验：PowerShell 执行 `$env:GITEE_TOKEN` 应能打印出令牌。
  - ⚠️ 令牌是敏感凭证，切勿写入代码、提交记录或明文日志；如泄露请在 Gitee 设置中重置。

## 1. 修改版本号（两处，务必一致）

| 文件 | 字段 | 说明 |
| --- | --- | --- |
| `pubspec.yaml` | `version: X.Y.Z+N` | `N` 为 versionCode，每次发布 **递增** |
| `lib/app_info.dart` | `static String version = 'X.Y.Z';` | 仅作 pre-init 兜底，运行时由 package_info_plus 覆盖 |

两处的 `X.Y.Z` 必须完全一致，否则界面显示与更新判断会错乱。

## 2. 构建 Release APK

```powershell
flutter build apk --release
```

- 产物：`build/app/outputs/flutter-apk/app-release.apk`。
- Release 使用 **debug 签名**（`android/app/build.gradle` 中 `signingConfig = signingConfigs.debug`），可直接安装。
- 建议另存为带版本号的文件名，便于上传与归档：

```powershell
$ver = "0.8.4"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" `
          "build\app\outputs\flutter-apk\ebadge-$ver.apk"
```

## 3. 提交、打 tag、推送

```powershell
$ver = "0.8.4"
git add -A
git commit -m "chore: 版本号升至 $ver"
git tag -a "v$ver" -m "v$ver"
git push origin master "v$ver"
```

tag 命名固定为 `vX.Y.Z`（带 `v` 前缀），客户端会去掉 `v` 再比较版本。

## 4. 创建 Gitee Release 并上传 APK

### 方式 A：API 自动（推荐）

```powershell
$ver   = "0.8.4"
$token = $env:GITEE_TOKEN

# 4.1 创建 Release，拿到 release id
$rel = Invoke-RestMethod -Method Post `
  -Uri "https://gitee.com/api/v5/repos/realmcu/hmi-android-apk/releases" `
  -Body @{
    access_token     = $token
    tag_name         = "v$ver"
    name             = "v$ver"
    body             = "本次更新内容……"
    target_commitish = "master"
  }
$rel.id

# 4.2 上传 APK 资产（multipart，字段名必须是 file）
Invoke-RestMethod -Method Post `
  -Uri "https://gitee.com/api/v5/repos/realmcu/hmi-android-apk/releases/$($rel.id)/attach_files?access_token=$token" `
  -Form @{ file = Get-Item "build\app\outputs\flutter-apk\ebadge-$ver.apk" }
```

### 方式 B：网页手动（备用）

打开 <https://gitee.com/realmcu/hmi-android-apk/releases/new>，基于已推送的 `vX.Y.Z`
tag 创建 Release，并在附件中上传 `ebadge-X.Y.Z.apk`。

## 5. 验证「检查更新」

- 客户端逻辑见 `lib/services/update_service.dart`：读取 `releases/latest` 的 `tag_name`
  （去掉 `v` 前缀）与第一个 `.apk` 资产的下载链接。
- 验证：

```powershell
Invoke-RestMethod "https://gitee.com/api/v5/repos/realmcu/hmi-android-apk/releases/latest" |
  Select-Object tag_name, @{n='apk';e={$_.assets.name}}
```

  返回的 `tag_name` 应为最新版本，`apk` 中应包含刚上传的 `.apk`。
- ⚠️ 只打 tag、不上传 APK，老版本 **不会** 提示更新。

## 6. SHA-256 强校验

客户端已兼容强校验：若 Release notes（body）中声明了 SHA-256，下载与「复用本地已下载包」
时都会比对哈希；未声明则回退到「文件大小 + ZIP 魔数」弱校验。

生成哈希并写入 notes：

```powershell
(Get-FileHash -Algorithm SHA256 "build\app\outputs\flutter-apk\ebadge-$ver.apk").Hash.ToLower()
```

在 Release notes 中单独一行写入（大小写、连字符不敏感，正则从 body 中提取 64 位 hex）：

```
SHA-256: <上一步得到的 64 位小写 hex>
```

相关实现：`update_service.dart` 的 `_parseSha256` / `cachedApk` / `downloadApk`
中的 `expectedSha256`。

## 附：已发布 tag

`v0.8.0`、`v0.8.2`、`v0.8.3`（无 `v0.8.1`）。
