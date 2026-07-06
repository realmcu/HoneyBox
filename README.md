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

完整路径：

```text
xxx\AndroidStudioProjects\map1\app\build\outputs\apk\debug\app-debug.apk
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
