package com.example.map1

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.LinkOff
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.example.map1.i18n.DashboardI18n
import com.example.map1.i18n.LanguageMenuButton
import com.example.map1.i18n.LanguagePreference
import com.example.map1.i18n.LocalAppStrings
import com.example.map1.i18n.appStrings
import com.example.map1.navi.NaviActivity
import com.example.map1.navi.NaviFramePreview
import com.example.map1.navi.NaviPerfStats
import com.example.map1.navi.NaviProjectionActivity
import com.example.map1.search.Place
import com.example.map1.search.searchPlaces
import com.example.map1.ui.theme.Map1Theme
import com.example.map1.util.NetworkUtils
import com.google.zxing.client.android.Intents
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MapHomeActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Must run before the first string lookup (the toast below).
        LanguagePreference.ensureLoaded(this)
        val mapReady = MapSdkInitializer.initialize(applicationContext)
        if (!mapReady) {
            // Key-less local builds still open the dashboard: BLE connect and the
            // add-device flow do not touch AMap.
            android.widget.Toast.makeText(
                this,
                appStrings(this).missingApiKeyToast,
                android.widget.Toast.LENGTH_LONG,
            ).show()
        }
        enableEdgeToEdge()
        setContent {
            Map1Theme {
                DashboardI18n {
                    Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                        NaviHomeScreen(
                            modifier = Modifier
                                .padding(innerPadding)
                                .consumeWindowInsets(innerPadding)
                        )
                    }
                }
            }
        }
    }
}

/** 常用投屏分辨率预设（宽 to 高，像素）。 */
private val RESOLUTION_PRESETS = listOf(
    410 to 370,
    480 to 800,
    600 to 1024,
    720 to 1280,
    800 to 480,
    1024 to 600,
    1280 to 720,
)

private data class ReceiverEndpoint(val host: String, val port: Int)

/** Accepts a host, host:port, or URI whose authority contains a valid receiver endpoint. */
private fun parseReceiverEndpoint(rawValue: String): ReceiverEndpoint? {
    val value = rawValue.trim()
    if (value.isEmpty() || value.any { it.isWhitespace() }) return null

    val authority = if (value.contains("://")) {
        val uri = runCatching { java.net.URI(value) }.getOrNull() ?: return null
        if (uri.scheme?.lowercase() != "tcp" || uri.port == -1 || uri.userInfo != null ||
            !uri.rawPath.isNullOrEmpty() && uri.rawPath != "/" ||
            uri.rawQuery != null || uri.rawFragment != null
        ) return null
        val host = uri.host ?: return null
        host to uri.port
    } else {
        if (value.contains('/') || value.contains('?') || value.contains('#') || value.contains('@')) return null
        val separator = value.lastIndexOf(':')
        if (separator > 0) {
            val portText = value.substring(separator + 1)
            if (portText.isEmpty() || !portText.all(Char::isDigit)) return null
            value.substring(0, separator) to (portText.toIntOrNull() ?: return null)
        } else {
            value to 5004
        }
    }

    val host = authority.first.lowercase()
    val port = authority.second
    val ipv4Valid = host.split('.').let { parts ->
        parts.size == 4 && parts.all { part ->
            part.isNotEmpty() && part.all(Char::isDigit) &&
                (part.toIntOrNull() ?: -1) in 0..255
        }
    }
    val dnsValid = host.contains('.') && host.length <= 253 && host.split('.').all { label ->
        label.length in 1..63 && label.first().isLetterOrDigit() &&
            label.last().isLetterOrDigit() && label.all { it.isLetterOrDigit() || it == '-' }
    }
    return if ((ipv4Valid || dnsValid) && port in 1..65535) ReceiverEndpoint(host, port) else null
}

@Composable
fun NaviHomeScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val strings = LocalAppStrings.current

    // 通过地点搜索选出的起点/终点（默认：苏州金鸡湖 -> 拙政园，坐标为高德 GCJ-02）
    var startPlace by remember {
        mutableStateOf<Place?>(
            Place(name = "金鸡湖", address = "苏州工业园区", latitude = 31.314, longitude = 120.728)
        )
    }
    var endPlace by remember {
        mutableStateOf<Place?>(
            Place(name = "拙政园", address = "苏州市姑苏区", latitude = 31.325, longitude = 120.629)
        )
    }
    var speed by remember { mutableStateOf("60") }
    // 接收端 IP，留空不发送（不预填，由用户手动输入或扫描选择）
    var tcpHost by remember { mutableStateOf("") }
    var tcpPort by remember { mutableStateOf("5004") }
    var tcpFps by remember { mutableStateOf("5") }
    // 虚拟屏 DPI（影响导航 UI 字号大小），由滑块调整
    var virtualDpi by remember {
        mutableStateOf(com.example.map1.navi.NaviCaptureService.DEFAULT_VIRTUAL_DISPLAY_DPI.toFloat())
    }
    // 投屏分辨率（宽×高），可从预设下拉选择或手动输入
    var castWidth by remember {
        mutableStateOf(com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_WIDTH.toString())
    }
    var castHeight by remember {
        mutableStateOf(com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_HEIGHT.toString())
    }
    var resolutionMenuExpanded by remember { mutableStateOf(false) }
    // 本机局域网 IP（提示用，帮助确认网段）
    var localIp by remember { mutableStateOf<String?>(null) }
    // 局域网扫描相关
    var lanDevices by remember { mutableStateOf<List<com.example.map1.util.LanDevice>>(emptyList()) }
    var scanning by remember { mutableStateOf(false) }
    var scanProgress by remember { mutableStateOf(0) }
    var deviceMenuExpanded by remember { mutableStateOf(false) }
    // 虚拟屏导航实际运行状态由 Service 决定（启动 true / 销毁 false）。
    // 这样到达终点后 Service 自行停止或用户点击结束，都能自动回到「开始虚拟屏导航」。
    val virtualNaviRunning by NaviFramePreview.running.collectAsState()
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    val vehicleWifiState by VehicleWifiManager.state.collectAsState()
    val vehicleBleState by VehicleBleManager.state.collectAsState()
    // BLE 投屏发送器实例
    var bleSender by remember { mutableStateOf<NaviBleFrameSender?>(null) }
    val bleProjecting = bleSender?.state == NaviBleFrameSender.State.SENDING ||
        bleSender?.state == NaviBleFrameSender.State.OPENING
    // 复用同一个 sender：既避免重复绑定 onNaviNotify，也让握手结果（设备宽高/FPS）
    // 在连接后查询一次就能被「开始投屏」直接沿用。
    fun ensureBleSender(): NaviBleFrameSender {
        bleSender?.let { return it }
        val sender = NaviBleFrameSender(
            onStatus = { status ->
                val text = strings.castStatus(status)
                scope.launch {
                    // 同一状态连续上报（重试、区域不变）不重复排队，否则浮条会一直挂在屏幕上。
                    if (snackbarHostState.currentSnackbarData?.visuals?.message != text) {
                        snackbarHostState.showSnackbar(text)
                    }
                }
            },
        )
        bleSender = sender
        VehicleBleManager.onNaviNotify = { uuid, value -> sender.onNotify(uuid, value) }
        return sender
    }

    var pendingVehicleConfig by remember { mutableStateOf<VehicleQrProtocol.Config?>(null) }
    var pendingBleConfig by remember { mutableStateOf<VehicleQrProtocol.BleConfig?>(null) }
    var scanError by remember { mutableStateOf<String?>(null) }
    // 握手失败 / 连接失败的原因。VehicleBleManager 已经主动丢弃链路，这里只负责
    // 把原因告诉用户并把状态复位回 Idle（否则右上角会一直挂着「断开」）。
    var connectFailure by remember { mutableStateOf<String?>(null) }
    var lastScan by remember { mutableStateOf<Pair<String, Long>?>(null) }

    fun handleScanResult(contents: String) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (lastScan?.let { it.first == contents && now - it.second < 2_000 } == true) return
        lastScan = contents to now
        when (val result = VehicleQrProtocol.parse(contents)) {
            is VehicleQrProtocol.Result.WifiSuccess -> {
                tcpHost = result.config.ip
                tcpPort = result.config.port.toString()
                pendingVehicleConfig = result.config
            }
            is VehicleQrProtocol.Result.BleSuccess -> pendingBleConfig = result.config
            is VehicleQrProtocol.Result.Failure ->
                scanError = strings.scanRejected(strings.qrErrorText(result.error))
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let(::handleScanResult)
    }
    fun openScanner() {
        scanLauncher.launch(
            ScanOptions().apply {
                setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                setPrompt(strings.qrScannerPrompt)
                setBeepEnabled(false)
                setOrientationLocked(false)
                setBarcodeImageEnabled(false)
                setCaptureActivity(QrScannerActivity::class.java)
                addExtra(Intents.Scan.SCAN_TYPE, Intents.Scan.MIXED_SCAN)
            }
        )
    }
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) openScanner()
        else scope.launch { snackbarHostState.showSnackbar(strings.snackCameraDenied) }
    }

    // 手动添加设备：仪表不一定有二维码，改为扫广播发现后直连。复用同一个
    // VehicleBleManager，所以连接/投屏状态与扫码路径完全一致。
    val addDevicePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        if (grants.values.all { it }) {
            context.startActivity(Intent(context, AddBleDeviceActivity::class.java))
        } else {
            scope.launch {
                snackbarHostState.showSnackbar(strings.snackNearbyDeniedForScan)
            }
        }
    }

    fun openAddDevice() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            context.startActivity(Intent(context, AddBleDeviceActivity::class.java))
        } else {
            addDevicePermissionLauncher.launch(missing.toTypedArray())
        }
    }

    val blePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val config = pendingBleConfig
        if (config != null && grants.values.all { it }) {
            pendingBleConfig = null
            VehicleBleManager.connect(context, config)
        } else if (config != null) {
            scope.launch { snackbarHostState.showSnackbar(strings.snackNearbyDeniedForBle) }
        }
    }
    val wifiPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        val config = pendingVehicleConfig
        if (granted && config != null) {
            tcpHost = config.ip
            tcpPort = config.port.toString()
            pendingVehicleConfig = null
            VehicleWifiManager.connect(context, config)
        } else if (!granted) {
            scope.launch { snackbarHostState.showSnackbar(strings.snackWifiDenied) }
        }
    }

    fun confirmBleConfig(config: VehicleQrProtocol.BleConfig) {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            pendingBleConfig = null
            VehicleBleManager.connect(context, config)
        } else {
            blePermissionLauncher.launch(missing.toTypedArray())
        }
    }

    fun confirmVehicleConfig(config: VehicleQrProtocol.Config) {
        if (!config.connectsVehicleAp) {
            tcpHost = config.ip
            tcpPort = config.port.toString()
            pendingVehicleConfig = null
            scope.launch { snackbarHostState.showSnackbar(strings.snackActionWithoutVehicleAp) }
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            pendingVehicleConfig = null
            scanError = strings.errorLegacyWifiSelection
            return
        }
        val wifiManager = context.applicationContext.getSystemService(WifiManager::class.java)
        if (!wifiManager.isWifiEnabled) {
            runCatching {
                context.startActivity(Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }.recoverCatching {
                context.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            scope.launch { snackbarHostState.showSnackbar(strings.snackEnableWifiFirst) }
            return
        }
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED) {
            tcpHost = config.ip
            tcpPort = config.port.toString()
            pendingVehicleConfig = null
            VehicleWifiManager.connect(context, config)
        } else {
            wifiPermissionLauncher.launch(permission)
        }
    }

    // 启动时仅查询本机 IP 作网段提示，不预填接收端地址
    LaunchedEffect(Unit) {
        localIp = withContext(Dispatchers.IO) { NetworkUtils.getLocalIpv4() }
    }

    // 握手没通过（服务缺失、通知订阅失败、超时）时 manager 会先自断链路并把原因
    // 放进 State.Error：弹窗说明，同时复位到 Idle，让右上角回到「连接 / 扫一扫」。
    LaunchedEffect(vehicleBleState) {
        when (val state = vehicleBleState) {
            is VehicleBleManager.State.Error -> {
                connectFailure = strings.bleErrorText(state.error)
                VehicleBleManager.disconnect()
            }

            // NaviReady 表示 MTU 已协商、0xFFC2 通知已订阅，此时 0x05 才能收到应答。
            // 连上就问一次，把设备真正要求的 FPS / 投屏区域回填到输入框。
            is VehicleBleManager.State.NaviReady -> {
                val info = ensureBleSender().probeDeviceInfo() ?: return@LaunchedEffect
                if (info.width > 0 && info.height > 0) {
                    castWidth = info.width.toString()
                    castHeight = info.height.toString()
                }
                info.requestedFps.takeIf { it in 1..60 }?.let { tcpFps = it.toString() }
            }

            // 断开后丢掉 sender：下次连接要重新握手（MTU 可能变了）。
            is VehicleBleManager.State.Disconnected, is VehicleBleManager.State.Idle -> {
                bleSender?.stop()
                bleSender = null
            }

            else -> Unit
        }
    }

    connectFailure?.let { message ->
        AlertDialog(
            onDismissRequest = { connectFailure = null },
            title = { Text(strings.connectFailedTitle) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { connectFailure = null }) { Text(strings.gotIt) }
            },
        )
    }

    pendingVehicleConfig?.let { config ->
        BackHandler { pendingVehicleConfig = null }
        AlertDialog(
            onDismissRequest = { pendingVehicleConfig = null },
            title = { Text(strings.confirmVehicleTitle) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(strings.fieldModel(config.modelId))
                    Text(strings.fieldSn(config.serialNumber))
                    Text(strings.fieldAction(config.action.toString(), config.actionHex))
                    Text(strings.fieldSsid(config.ssid))
                    Text(strings.fieldEndpoint("${config.ip}:${config.port}"))
                    Text(strings.fieldPasswordHidden)
                    if (config.connectsVehicleAp) Text(strings.wifiApprovalNotice)
                    if (config.customLocalAp) Text(strings.localApNotice)
                }
            },
            confirmButton = {
                TextButton(onClick = { confirmVehicleConfig(config) }) { Text(strings.confirm) }
            },
            dismissButton = {
                TextButton(onClick = { pendingVehicleConfig = null }) { Text(strings.cancel) }
            },
        )
    }
    pendingBleConfig?.let { config ->
        BackHandler { pendingBleConfig = null }
        AlertDialog(
            onDismissRequest = { pendingBleConfig = null },
            title = { Text(strings.bleDetectedTitle) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(strings.fieldModel(config.modelId))
                    Text(strings.fieldSn(config.serialNumber))
                    Text(strings.fieldBleAddress(config.address))
                    Text(
                        strings.fieldApk(config.apkUrl),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(strings.bleGattNotice)
                }
            },
            confirmButton = {
                TextButton(onClick = { confirmBleConfig(config) }) { Text(strings.connect) }
            },
            dismissButton = {
                TextButton(onClick = { pendingBleConfig = null }) { Text(strings.cancel) }
            },
        )
    }
    scanError?.let { error ->
        AlertDialog(
            onDismissRequest = { scanError = null },
            title = { Text(strings.invalidQrTitle) },
            text = { Text(error) },
            confirmButton = { TextButton(onClick = { scanError = null }) { Text(strings.back) } },
        )
    }

    // 当前正在搜索的目标：null=不在搜索界面，true=选起点，false=选终点
    var searchingForStart by remember { mutableStateOf<Boolean?>(null) }
    var pendingNaviLaunch by remember { mutableStateOf<(() -> Unit)?>(null) }

    fun launchNavi() {
        val s = startPlace ?: return
        val e = endPlace ?: return
        val intent = Intent(context, NaviActivity::class.java).apply {
            putExtra(NaviActivity.EXTRA_START_LAT, s.latitude)
            putExtra(NaviActivity.EXTRA_START_LNG, s.longitude)
            putExtra(NaviActivity.EXTRA_END_LAT, e.latitude)
            putExtra(NaviActivity.EXTRA_END_LNG, e.longitude)
            putExtra(NaviActivity.EXTRA_SPEED, speed.toIntOrNull() ?: 60)
            putExtra(NaviActivity.EXTRA_TCP_HOST, tcpHost.trim())
            putExtra(NaviActivity.EXTRA_TCP_PORT, tcpPort.toIntOrNull() ?: 5004)
            putExtra(NaviActivity.EXTRA_TCP_FPS, tcpFps.toIntOrNull() ?: 5)
        }
        context.startActivity(intent)
    }

    // 方案 X：把导航渲染到 400×480 虚拟屏，App 可切后台 / 主屏黑屏仍持续发送
    fun launchVirtualNavi() {
        val s = startPlace ?: return
        val e = endPlace ?: return
        val intent = Intent(context, NaviProjectionActivity::class.java).apply {
            putExtra(NaviActivity.EXTRA_START_LAT, s.latitude)
            putExtra(NaviActivity.EXTRA_START_LNG, s.longitude)
            putExtra(NaviActivity.EXTRA_END_LAT, e.latitude)
            putExtra(NaviActivity.EXTRA_END_LNG, e.longitude)
            putExtra(NaviActivity.EXTRA_SPEED, speed.toIntOrNull() ?: 60)
            putExtra(NaviActivity.EXTRA_TCP_HOST, tcpHost.trim())
            putExtra(NaviActivity.EXTRA_TCP_PORT, tcpPort.toIntOrNull() ?: 5004)
            putExtra(NaviActivity.EXTRA_TCP_FPS, tcpFps.toIntOrNull() ?: 5)
            putExtra(
                com.example.map1.navi.NaviCaptureService.EXTRA_DPI,
                virtualDpi.toInt(),
            )
            putExtra(
                com.example.map1.navi.NaviCaptureService.EXTRA_WIDTH,
                castWidth.toIntOrNull() ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_WIDTH,
            )
            putExtra(
                com.example.map1.navi.NaviCaptureService.EXTRA_HEIGHT,
                castHeight.toIntOrNull() ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_HEIGHT,
            )
        }
        context.startActivity(intent)
    }

    // 结束虚拟屏后台导航（运行状态由 Service 销毁时回置，无需在此手动置位）
    fun stopVirtualNavi() {
        bleSender?.stop()
        bleSender = null
        context.startService(
            com.example.map1.navi.NaviCaptureService.stopIntent(context)
        )
    }

    // BLE 投屏：启动 NaviCaptureService (host="", 不走 TCP) + BLE sender
    fun launchVirtualBleNavi() {
        val s = startPlace ?: return
        val e = endPlace ?: return

        val quality = 60

        // 先建 sender 并问设备要投屏区域：JPEG 尺寸在 NaviCaptureService 启动时就固定了，
        // 所以必须在启动虚拟屏之前拿到设备的实际宽高（老固件不回应则退回用户设置）。
        // 连接时通常已经查过一次，这里命中缓存、不会重复发 0x05。
        val sender = ensureBleSender()

        scope.launch {
            // 连接时已把设备上报的区域与 FPS 填进输入框，这里以输入框为准：
            // 用户改了就用用户的（自定义覆盖），只有输入框为空/非法时才退回设备值。
            val info = sender.probeDeviceInfo()
            val w = castWidth.toIntOrNull() ?: info?.width
                ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_WIDTH
            val h = castHeight.toIntOrNull() ?: info?.height
                ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_HEIGHT
            // 设备直接给出建议质量（单一值）；未上报或超出合理区间时用本地默认。
            val q = info?.quality?.takeIf { it in 10..100 } ?: quality
            // 采样率同理：输入框优先，随后才用设备请求值。
            val fpsEff = (tcpFps.toIntOrNull() ?: info?.requestedFps ?: 5).coerceIn(1, 60)

            val intent = Intent(context, NaviProjectionActivity::class.java).apply {
                putExtra(NaviActivity.EXTRA_START_LAT, s.latitude)
                putExtra(NaviActivity.EXTRA_START_LNG, s.longitude)
                putExtra(NaviActivity.EXTRA_END_LAT, e.latitude)
                putExtra(NaviActivity.EXTRA_END_LNG, e.longitude)
                putExtra(NaviActivity.EXTRA_SPEED, speed.toIntOrNull() ?: 60)
                putExtra(NaviActivity.EXTRA_TCP_HOST, "")  // 不走 TCP
                putExtra(NaviActivity.EXTRA_TCP_PORT, 0)
                putExtra(NaviActivity.EXTRA_TCP_FPS, fpsEff)
                putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_DPI, virtualDpi.toInt())
                putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_WIDTH, w)
                putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_HEIGHT, h)
                putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_QUALITY, q)
            }
            context.startActivity(intent)

            sender.start(w, h, fpsEff, q)
        }
    }

    // 请求定位权限（模拟导航本身不强依赖，但 SDK 初始化需要）
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) {
        pendingNaviLaunch?.invoke()
        pendingNaviLaunch = null
    }

    // 进入搜索界面时只显示搜索页
    val target = searchingForStart
    if (target != null) {
        PlaceSearchScreen(
            title = if (target) strings.pickStartTitle else strings.pickEndTitle,
            onBack = { searchingForStart = null },
            onPick = { place ->
                if (target) startPlace = place else endPlace = place
                searchingForStart = null
            },
            modifier = modifier,
        )
        return
    }

    // 导航进行中：投屏 JPG 预览铺满整屏，隐藏其余控件，仅保留底部「结束虚拟屏导航」按钮。
    if (virtualNaviRunning || bleProjecting) {
        // The projection screen returns before the main Scaffold, so it needs its
        // own SnackbarHost -- otherwise showSnackbar() (e.g. "投屏异常…") has no
        // host to render into and the message is silently dropped.
        // The stop button lives in bottomBar on purpose: Scaffold stacks the
        // SnackbarHost above the bottomBar, so cast-status messages never cover it.
        Scaffold(
            modifier = modifier.fillMaxSize(),
            snackbarHost = { SnackbarHost(snackbarHostState) },
            bottomBar = {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Button(
                        onClick = { stopVirtualNavi() },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (bleProjecting) strings.endBleCasting else strings.endVirtualNavi)
                    }
                }
            },
        ) { contentPadding ->
            val previewAspect = run {
                val w = castWidth.toIntOrNull()?.takeIf { it > 0 } ?: 410
                val h = castHeight.toIntOrNull()?.takeIf { it > 0 } ?: 370
                w.toFloat() / h.toFloat()
            }
            // 播放器式布局：整块黑底铺满，画面按自身比例居中留黑边，按钮固定在最底部。
            NaviJpgPreviewWindow(
                aspectRatio = previewAspect,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(contentPadding)
                    .padding(16.dp),
            )
        }
        return
    }

    // 主界面：起点 / 终点选择 + 开始导航（可滚动，防止内容超出屏幕）
    Scaffold(
        modifier = modifier.fillMaxSize(),
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { contentPadding ->
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(contentPadding)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = strings.dashboardTitle,
                style = MaterialTheme.typography.headlineSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            // 已连线时两个入口合并成一个「断开」；连接中显示「取消」。
            val bleLinkUp = vehicleBleState is VehicleBleManager.State.Connecting ||
                vehicleBleState is VehicleBleManager.State.Connected ||
                vehicleBleState is VehicleBleManager.State.NaviReady
            val wifiLinkUp = vehicleWifiState is VehicleWifiManager.State.ApprovalPending ||
                vehicleWifiState is VehicleWifiManager.State.Available
            if (bleLinkUp || wifiLinkUp) {
                TextButton(
                    onClick = {
                        VehicleBleManager.disconnect()
                        VehicleWifiManager.disconnect()
                    },
                ) {
                    Icon(Icons.Outlined.LinkOff, contentDescription = null)
                    Text(
                        text = if (vehicleBleState is VehicleBleManager.State.Connecting) {
                            strings.cancel
                        } else {
                            strings.disconnect
                        },
                        modifier = Modifier.padding(start = 4.dp),
                    )
                }
            } else {
                // 没有二维码的仪表走「+ 连接」：广播过滤后手动选设备。
                TextButton(onClick = ::openAddDevice) {
                    Icon(Icons.Outlined.Add, contentDescription = null)
                    Text(strings.connect, modifier = Modifier.padding(start = 4.dp))
                }
                TextButton(
                    onClick = {
                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                            PackageManager.PERMISSION_GRANTED
                        ) openScanner() else cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                    },
                ) {
                    Icon(Icons.Outlined.QrCodeScanner, contentDescription = null)
                    Text(strings.scanQrCode, modifier = Modifier.padding(start = 4.dp))
                }
            }
        }

        // ── 连接信息（单行，仅显示当前活跃连接方式的信息）──
        // BLE 优先（与投屏按钮逻辑一致）：BLE 处于非空闲状态时展示 BLE 信息；
        // 否则若 Wi-Fi 处于非空闲状态则展示 Wi-Fi 信息；均空闲时提示扫码建连。
        val bleActive = vehicleBleState !is VehicleBleManager.State.Idle
        val wifiActive = vehicleWifiState !is VehicleWifiManager.State.Idle
        val connText: String
        val connColor: Color
        if (bleActive) {
            connText = when (val s = vehicleBleState) {
                is VehicleBleManager.State.Connecting ->
                    strings.bleConnecting(s.config.address)
                is VehicleBleManager.State.Connected ->
                    strings.bleConnected(s.config.modelId, s.config.address)
                is VehicleBleManager.State.NaviReady ->
                    strings.bleNaviReady(s.config.modelId)
                is VehicleBleManager.State.Disconnected ->
                    strings.bleDisconnected(s.config.address)
                is VehicleBleManager.State.Error -> strings.bleError(s.error)
                else -> strings.bleIdle
            }
            connColor = when (vehicleBleState) {
                is VehicleBleManager.State.NaviReady -> MaterialTheme.colorScheme.primary
                is VehicleBleManager.State.Error, is VehicleBleManager.State.Disconnected ->
                    MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.outline
            }
        } else if (wifiActive) {
            connText = when (val s = vehicleWifiState) {
                is VehicleWifiManager.State.ApprovalPending ->
                    strings.wifiApprovalPending(s.ssid)
                is VehicleWifiManager.State.Available -> strings.wifiConnected(s.ssid)
                is VehicleWifiManager.State.Lost -> strings.wifiLost(s.ssid)
                is VehicleWifiManager.State.Error -> strings.wifiError(s.error)
                else -> strings.wifiIdle
            }
            connColor = when (vehicleWifiState) {
                is VehicleWifiManager.State.Error, is VehicleWifiManager.State.Lost ->
                    MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.outline
            }
        } else {
            connText = strings.noConnection
            connColor = MaterialTheme.colorScheme.outline
        }
        // 状态行右侧放语言入口：标题栏已经排满「连接 / 扫一扫」，再塞图标会把标题挤断。
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = connText,
                style = MaterialTheme.typography.bodySmall,
                color = connColor,
                modifier = Modifier.weight(1f),
            )
            LanguageMenuButton()
        }

        // 起点 / 终点放同一行节省纵向空间
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PlaceSelector(
                label = strings.startPoint,
                place = startPlace,
                onClick = { searchingForStart = true },
                modifier = Modifier.weight(1f),
            )
            PlaceSelector(
                label = strings.endPoint,
                place = endPlace,
                onClick = { searchingForStart = false },
                modifier = Modifier.weight(1f),
            )
        }

        // 模拟速度 + 接收端 IP 放同一行
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = speed,
                onValueChange = { speed = it },
                label = { Text(strings.speedLabel) },
                singleLine = true,
                modifier = Modifier.weight(0.45f)
            )
            OutlinedTextField(
                value = tcpHost,
                onValueChange = { tcpHost = it },
                label = { Text(strings.receiverHostLabel) },
                singleLine = true,
                modifier = Modifier.weight(0.55f)
            )
        }

        Text(
            text = localIp?.let { strings.localIp(it) } ?: strings.localIpUnknown,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.outline,
        )

        // 扫描局域网 + 下拉选择设备
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                onClick = {
                    if (scanning) return@TextButton
                    scanning = true
                    scanProgress = 0
                    lanDevices = emptyList()
                    deviceMenuExpanded = false
                    scope.launch {
                        val result = withContext(Dispatchers.IO) {
                            NetworkUtils.scanLan(timeoutMs = 300) { scanned, total ->
                                scanProgress = scanned * 100 / total
                            }
                        }
                        lanDevices = result
                        scanning = false
                        deviceMenuExpanded = result.isNotEmpty()
                    }
                },
                enabled = !scanning,
            ) {
                Text(if (scanning) strings.scanningLan(scanProgress) else strings.scanLanDevices)
            }

            if (lanDevices.isNotEmpty()) {
                Box {
                    TextButton(onClick = { deviceMenuExpanded = true }) {
                        Text(strings.pickDevice(lanDevices.size))
                    }
                    DropdownMenu(
                        expanded = deviceMenuExpanded,
                        onDismissRequest = { deviceMenuExpanded = false },
                    ) {
                        lanDevices.forEach { device ->
                            DropdownMenuItem(
                                text = { Text(device.label) },
                                onClick = {
                                    tcpHost = device.ip
                                    deviceMenuExpanded = false
                                },
                            )
                        }
                    }
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = tcpPort,
                onValueChange = { tcpPort = it },
                label = { Text(strings.portLabel) },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = tcpFps,
                onValueChange = { tcpFps = it },
                label = { Text("FPS") },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
        }

        // 投屏分辨率：宽×高。可从常用预设下拉选择，或手动输入自定义值。
        Text(
            text = strings.resolutionSection,
            style = MaterialTheme.typography.bodySmall,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = castWidth,
                onValueChange = { castWidth = it.filter { c -> c.isDigit() } },
                label = { Text(strings.widthLabel) },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = castHeight,
                onValueChange = { castHeight = it.filter { c -> c.isDigit() } },
                label = { Text(strings.heightLabel) },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Box {
                TextButton(onClick = { resolutionMenuExpanded = true }) {
                    Text(strings.presetLabel)
                }
                DropdownMenu(
                    expanded = resolutionMenuExpanded,
                    onDismissRequest = { resolutionMenuExpanded = false },
                ) {
                    RESOLUTION_PRESETS.forEach { (w, h) ->
                        DropdownMenuItem(
                            text = { Text("${w}×$h") },
                            onClick = {
                                castWidth = w.toString()
                                castHeight = h.toString()
                                resolutionMenuExpanded = false
                            },
                        )
                    }
                }
            }
        }

        // UI 缩放滑块：通过改变虚拟屏渲染分辨率来真正改变导航 UI 控件尺寸。
        // 值越大 → 渲染画布越大 → 缩放回目标分辨率后 UI/字越小。160=原始大小。
        Text(
            text = strings.zoomLabel(virtualDpi.toInt()),
            style = MaterialTheme.typography.bodySmall,
        )
        Slider(
            value = virtualDpi,
            onValueChange = { virtualDpi = it },
            valueRange = 160f..480f,
            steps = (480 - 160) / 20 - 1,
            modifier = Modifier.fillMaxWidth(),
        )

        // 投屏按钮：BLE 就绪时走 BLE，否则走 WiFi/预览
        val bleReady = vehicleBleState is VehicleBleManager.State.NaviReady

        Button(
            onClick = {
                val action = if (bleReady) ::launchVirtualBleNavi else ::launchVirtualNavi
                val fineGranted = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                if (fineGranted) {
                    action()
                } else {
                    pendingNaviLaunch = action
                    permissionLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        )
                    )
                }
            },
            enabled = startPlace != null && endPlace != null,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(when {
                bleReady -> strings.startBleCasting
                tcpHost.isNotBlank() -> strings.startWifiCasting
                else -> strings.startPreviewCasting
            })
        }
    }
    }
}

/** 主界面上的小窗口：同步显示虚拟屏服务最新生成的投屏 JPG，并在左上角叠加流程耗时/帧率日志。 */
@Composable
private fun NaviJpgPreviewWindow(
    aspectRatio: Float = 400f / 480f,
    modifier: Modifier = Modifier,
) {
    val frame by NaviFramePreview.latestFrame.collectAsState()
    val perf by NaviPerfStats.snapshot.collectAsState()
    val strings = LocalAppStrings.current
    val imageBitmap = remember(frame) {
        val jpeg = frame?.jpeg ?: return@remember null
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)?.asImageBitmap()
    }

    Card(modifier = modifier) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                // Black letterbox like a video player: the JPG keeps its own aspect.
                .background(Color.Black)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant),
            contentAlignment = Alignment.Center,
        ) {
            if (imageBitmap != null) {
                Image(
                    bitmap = imageBitmap,
                    contentDescription = strings.previewDescription,
                    contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(aspectRatio),
                )
            } else {
                Text(
                    text = strings.previewPlaceholder,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.6f),
                )
            }

            // 左上角叠加流程耗时日志，帮助定位帧率瓶颈。
            Text(
                text = strings.perfOverlayText(perf),
                style = MaterialTheme.typography.labelSmall,
                color = Color.Green,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .background(Color.Black.copy(alpha = 0.55f))
                    .padding(horizontal = 6.dp, vertical = 4.dp),
            )
        }
    }
}

/** 起点/终点选择条目，点击后进入搜索界面。 */
@Composable
private fun PlaceSelector(
    label: String,
    place: Place?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = label, style = MaterialTheme.typography.labelMedium)
            Text(
                text = place?.name ?: LocalAppStrings.current.pickPlaceHint,
                style = MaterialTheme.typography.titleMedium,
                color = if (place == null) MaterialTheme.colorScheme.outline
                else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (place != null && place.address.isNotBlank()) {
                Text(
                    text = place.address,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.outline,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/**
 * 地点搜索界面：顶部输入框，下方实时联想结果列表，点击列表项确认选择。
 * 体验与真实地图 App 一致。
 */
@Composable
private fun PlaceSearchScreen(
    title: String,
    onBack: () -> Unit,
    onPick: (Place) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val strings = LocalAppStrings.current
    var keyword by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Place>>(emptyList()) }

    // 输入防抖：停止输入 300ms 后再发起搜索
    LaunchedEffect(keyword) {
        if (keyword.isBlank()) {
            results = emptyList()
            return@LaunchedEffect
        }
        delay(300)
        searchPlaces(context, keyword) { list -> results = list }
    }

    Column(modifier = modifier.fillMaxSize()) {
        // 顶部标题栏 + 返回
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            TextButton(
                onClick = onBack,
                modifier = Modifier.align(Alignment.CenterStart),
            ) {
                Text("← ${strings.back}")
            }
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.align(Alignment.Center),
            )
        }

        OutlinedTextField(
            value = keyword,
            onValueChange = { keyword = it },
            label = { Text(strings.searchHint) },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        )

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(results) { place ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(place) }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Column {
                        Text(
                            text = place.name,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        if (place.address.isNotBlank()) {
                            Text(
                                text = place.address,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.outline,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
                HorizontalDivider()
            }
        }
    }
}
