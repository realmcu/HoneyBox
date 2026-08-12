# CI Release 签名与高德 Key 配置

推送 `v*` 标签后，GitHub Actions 会构建 Release APK 并发布到 GitHub Release
与 Gitee 镜像。由于 `android/local.properties` 与 keystore 都不入库，
CI 必须从 GitHub Secrets 还原这些凭据，否则 `build.gradle` 的校验任务会抛
`GradleException` 并中断构建。

## 为什么不能省

`android/app/build.gradle` 在 `applicationVariants.configureEach` 中注册了
`validate<Variant>AmapConfiguration` 任务，并让 `assemble<Variant>` 依赖它：

- release 构建缺少 `AMAP_RELEASE_KEY` → 直接失败
- release 构建缺少任一签名项（`RELEASE_STORE_FILE` / `RELEASE_STORE_PASSWORD` /
  `RELEASE_KEY_ALIAS` / `RELEASE_KEY_PASSWORD`）→ 直接失败
- `RELEASE_STORE_FILE` 指向的文件不存在 → 直接失败

这是刻意设计：release 绝不回退 debug 签名，避免发布出无法通过高德鉴权、
且用户装机后才暴露问题的包。

## 必须配置的 Secrets

在 GitHub 仓库 **Settings → Secrets and variables → Actions → New repository secret**
逐项添加：

| Secret 名称 | 内容 | 用途 |
| --- | --- | --- |
| `AMAP_RELEASE_KEY` | 高德控制台为 Release 签名申请的 Key | release 构建 |
| `AMAP_DEBUG_KEY` | 高德控制台为 Debug 签名申请的 Key | 分支推送时的 debug 构建 |
| `RELEASE_KEYSTORE_BASE64` | keystore 文件的 base64 单行文本 | 还原签名证书 |
| `RELEASE_STORE_PASSWORD` | keystore 密码 | 签名 |
| `RELEASE_KEY_ALIAS` | key alias | 签名 |
| `RELEASE_KEY_PASSWORD` | key 密码 | 签名 |
| `RELEASE_SIGNING_SHA1` | 可选。期望的签名 SHA-1，用于校验产物 | 防止签错证书 |

`GITEE_TOKEN` 已由既有发布流程使用，此处无需改动。

## 生成 `RELEASE_KEYSTORE_BASE64`

必须是**单行无换行**，否则 CI 解码会失败。

Git Bash / Linux / macOS：

```bash
base64 -w0 /path/to/honeybox-release.jks > keystore-base64.txt
```

PowerShell：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\secure\honeybox-release.jks")) |
  Set-Content -NoNewline keystore-base64.txt
```

把 `keystore-base64.txt` 的全部内容粘贴为 Secret 值。

**该文件等价于 keystore 明文，配置完成后立即删除。**

验证生成正确（两个哈希须一致）：

```bash
sha256sum /path/to/honeybox-release.jks
base64 -d keystore-base64.txt | sha256sum
```

## 获取 `RELEASE_SIGNING_SHA1`

```bash
keytool -list -v -keystore /path/to/honeybox-release.jks -alias <你的alias>
```

取输出中的 `SHA1:` 一行。这个值必须与高德开放平台控制台上
Release Key 绑定的 SHA1 完全一致。

## 高德 Key 与签名的绑定关系

高德 Android Key 按 **Key + 包名 + 签名 SHA1** 三元组校验，三者任一不符
就会鉴权失败（表现为地图白屏或导航无法启动）。因此：

- Debug 与 Release **必须使用各自签名对应的 Key**，不可混用
- 如果 CI 用的 keystore 与本地 release keystore 是同一个，
  则 `AMAP_RELEASE_KEY` 可直接复用本地那份，无需另外申请
- 如果将来更换 keystore，必须同步更新高德控制台的 SHA1 绑定，
  并更新 `RELEASE_SIGNING_SHA1`

包名固定为 `com.honeygui.honeybox`。

## CI 中的处理流程

`.github/workflows/flutter-ci.yml` 的 `build-android` job：

1. **Configure signing and AMap keys** — 判断是否为 release（`refs/tags/v*`
   或手动指定 `release_tag`）。release 时校验 5 项 Secret 齐全、把 keystore
   解码到 `$RUNNER_TEMP`、用 `keytool` 验证可读、写入 `android/local.properties`；
   非 release 时只写 `AMAP_DEBUG_KEY`。日志只打印键名，不打印值。
2. **Build Android APK** — debug 或 release。
3. **Verify release APK signature** — 用 `apksigner verify --print-certs`
   读取产物实际 SHA-1，与 `RELEASE_SIGNING_SHA1` 比对；未设置该 Secret 时
   仅告警并打印实际值，不阻断。
4. **Clean up signing material** — `if: always()`，删除 `local.properties`
   与解码出的 keystore。

## 安全须知

- GitHub Actions 会自动对日志中出现的 Secret 值打码，但仍应避免主动
  `echo` 或 `cat` 凭据
- `local.properties` 已被 `android/.gitignore` 忽略（`/local.properties`），
  `*.keystore` 与 `*.jks` 已被根 `.gitignore` 忽略
- Secret 仅在同仓库的 Actions 中可用；**来自 fork 的 PR 拿不到 Secret**，
  因此 fork PR 无法构建 release（这是预期行为）
- 更换密码或 keystore 后，须同时更新对应 Secret 与高德控制台绑定

## 首次配置后的验证方式

不必真的打正式标签。在 Actions 页面手动触发 workflow，
把 `release_tag` 填成一个已存在的旧标签（如 `v0.8.12`），
即可完整跑通 release 构建与签名校验流程。
