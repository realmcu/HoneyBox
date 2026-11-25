# Optional classes referenced by the bundled AMap SDK.
-dontwarn com.amap.ams.gnss.GnssSoftLocator
-dontwarn net.jafama.FastMath

# crpblelib (Realtek BLE DFU SDK) 里引用了未随 AAR 提供的可选传输实现：
#   com.realsil.sdk.bbpro.**      BBPRO 的 SPP / USB 传输层
#   com.realsil.sdk.core.usb.**   USB GATT 通道
# 只走 BLE DFU 时这些分支永远不会执行，但 R8 会把「找不到类」当错误直接失败。
# 只放行该 SDK 自己的包，不影响本项目代码的裁剪。
-dontwarn com.realsil.sdk.**

# AMap SDKs use reflection and JNI internally。三个包缺一不可：
#   com.amap.**     对外 API 与地图/定位/搜索实现（jar 内 3038 个类）
#   com.autonavi.** 地图内核与导航核心（668 个类）。native 层用 JNI 反射
#                   查找这些类，被混淆后会抛
#                   ClassNotFoundException: com.autonavi.base.amap.mapcore.ClassTools
#                   以及 UnsatisfiedLinkError: AMapNaviLogger.getTreadId()
#   com.alibaba.**  阿里云语音合成（23 个类），setUseInnerVoice(true) 时
#                   由高德内部反射加载，对应 libnui.so 等三个 so
-keep class com.amap.** { *; }
-keep interface com.amap.** { *; }
-keep class com.autonavi.** { *; }
-keep interface com.autonavi.** { *; }
-keep class com.alibaba.** { *; }
-keep interface com.alibaba.** { *; }

# 上述包内的类由 native/反射调用，不能因“看起来没被引用”而被裁剪。
-keepclassmembers class com.amap.** { *; }
-keepclassmembers class com.autonavi.** { *; }
-keepclassmembers class com.alibaba.** { *; }

# Keep native method names and the Kotlin JNI bridge used by navi_jpeg.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
-keep class com.example.map1.navi.TurboJpegEncoder { *; }
