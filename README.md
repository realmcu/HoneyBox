# map

## 临时发布测试 APK

用于把 App 发给其他测试机安装时，可直接打 Debug APK。

### 1. 打包

在项目根目录运行 PowerShell：

```powershell
$env:JAVA_HOME = "xxx\android-studio-quail1-patch2-windows\android-studio\jbr"; .\gradlew.bat assembleDebug
```

打包成功后，APK 位置：

```text
app\build\outputs\apk\debug\app-debug.apk
```



### 2. 发给测试机安装

把 `app-debug.apk` 通过微信、QQ、网盘或数据线发到测试手机。

测试手机需要允许安装未知来源应用：

```text
设置 → 安全/隐私 → 安装未知来源应用
```

然后点击 APK 安装。

### 3. 使用 adb 安装

测试机开启 USB 调试并连接电脑后，可运行：

```powershell
& "xxx\Android\Sdk\platform-tools\adb.exe" install -r app\build\outputs\apk\debug\app-debug.apk
```

如果提示签名冲突，先卸载旧版本：

```powershell
& "xxx\Android\Sdk\platform-tools\adb.exe" uninstall com.example.map1
```

再重新安装。

### 注意事项

- 当前包名：`com.example.map1`
- 最低系统版本：Android 7.0 / API 24
- 当前 APK 主要用于临时测试，不是正式上架包。
- 当前工程使用高德 SDK，Debug APK 的签名 SHA1 需要与高德控制台配置一致。
- 如果以后改用 Release 包，需要配置正式签名证书，并把 Release SHA1 更新到高德控制台。

## 正式 Release 打包（推荐，换电脑也能生效）

高德 Key 的校验是三要素绑定：`Key + 包名(com.example.map1) + 签名证书 SHA1`。
只要所有电脑都用**同一把固定的签名证书**，并把它的 SHA1 注册到高德控制台，
那么**任何电脑打出的 Release 包都能生效**，无需每台机器重复注册。

### 原理

- Debug 包默认使用每台电脑各自随机生成的 `~/.android/debug.keystore`，SHA1 各不相同，所以换电脑就失效。
- Release 包使用工程约定的固定证书 `release.keystore`，SHA1 全网统一，一次注册长期有效。

### 一、准备固定签名证书（整个团队只做一次）

1. 生成证书（在任意一台电脑执行，按提示设置并牢记密码）：

   ```powershell
   $env:JAVA_HOME = "<android-studio>\jbr"
   New-Item -ItemType Directory -Force -Path D:\keys | Out-Null
   & "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
     -keystore D:\keys\release.keystore `
     -alias map1 `
     -keyalg RSA -keysize 2048 -validity 36500 `
     -dname "CN=map1, OU=dev, O=yourcompany, L=Suzhou, ST=Jiangsu, C=CN"
   ```

2. 取该证书的 SHA1：

   ```powershell
   & "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore D:\keys\release.keystore -alias map1
   ```

3. 登录 [高德控制台](https://console.amap.com) → 找到本应用的 Key → 把上面的 **发布版 SHA1** 与包名 `com.example.map1` 填入并保存（可与 Debug SHA1 并存）。

4. **备份 `release.keystore` 与密码**：证书一旦丢失将无法为同一 App 发布更新版。请另存到安全位置，且**切勿提交进 git**（`.gitignore` 已忽略 `*.keystore`）。

### 二、每台打包电脑的一次性配置

1. 把团队共享的 `release.keystore` 拷贝到本机（如 `D:\keys\release.keystore`）。
2. 在项目根目录 `local.properties`（此文件不进 git）末尾追加以下 4 行，按本机实际路径和真实密码填写：

   ```properties
   RELEASE_STORE_FILE=D:/keys/release.keystore
   RELEASE_STORE_PASSWORD=你的keystore密码
   RELEASE_KEY_ALIAS=map1
   RELEASE_KEY_PASSWORD=你的key密码
   ```

   > 路径用正斜杠 `/`。若生成证书时只设了一个密码，两个密码填相同值即可。
   > 工程的 `app/build.gradle.kts` 已配置为：仅当 `local.properties` 提供了上述签名信息时，Release 包才使用该证书签名。

### 三、打 Release 包

```powershell
$env:JAVA_HOME = "<android-studio>\jbr"
.\gradlew.bat assembleRelease
```

产物位置：

```text
app\build\outputs\apk\release\app-release.apk
```

### 四、验证签名（可选）

确认 APK 的 SHA1 与注册到高德的一致：

```powershell
$bt = Get-ChildItem "$env:USERPROFILE\AppData\Local\Android\Sdk\build-tools" -Directory | Sort-Object Name -Descending | Select-Object -First 1
& "$($bt.FullName)\apksigner.bat" verify --print-certs app\build\outputs\apk\release\app-release.apk
```

输出的 `SHA-1 digest` 应与高德控制台里填写的发布版 SHA1 一致。

### 五、安装到测试机

```powershell
& "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r app\build\outputs\apk\release\app-release.apk
```

如提示签名冲突，先卸载旧包再装：

```powershell
& "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe" uninstall com.example.map1
```

### 换电脑要点小结

- **只需**：拷贝 `release.keystore` + 在该机 `local.properties` 填好 4 行签名信息。
- **无需**：重新到高德注册（同一证书 SHA1 已全局生效）。
- 若地图黑屏 / 导航报鉴权失败：多为高德控制台 SHA1 未保存或尚未生效，核对 SHA1 后等待几分钟重试。
