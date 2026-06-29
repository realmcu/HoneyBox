# eBadge APK 新电脑搭建指南

## 新电脑最小安装（不装 Android Studio）

总共 ~500MB，约 20 分钟。

### 1. JDK 17
- 下载：https://adoptium.net/temurin/releases/?version=17
- 安装后将 `JAVA_HOME` 添加为系统环境变量

### 2. Flutter SDK
- 下载：https://docs.flutter.dev/get-started/install/windows
- 解压到 `C:\flutter\flutter`
- 将 `C:\flutter\flutter\bin` 添加到系统环境变量 PATH

### 3. Android Command Line Tools
- 下载：https://developer.android.com/studio#command-line-tools-only
- 解压到 `C:\Android\cmdline-tools`
- 将 `C:\Android\cmdline-tools\latest\bin` 添加到 PATH
- 打开命令提示符，运行：
```batch
sdkmanager "platform-tools"
sdkmanager "platforms;android-34"
sdkmanager "build-tools;34.0.0"
```
- 然后设置 SDK 路径：
```batch
flutter config --android-sdk "C:\Android"
```

### 4. Git（可选）
- 下载：https://git-scm.com/download/win

---

## 验证安装

```batch
flutter doctor
```

全部显示绿色勾即可。

---

## 编译 APK

```batch
:: 1. 下载代码
git clone <仓库地址>
cd miniprogram/ebadge_app

:: 2. 安装依赖
flutter pub get

:: 3. 连接手机（USB 调试已开启）
adb devices

:: 4. 编译并安装到手机
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk

:: 或一步到位
flutter run
```
