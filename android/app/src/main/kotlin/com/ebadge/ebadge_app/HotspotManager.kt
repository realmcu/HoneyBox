package com.ebadge.ebadge_app

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Local-only Wi-Fi hotspot probe.
 *
 * Uses [WifiManager.startLocalOnlyHotspot] (API 26+), the only hotspot API a
 * non-privileged app may call. The system generates the SSID / passphrase (they
 * can be read back but not chosen), the hotspot shares no internet, and only one
 * can be active at a time. Requires CHANGE_WIFI_STATE + a granted location
 * permission at runtime.
 */
class HotspotManager(private val context: Context) {

    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null

    /** True once the current hotspot was brought up on the forced 2.4GHz band. */
    private var forced2g = false

    /** Start (or return the already-running) local-only hotspot. */
    @SuppressLint("MissingPermission")
    fun start(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", "本地热点需要 Android 8.0 (API 26) 及以上", null)
            return
        }
        reservation?.let {
            result.success(infoMap(it))
            return
        }
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager
        try {
            // Prefer a 2.4GHz-only hotspot — the paired device's Wi-Fi is 2.4G,
            // and some phones would otherwise bring the AP up on 5GHz. This path
            // needs the SoftApConfiguration overload (API 30+, @SystemApi, gated
            // on NEARBY_WIFI_DEVICES); if it isn't available it falls through.
            if (startForced2g(wifi, result)) return
            forced2g = false
            wifi.startLocalOnlyHotspot(callbackFor(result), Handler(Looper.getMainLooper()))
        } catch (e: SecurityException) {
            result.error("permission", "缺少定位权限或系统限制：${e.message}", null)
        } catch (e: Exception) {
            result.error("error", "开启热点异常：${e.message}", null)
        }
    }

    /** The shared reservation callback that resolves the pending [result]. */
    private fun callbackFor(result: MethodChannel.Result):
        WifiManager.LocalOnlyHotspotCallback =
        object : WifiManager.LocalOnlyHotspotCallback() {
            override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                reservation = res
                result.success(infoMap(res))
            }

            override fun onFailed(reason: Int) {
                result.error("failed", "开启热点失败：${reasonText(reason)}", reason)
            }

            override fun onStopped() {
                reservation = null
            }
        }

    /**
     * Try to start a 2.4GHz-only local-only hotspot via the hidden
     * `startLocalOnlyHotspot(SoftApConfiguration, Executor, callback)` overload.
     *
     * `SoftApConfiguration.Builder.setBand()` and this overload are `@SystemApi`
     * (absent from the public SDK), so both are invoked reflectively. Returns
     * true only if the call was dispatched — any failure (old OS, missing
     * permission, blocked non-SDK access) returns false so the caller can fall
     * back to the default band-agnostic API.
     */
    @SuppressLint("MissingPermission")
    private fun startForced2g(wifi: WifiManager, result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val cfgClass = Class.forName("android.net.wifi.SoftApConfiguration")
            val builderClass =
                Class.forName("android.net.wifi.SoftApConfiguration\$Builder")
            val band2g = cfgClass.getField("BAND_2GHZ").getInt(null)

            val builder = builderClass.getConstructor().newInstance()
            builderClass.getMethod("setBand", Int::class.javaPrimitiveType)
                .invoke(builder, band2g)
            val config = builderClass.getMethod("build").invoke(builder)

            val method = wifi.javaClass.getMethod(
                "startLocalOnlyHotspot",
                cfgClass,
                Executor::class.java,
                WifiManager.LocalOnlyHotspotCallback::class.java,
            )
            val executor = Executor { r -> Handler(Looper.getMainLooper()).post(r) }
            method.invoke(wifi, config, executor, callbackFor(result))
            forced2g = true
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** Tear the hotspot down (frees Wi-Fi for normal use). */
    fun stop() {
        try {
            reservation?.close()
        } catch (_: Exception) {
        }
        reservation = null
        forced2g = false
    }

    val isActive: Boolean get() = reservation != null

    /** SSID / passphrase from the reservation (SoftApConfiguration on R+). */
    @SuppressLint("MissingPermission")
    private fun infoMap(res: WifiManager.LocalOnlyHotspotReservation): Map<String, Any?> {
        var ssid: String? = null
        var password: String? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val cfg = res.softApConfiguration
                @Suppress("DEPRECATION")
                ssid = cfg.ssid
                password = cfg.passphrase
            } else {
                @Suppress("DEPRECATION")
                val cfg = res.wifiConfiguration
                @Suppress("DEPRECATION")
                ssid = cfg?.SSID
                @Suppress("DEPRECATION")
                password = cfg?.preSharedKey
            }
        } catch (_: Exception) {
        }
        // Trim the quotes WifiConfiguration.SSID sometimes carries.
        ssid = ssid?.trim('"')
        return mapOf(
            "ssid" to ssid,
            "password" to password,
            "band" to if (forced2g) "2.4GHz" else null,
        )
    }

    private fun reasonText(reason: Int): String = when (reason) {
        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL ->
            "无可用信道"
        WifiManager.LocalOnlyHotspotCallback.ERROR_GENERIC ->
            "系统错误"
        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE ->
            "当前模式不兼容（可能已开启共享热点或 Wi-Fi）"
        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED ->
            "系统或管理策略禁止开启热点"
        else -> "未知原因($reason)"
    }
}
