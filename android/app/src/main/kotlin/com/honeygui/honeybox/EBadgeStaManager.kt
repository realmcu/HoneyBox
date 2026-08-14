package com.honeygui.honeybox

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * 把手机作为 STA 连上 eBadge 设备的 SoftAP，用于协议 §5 的 Wi-Fi 数据面传图。
 *
 * 与 [HotspotManager] 的分工正好相反：那个是「手机开热点、设备来连」（WiFi 投屏
 * 走的路），本类是「设备开热点、手机去连」（eBadge 传图协议要求的方向，见协议
 * §1「SoftAP：设备开热点，手机连接设备」）。两者不能同时生效。
 *
 * ## 为什么要 bindProcessToNetwork
 *
 * 设备热点没有互联网（`NET_CAPABILITY_INTERNET` 缺失），Android 不会把它选为默认
 * 网络，于是 Dart 侧 `Socket.connect('192.168.4.1', 9000)` 会走蜂窝数据出去，必然
 * 连不上。要让普通 socket 落到这张网上，只有两条路：
 *
 * 1. 在原生侧用 `network.bindSocket()` 逐个绑 socket —— 那意味着 TCP 上传整段都得
 *    搬到 Kotlin 里，EBXF 组包也跟着搬，协议实现就散成两半了。
 * 2. `bindProcessToNetwork()` 把整个进程的 socket 默认网络切过去 —— Dart 侧
 *    `dart:io` 不用改一行，协议实现全留在 Dart。
 *
 * 这里选 2，代价是**绑定期间本进程所有网络请求都走设备热点**（检查更新之类会失
 * 败）。所以 [connect] 成功后必须尽快 [disconnect]；协议 §5.5 的全局超时是 180 s，
 * 调用方要把解绑放在 finally 里，别指望流程一定走到成功分支。
 *
 * BLE 控制面不受影响 —— GATT 不走 IP 栈，绑定与它无关，传图期间进度 Notify 照收。
 *
 * 注意这里刻意**不复用** mapfeature 的 `VehicleWifiManager`：那个类的设计前提是
 * 「绝不绑定进程」（车机导航要同时用蜂窝数据上网），和本场景的需求正好冲突；而且
 * `:app` 用它还要反向依赖那个模块。
 */
class EBadgeStaManager(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var connectivityManager: ConnectivityManager? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    @Volatile private var network: Network? = null

    /** 待回复的 connect 调用。回过一次就置空 —— Result 重复回调会抛。 */
    private var pending: MethodChannel.Result? = null

    /**
     * 会话代数。requestNetwork 的回调可能在 [disconnect] 之后才到（Android 不保证
     * unregister 立刻生效），用它把迟到的回调认出来丢掉，否则上一轮的 onAvailable
     * 会把下一轮的状态覆盖掉。
     */
    private var generation = 0L

    val isConnected: Boolean get() = network != null

    /**
     * 连接 [ssid]，成功后把进程默认网络绑到这张网上。
     *
     * [result] 在连上（或失败/超时）时回一次：成功回 true，失败回 error。
     * [timeoutMs] 交给 Android 自己计时 —— 它比应用侧 Handler 更清楚「用户在系统
     * 弹窗上迟迟不点」和「AP 根本不存在」的区别。
     */
    @Synchronized
    fun connect(
        ssid: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported",
                "连接指定 Wi-Fi 需要 Android 10 (API 29) 及以上",
                null,
            )
            return
        }
        // 新请求先把旧会话拆干净，否则两个 NetworkCallback 会互相覆盖 network 字段。
        disconnectLocked()

        val app = context.applicationContext
        val wifi = app.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (!wifi.isWifiEnabled) {
            result.error("wifi_off", "Wi-Fi 未开启，请开启后重试", null)
            return
        }

        val specifier = try {
            WifiNetworkSpecifier.Builder().apply {
                setSsid(ssid)
                // 协议 §4.7 允许 Open（TLV_AP_SECURITY=0，密码 length=0）。
                // setWpa2Passphrase("") 会被 Android 判为非法参数，所以空密码时
                // 干脆不设，让它按开放网络处理。
                if (password.isNotEmpty()) setWpa2Passphrase(password)
            }.build()
        } catch (_: IllegalArgumentException) {
            result.error("bad_credentials", "SSID 或密码不被 Android 接受", null)
            return
        }

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            // 设备热点不通外网。不摘掉这个 capability，请求永远不会被满足。
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val manager = app.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        connectivityManager = manager
        pending = result

        val myGeneration = ++generation
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(available: Network) {
                synchronized(this@EBadgeStaManager) {
                    if (generation != myGeneration) return
                    network = available
                    // 绑定失败不算致命:调用方仍可能通过默认路由碰巧连通,
                    // 但绝大多数机型上会失败,所以要如实回报。
                    val bound = try {
                        manager.bindProcessToNetwork(available)
                    } catch (_: RuntimeException) {
                        false
                    }
                    finish(myGeneration) { it.success(bound) }
                }
            }

            override fun onUnavailable() {
                synchronized(this@EBadgeStaManager) {
                    if (generation != myGeneration) return
                    finish(myGeneration) {
                        it.error(
                            "unavailable",
                            "未能连上 $ssid：设备热点未开启、超时，或用户取消了系统确认弹窗",
                            null,
                        )
                    }
                }
            }

            override fun onLost(lost: Network) {
                synchronized(this@EBadgeStaManager) {
                    if (generation != myGeneration || network != lost) return
                    network = null
                    // 连上之后才掉的网:此时 connect 早已回过,只清状态不回 Result。
                    finish(myGeneration) {
                        it.error("lost", "与 $ssid 的连接已断开", null)
                    }
                }
            }
        }
        callback = cb

        try {
            // 系统会弹「是否允许连接到该网络」。requestNetwork 必须在整个会话期间
            // 保持注册 —— 一 unregister，Android 就会把这张网收走。
            manager.requestNetwork(request, cb, timeoutMs)
        } catch (e: SecurityException) {
            callback = null
            finish(myGeneration) {
                it.error("permission", "缺少附近设备/定位权限：${e.message}", null)
            }
        } catch (e: RuntimeException) {
            callback = null
            finish(myGeneration) {
                it.error("request_failed", "无法发起 Wi-Fi 连接请求：${e.message}", null)
            }
        }
    }

    /**
     * 回复并清空 [pending]。Result 必须在主线程调用，而 NetworkCallback 跑在
     * ConnectivityManager 的线程上，所以统一 post 过去。
     */
    private fun finish(myGeneration: Long, action: (MethodChannel.Result) -> Unit) {
        val r = pending ?: return
        pending = null
        mainHandler.post {
            synchronized(this) {
                // post 排队期间可能已经开了新会话,那这条回复就过期了。
                if (generation != myGeneration) return@post
            }
            action(r)
        }
    }

    /** 解绑进程网络并释放请求。幂等 —— 调用方可以在 finally 里无脑调。 */
    @Synchronized
    fun disconnect() = disconnectLocked()

    private fun disconnectLocked() {
        generation++
        network = null

        val manager = connectivityManager
        // 先解绑再 unregister:反过来的话,网络已被系统收走,绑定会残留成一条
        // 指向死网络的默认路由,后续所有 socket 都连不出去。
        if (manager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                manager.bindProcessToNetwork(null)
            } catch (_: RuntimeException) {
            }
        }
        val old = callback
        callback = null
        if (old != null && manager != null) {
            try {
                manager.unregisterNetworkCallback(old)
            } catch (_: RuntimeException) {
                // Android 可能已经自己回收了。
            }
        }
        connectivityManager = null

        // 还没回过的 connect 要给个交代,否则 Dart 侧的 await 永远悬着。
        val r = pending
        pending = null
        if (r != null) {
            mainHandler.post { r.error("cancelled", "Wi-Fi 连接已取消", null) }
        }
    }
}
