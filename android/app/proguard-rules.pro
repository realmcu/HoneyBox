# Optional classes referenced by the bundled AMap SDK.
-dontwarn com.amap.ams.gnss.GnssSoftLocator
-dontwarn net.jafama.FastMath

# AMap SDKs use reflection and JNI internally.
-keep class com.amap.** { *; }
-keep interface com.amap.** { *; }

# Keep native method names and the Kotlin JNI bridge used by navi_jpeg.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
-keep class com.example.map1.navi.TurboJpegEncoder { *; }
