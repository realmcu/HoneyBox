package com.example.map1.navi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Presentation
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.WindowManager
import android.widget.FrameLayout
import com.amap.api.navi.AMapNavi
import com.amap.api.navi.AMapNaviView
import com.amap.api.navi.AMapNaviViewOptions
import com.amap.api.navi.enums.NaviType
import com.amap.api.navi.enums.PathPlanningStrategy
import com.amap.api.navi.model.AMapCalcRouteResult
import com.amap.api.navi.model.NaviLatLng
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * 方案 X：把导航 [AMapNaviView] 渲染到一个 400×480 的私有虚拟屏（[VirtualDisplay]）上的
 * [Presentation] 中，再用 [ImageReader] 接虚拟屏输出，直接得到 400×480 的帧并通过 TCP 发出。
 *
 * 关键点：
 * - 内容渲染在虚拟屏（不是主屏），所以 App 切到后台、主屏黑屏/锁屏都不影响虚拟屏继续渲染。
 * - 走系统合成（VirtualDisplay→ImageReader），不走 glReadPixels，速度快且尺寸即 400×480。
 * - 不依赖 MediaProjection 屏幕采集，避免锁屏后系统把采集内容变成黑屏。
 * - 作为 connectedDevice 类型前台 Service 运行，保证与投屏设备的持续网络连接。
 *
 * 启动流程：Activity 确认悬浮窗权限后启动本 Service，Service 创建
 * DisplayManager VirtualDisplay → Presentation。
 */
class NaviCaptureService : Service() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val compressExecutor = Executors.newSingleThreadExecutor()
    private val nextSeq = AtomicInteger(0)

    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var presentation: NaviPresentation? = null
    private var jpgTcpSender: NaviJpgTcpSender? = null
    private var cpuWakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private var imageThread: HandlerThread? = null
    private var imageHandler: Handler? = null

    // 优化 2：复用去行填充的中间缓冲位图，避免每帧 createBitmap + GC。
    // 只在采集线程（imageThread）上访问，无需同步。
    private var reusablePadded: Bitmap? = null

    private var tcpFps = DEFAULT_TCP_FPS
    private var startLatLng = NaviLatLng(31.314, 120.728)
    private var endLatLng = NaviLatLng(31.325, 120.629)
    private var emulatorSpeed = 60
    private var virtualDisplayDpi = DEFAULT_VIRTUAL_DISPLAY_DPI
    // 投屏分辨率（可由启动方通过 EXTRA_WIDTH / EXTRA_HEIGHT 指定），默认 400×480。
    private var jpgWidth = DEFAULT_JPG_WIDTH
    private var jpgHeight = DEFAULT_JPG_HEIGHT
    private var renderWidth = DEFAULT_JPG_WIDTH
    private var renderHeight = DEFAULT_JPG_HEIGHT
    private var uiRenderScale = 1f

    private val captureRunnable = object : Runnable {
        override fun run() {
            NaviPerfStats.onCaptureLoopStart()
            captureAndSendJpgFrame()
            // 仅渲染（未配置 TCP）时也持续采集，用于本机预览与耗时统计。
            imageHandler?.postDelayed(this, 1_000L / tcpFps)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        // 停止指令：结束虚拟屏导航。
        if (intent.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundCompat()
        NaviFramePreview.setRunning(true)

        tcpFps = intent.getIntExtra(EXTRA_TCP_FPS, DEFAULT_TCP_FPS).coerceAtLeast(1)
        emulatorSpeed = intent.getIntExtra(EXTRA_SPEED, 60)
        startLatLng = NaviLatLng(
            intent.getDoubleExtra(EXTRA_START_LAT, startLatLng.latitude),
            intent.getDoubleExtra(EXTRA_START_LNG, startLatLng.longitude),
        )
        endLatLng = NaviLatLng(
            intent.getDoubleExtra(EXTRA_END_LAT, endLatLng.latitude),
            intent.getDoubleExtra(EXTRA_END_LNG, endLatLng.longitude),
        )
        virtualDisplayDpi = intent.getIntExtra(EXTRA_DPI, DEFAULT_VIRTUAL_DISPLAY_DPI)
            .coerceIn(160, 480)
        // 投屏分辨率：限制在合理范围并对齐到 2 的倍数，避免部分编码/传输环节对奇数宽高的兼容问题。
        jpgWidth = intent.getIntExtra(EXTRA_WIDTH, DEFAULT_JPG_WIDTH)
            .coerceIn(MIN_DIMENSION, MAX_DIMENSION) and 1.inv()
        jpgHeight = intent.getIntExtra(EXTRA_HEIGHT, DEFAULT_JPG_HEIGHT)
            .coerceIn(MIN_DIMENSION, MAX_DIMENSION) and 1.inv()
        val host = intent.getStringExtra(EXTRA_TCP_HOST).orEmpty().trim()
        val port = intent.getIntExtra(EXTRA_TCP_PORT, DEFAULT_TCP_PORT)

        startCapture(host, port)
        return START_NOT_STICKY
    }

    private fun startCapture(host: String, port: Int) {
        // 持有唤醒锁，防止导航投屏期间系统自动锁屏/熄屏导致虚拟屏黑帧。
        acquireWakeLocks()

        // 重置耗时统计，记录目标帧率。
        NaviPerfStats.reset(tcpFps)

        // 启动 TCP 发送线程（host 为空时不发送，仅渲染）
        if (host.isNotBlank()) {
            jpgTcpSender = NaviJpgTcpSender(
                host = host,
                port = port,
                networkProvider = { com.example.map1.VehicleWifiManager.selectedNetwork },
                onStatus = { msg -> Log.i(TAG, "tcp: $msg") },
                onFps = { fps, seq, bytesPerSecond ->
                    NaviPerfStats.onSendThroughput(bytesPerSecond)
                },
                onSendTiming = { seq, _, sendMs ->
                    NaviPerfStats.onSent(seq, sendMs, jpgTcpSender?.queueSize ?: 0)
                },
            ).also { it.start() }
        }

        // 始终让 ImageReader/VirtualDisplay 直接输出目标分辨率，这样可以一直走 ByteBuffer→TurboJPEG
        // 的直通编码路径。UI 缩放改由 Presentation 内部把 AMapNaviView 按更大/更小尺寸布局后再缩放显示。
        uiRenderScale = (virtualDisplayDpi.toFloat() / 160f).coerceIn(0.5f, 3f)
        renderWidth = jpgWidth
        renderHeight = jpgHeight
        Log.i(TAG, "uiRenderScale=$uiRenderScale, directOut=${jpgWidth}x$jpgHeight")

        // ImageReader 固定接收目标分辨率输出，无需 Java Bitmap 缩放。
        imageReader = ImageReader.newInstance(renderWidth, renderHeight, PixelFormat.RGBA_8888, 3)

        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        virtualDisplay = displayManager.createVirtualDisplay(
            VIRTUAL_DISPLAY_NAME,
            renderWidth,
            renderHeight,
            160,
            imageReader?.surface,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION or
                DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY,
            object : VirtualDisplay.Callback() {
                override fun onPaused() { Log.d(TAG, "virtualDisplay paused") }
                override fun onResumed() { Log.d(TAG, "virtualDisplay resumed") }
                override fun onStopped() { Log.d(TAG, "virtualDisplay stopped") }
            },
            mainHandler,
        )

        val display = virtualDisplay?.display
        if (display == null) {
            Log.e(TAG, "VirtualDisplay.display 为空")
            stopSelf()
            return
        }

        // 在主线程把导航 UI 显示到虚拟屏的 Presentation 中
        mainHandler.post { showNaviPresentation(display) }

        // 截图线程
        imageThread = HandlerThread("NaviCaptureImage").also { it.start() }
        imageHandler = Handler(imageThread!!.looper)
        imageHandler?.postDelayed(captureRunnable, 800)
    }

    private fun showNaviPresentation(display: Display) {
        // overlay 窗口需要悬浮窗权限（API 23+），未授权时 Presentation.show 会抛 BadTokenException。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.e(TAG, "未授予悬浮窗权限，无法显示虚拟屏导航")
            stopSelf()
            return
        }
        try {
            presentation = NaviPresentation(
                outerContext = this,
                display = display,
                uiRenderScale = uiRenderScale,
                jpgWidth = jpgWidth,
                jpgHeight = jpgHeight,
                onSetupNavi = ::setupNavi,
            ).also { it.show() }
        } catch (e: Exception) {
            Log.e(TAG, "显示 Presentation 失败", e)
            stopSelf()
        }
    }

    /** 在 Presentation 创建出 AMapNaviView 之后初始化导航并算路 */
    private fun setupNavi(naviView: AMapNaviView) {
        try {
            val aMapNavi = AMapNavi.getInstance(applicationContext)
            aMapNavi.addAMapNaviListener(object : NaviListenerAdapter() {
                override fun onInitNaviSuccess() {
                    val ok = aMapNavi.calculateDriveRoute(
                        arrayListOf(startLatLng),
                        arrayListOf(endLatLng),
                        null,
                        PathPlanningStrategy.DRIVING_DEFAULT,
                    )
                    if (!ok) Log.e(TAG, "发起算路失败")
                }

                override fun onCalculateRouteSuccess(result: AMapCalcRouteResult?) {
                    aMapNavi.setEmulatorNaviSpeed(emulatorSpeed)
                    aMapNavi.startNavi(NaviType.EMULATOR)
                }

                override fun onCalculateRouteFailure(result: AMapCalcRouteResult?) {
                    Log.e(TAG, "路线规划失败[${result?.errorCode}]：${result?.errorDescription}")
                }
            })
            aMapNavi.setUseInnerVoice(true, true)
        } catch (e: Exception) {
            Log.e(TAG, "初始化导航失败", e)
        }
    }

    private fun captureAndSendJpgFrame() {
        val acquireStartNs = System.nanoTime()
        val image = try {
            imageReader?.acquireLatestImage()
        } catch (e: Exception) {
            Log.e(TAG, "读取虚拟屏图像失败", e)
            null
        }
        val acquireMs = (System.nanoTime() - acquireStartNs) / 1_000_000L
        if (image == null) {
            // 没有新帧：说明虚拟屏渲染速度跟不上采集频率（采集端瓶颈或渲染端瓶颈）。
            NaviPerfStats.onEmptyAcquire(acquireMs)
            return
        }

        val directJpeg = encodeImageDirectIfPossible(image)
        if (directJpeg != null) {
            NaviPerfStats.onCaptured(acquireMs, 0)
            image.close()
            publishAndSend(directJpeg)
            return
        }

        val toBitmapStartNs = System.nanoTime()
        val bitmap = try {
            image.toBitmap()
        } finally {
            image.close()
        }
        val toBitmapMs = (System.nanoTime() - toBitmapStartNs) / 1_000_000L
        NaviPerfStats.onCaptured(acquireMs, toBitmapMs)
        compressAndSend(bitmap)
    }

    /**
     * 最快路径：renderScale=1 且 ImageReader 输出就是 400x480 RGBA 时，直接把平面 ByteBuffer
     * 交给 native TurboJPEG。这样跳过 copyPixelsFromBuffer()、Bitmap.copy() 和一次 Java Bitmap 分配。
     */
    private fun encodeImageDirectIfPossible(image: Image): ByteArray? {
        if (image.width != jpgWidth || image.height != jpgHeight) return null
        val plane = image.planes.firstOrNull() ?: return null
        if (plane.pixelStride != 4) return null
        val encodeStartNs = System.nanoTime()
        val jpeg = TurboJpegEncoder.encodeRgba(
            buffer = plane.buffer,
            width = image.width,
            height = image.height,
            rowStride = plane.rowStride,
            quality = JPG_QUALITY,
        ) ?: return null
        val encodeMs = (System.nanoTime() - encodeStartNs) / 1_000_000L
        NaviPerfStats.onEncoded(encodeMs)
        return jpeg
    }

    private fun compressAndSend(bitmap: Bitmap) {
        compressExecutor.execute {
            try {
                val encodeStartNs = System.nanoTime()
                val jpeg = TurboJpegEncoder.encode(bitmap, JPG_QUALITY)
                    ?: ByteArrayOutputStream().use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, JPG_QUALITY, stream)
                        stream.toByteArray()
                    }
                val encodeMs = (System.nanoTime() - encodeStartNs) / 1_000_000L
                NaviPerfStats.onEncoded(encodeMs)
                if (!bitmap.isRecycled) bitmap.recycle()
                publishAndSend(jpeg)
            } catch (e: Exception) {
                Log.e(TAG, "JPG 帧生成失败", e)
                if (!bitmap.isRecycled) bitmap.recycle()
            }
        }
    }

    private fun publishAndSend(jpeg: ByteArray) {
        val seq = nextSeq.getAndIncrement()
        NaviFramePreview.publish(seq, jpeg)
        jpgTcpSender?.enqueue(seq, jpeg)
    }

    private fun Image.toBitmap(): Bitmap {
        val plane = planes[0]
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val rowWidth = width + rowPadding / pixelStride

        // 优化 2：复用同尺寸的 padded 缓冲位图（尺寸/配置变化时才重建），
        // 每帧只做 copyPixelsFromBuffer，去掉一次 createBitmap 分配与 GC。
        val padded = reusablePadded?.takeIf {
            !it.isRecycled && it.width == rowWidth && it.height == height
        } ?: Bitmap.createBitmap(rowWidth, height, Bitmap.Config.ARGB_8888).also {
            reusablePadded?.recycle()
            reusablePadded = it
        }
        padded.copyPixelsFromBuffer(plane.buffer)

        // 下游会 recycle 返回的位图，而 padded 是复用缓冲，不能直接交出去。
        // 无行填充且尺寸已等于输出（renderScale=1.0）：直接拷贝一份同尺寸位图（无缩放）。
        if (rowWidth == width && width == jpgWidth && height == jpgHeight) {
            return padded.copy(Bitmap.Config.ARGB_8888, false)
        }

        // 去掉行填充 + 缩放到目标输出尺寸（产生新位图，不影响复用缓冲）。
        val cropped = if (rowWidth == width) padded else Bitmap.createBitmap(padded, 0, 0, width, height)
        if (cropped.width == jpgWidth && cropped.height == jpgHeight) {
            // cropped 可能就是 padded（复用缓冲），需拷贝后再交出。
            return if (cropped === padded) cropped.copy(Bitmap.Config.ARGB_8888, false) else cropped
        }
        return Bitmap.createScaledBitmap(cropped, jpgWidth, jpgHeight, true)
            .also { if (it !== cropped && cropped !== padded) cropped.recycle() }
    }

    private fun startForegroundCompat() {
        val channelId = "navi_capture"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                channelId,
                "导航投屏",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm.createNotificationChannel(channel)
        }
        // Notification.Builder(Context, channelId) 是 API 26+ 才有的构造方法，
        // 低版本（如 Android 7.0）必须用无 channel 的旧构造方法，否则 NoSuchMethodError。
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification: Notification = builder
            .setContentTitle("导航投屏运行中")
            .setContentText("正在将 ${jpgWidth}×$jpgHeight 导航画面发送到设备")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("WakelockTimeout")
    private fun acquireWakeLocks() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (cpuWakeLock?.isHeld != true) {
            cpuWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "map1:NaviCaptureCpuWakeLock",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        }

        // 只用 PARTIAL_WAKE_LOCK 时 CPU 不睡，但屏幕锁定后部分 ROM 会暂停 Presentation/GL，
        // ImageReader 读到黑帧。投屏运行期间额外保持屏幕亮起，结束服务时释放。
        if (screenWakeLock?.isHeld != true) {
            @Suppress("DEPRECATION")
            val flags = PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE
            screenWakeLock = pm.newWakeLock(flags, "map1:NaviCaptureScreenWakeLock").apply {
                setReferenceCounted(false)
                acquire()
            }
        }

        // 关键：PARTIAL_WAKE_LOCK 只保证 CPU 不睡，并不能阻止 Wi-Fi 芯片进入省电（PS）模式。
        // 部分厂商 ROM（如魅族 Flyme）在发送间隙让 Wi-Fi 休眠，导致 TCP 发送出现周期性数百 ms
        // 停顿，接收端（EVB）单帧 payload 读超时后断链，形成“网速下降→超时→重连”的死循环。
        // 申请 WIFI_MODE_FULL_HIGH_PERF 高性能 Wi-Fi 锁，禁止省电，保证投屏期间连续收发。
        if (wifiLock?.isHeld != true) {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wifi?.createWifiLock(mode, "map1:NaviCaptureWifiLock")?.apply {
                setReferenceCounted(false)
                acquire()
            }
            Log.i(TAG, "WifiLock acquired: mode=$mode held=${wifiLock?.isHeld}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        imageHandler?.removeCallbacks(captureRunnable)
        imageThread?.quitSafely()
        imageThread = null
        imageHandler = null
        reusablePadded?.let { if (!it.isRecycled) it.recycle() }
        reusablePadded = null

        jpgTcpSender?.stop()
        jpgTcpSender = null
        compressExecutor.shutdownNow()
        NaviFramePreview.setRunning(false)
        NaviFramePreview.clear()
        NaviPerfStats.clear()

        mainHandler.post {
            try {
                presentation?.dismiss()
            } catch (_: Exception) {
            }
            presentation = null
            try {
                if (AMapNavi.getInstance(applicationContext) != null) {
                    AMapNavi.getInstance(applicationContext).stopNavi()
                }
            } catch (_: Exception) {
            }
            AMapNavi.destroy()
        }

        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        try {
            if (screenWakeLock?.isHeld == true) screenWakeLock?.release()
        } catch (_: Exception) {
        }
        screenWakeLock = null
        try {
            if (cpuWakeLock?.isHeld == true) cpuWakeLock?.release()
        } catch (_: Exception) {
        }
        cpuWakeLock = null
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: Exception) {
        }
        wifiLock = null
    }

    /**
     * 承载 [AMapNaviView] 的 Presentation。Presentation 使用虚拟屏的 Context，内容会渲染到虚拟屏。
     */
    private class NaviPresentation(
        outerContext: Context,
        display: Display,
        private val uiRenderScale: Float,
        private val jpgWidth: Int,
        private val jpgHeight: Int,
        private val onSetupNavi: (AMapNaviView) -> Unit,
    ) : Presentation(outerContext, display) {

        private var naviView: AMapNaviView? = null

        override fun onCreate(savedInstanceState: Bundle?) {
            // Android 12(S)+：Presentation 自带一个绑定到 display 的 window context（R 引入），
            // 其窗口类型固定为 TYPE_PRESENTATION(2030)，从 Service 显示也自带合法 token，无需
            // Activity token。此时若再把窗口类型强设为 TYPE_APPLICATION_OVERLAY(2038)，会与
            // window context 的类型不一致，触发 assertWindowContextTypeMatches 抛出：
            //   IllegalArgumentException: Window type mismatch. ... 2030 ... 2038
            // 导致 Presentation.show() 崩溃、Service 自杀、TCP sender 被关。故 S+ 保持默认的
            // TYPE_PRESENTATION，不再覆盖窗口类型。
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                // R 以下的 Presentation 没有 window context，从 Service（无 Activity token）显示
                // 必须用 overlay 类型窗口，否则抛 BadTokenException: token null is not for an application。
                @Suppress("DEPRECATION")
                val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }
                window?.setType(overlayType)
            }
            // 让投屏窗口在锁屏界面上仍保持可见/持续渲染，避免虚拟屏输出黑帧。
            @Suppress("DEPRECATION")
            window?.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
            super.onCreate(savedInstanceState)
            val container = FrameLayout(context).apply {
                clipChildren = true
                clipToPadding = true
            }
            val view = AMapNaviView(context)
            view.onCreate(savedInstanceState)
            view.viewOptions = AMapNaviViewOptions().apply {
                isAutoLockCar = true
                isTrafficLine = true
            }
            val layoutWidth = (jpgWidth * uiRenderScale).toInt().coerceAtLeast(1)
            val layoutHeight = (jpgHeight * uiRenderScale).toInt().coerceAtLeast(1)
            view.pivotX = 0f
            view.pivotY = 0f
            view.scaleX = 1f / uiRenderScale
            view.scaleY = 1f / uiRenderScale
            container.addView(
                view,
                FrameLayout.LayoutParams(
                    layoutWidth,
                    layoutHeight,
                ),
            )
            setContentView(container)
            naviView = view
            view.onResume()
            onSetupNavi(view)
        }

        override fun onStop() {
            // 锁屏/熄屏时 Dialog/Presentation 可能收到 onStop；如果此处暂停 AMapNaviView，
            // GLSurfaceView 会停止绘制，ImageReader 随后读到黑屏。虚拟屏投屏需要保持渲染。
            super.onStop()
        }

        override fun dismiss() {
            naviView?.onDestroy()
            naviView = null
            super.dismiss()
        }
    }

    companion object {
        private const val TAG = "NaviCaptureService"
        private const val NOTIFICATION_ID = 0x4001
        private const val VIRTUAL_DISPLAY_NAME = "NaviVirtualDisplay"

        // 投屏分辨率默认值与允许范围。宽/高可由 UI 通过 EXTRA_WIDTH / EXTRA_HEIGHT 指定。
        const val DEFAULT_JPG_WIDTH = 400
        const val DEFAULT_JPG_HEIGHT = 480
        private const val MIN_DIMENSION = 160
        private const val MAX_DIMENSION = 1920
        private const val JPG_QUALITY = 60
        // UI 缩放默认值（语义：渲染倍率 = 值/160）。160 = 1.0 倍，直接渲染 400×480，
        // 无需缩放，帧率最高（优化 1）。值越大渲染画布越大、UI 越小但帧率越低。
        const val DEFAULT_VIRTUAL_DISPLAY_DPI = 160
        private const val DEFAULT_TCP_PORT = 5004
        private const val DEFAULT_TCP_FPS = 5

        const val EXTRA_START_LAT = "extra_start_lat"
        const val EXTRA_START_LNG = "extra_start_lng"
        const val EXTRA_END_LAT = "extra_end_lat"
        const val EXTRA_END_LNG = "extra_end_lng"
        const val EXTRA_SPEED = "extra_speed"
        const val EXTRA_TCP_HOST = "extra_tcp_host"
        const val EXTRA_TCP_PORT = "extra_tcp_port"
        const val EXTRA_TCP_FPS = "extra_tcp_fps"
        const val EXTRA_DPI = "extra_dpi"
        const val EXTRA_WIDTH = "extra_width"
        const val EXTRA_HEIGHT = "extra_height"
        const val ACTION_STOP = "com.example.map1.navi.action.STOP"

        /** 结束虚拟屏导航的 Intent。 */
        fun stopIntent(context: Context): Intent =
            Intent(context, NaviCaptureService::class.java).apply { action = ACTION_STOP }

        fun newIntent(
            context: Context,
            host: String,
            port: Int,
            fps: Int,
            speed: Int,
            dpi: Int,
            width: Int,
            height: Int,
            startLat: Double,
            startLng: Double,
            endLat: Double,
            endLng: Double,
        ): Intent = Intent(context, NaviCaptureService::class.java).apply {
            putExtra(EXTRA_TCP_HOST, host)
            putExtra(EXTRA_TCP_PORT, port)
            putExtra(EXTRA_TCP_FPS, fps)
            putExtra(EXTRA_SPEED, speed)
            putExtra(EXTRA_DPI, dpi)
            putExtra(EXTRA_WIDTH, width)
            putExtra(EXTRA_HEIGHT, height)
            putExtra(EXTRA_START_LAT, startLat)
            putExtra(EXTRA_START_LNG, startLng)
            putExtra(EXTRA_END_LAT, endLat)
            putExtra(EXTRA_END_LNG, endLng)
        }
    }
}
