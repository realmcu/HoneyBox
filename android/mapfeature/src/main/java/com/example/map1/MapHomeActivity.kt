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
        MapSdkInitializer.initialize(applicationContext)
        enableEdgeToEdge()
        setContent {
            Map1Theme {
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

/** 常用投屏分辨率预设（宽 to 高，像素）。 */
private val RESOLUTION_PRESETS = listOf(
    400 to 480,
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
    var pendingVehicleConfig by remember { mutableStateOf<VehicleQrProtocol.Config?>(null) }
    var pendingBleConfig by remember { mutableStateOf<VehicleQrProtocol.BleConfig?>(null) }
    var scanError by remember { mutableStateOf<String?>(null) }
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
            is VehicleQrProtocol.Result.Failure -> scanError = "${result.message}。当前配置未更改，也未发起连接。"
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let(::handleScanResult)
    }
    fun openScanner() {
        scanLauncher.launch(
            ScanOptions().apply {
                setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                setPrompt("扫描车辆二维码")
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
        else scope.launch { snackbarHostState.showSnackbar("相机权限被拒绝，无法扫一扫。请在系统设置中允许相机权限。") }
    }
    val blePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val config = pendingBleConfig
        if (config != null && grants.values.all { it }) {
            pendingBleConfig = null
            VehicleBleManager.connect(context, config)
        } else if (config != null) {
            scope.launch { snackbarHostState.showSnackbar("附近设备权限被拒绝，无法连接 BLE 仪表。") }
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
            scope.launch { snackbarHostState.showSnackbar("Wi-Fi 权限被拒绝，未连接车辆。请在系统设置中授权后重试。") }
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
            scope.launch { snackbarHostState.showSnackbar("action 不含 0x200：仅填入车辆端点，不连接 Wi-Fi") }
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            pendingVehicleConfig = null
            scanError = "Android 10 以下不支持安全的自动车辆 Wi-Fi 选择；接收端已填入，请手动连接车辆 Wi-Fi。"
            return
        }
        val wifiManager = context.applicationContext.getSystemService(WifiManager::class.java)
        if (!wifiManager.isWifiEnabled) {
            runCatching {
                context.startActivity(Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }.recoverCatching {
                context.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            scope.launch { snackbarHostState.showSnackbar("请先打开 Wi-Fi，开启后返回并再次确认连接") }
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

    pendingVehicleConfig?.let { config ->
        BackHandler { pendingVehicleConfig = null }
        AlertDialog(
            onDismissRequest = { pendingVehicleConfig = null },
            title = { Text("确认车辆连接") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("型号：${config.modelId}")
                    Text("SN：${config.serialNumber}")
                    Text("Action：${config.action} (${config.actionHex})")
                    Text("SSID：${config.ssid}")
                    Text("端点：${config.ip}:${config.port}")
                    Text("密码：已隐藏")
                    if (config.connectsVehicleAp) Text("确认后 Android 将显示系统 Wi-Fi 连接批准界面。")
                    if (config.customLocalAp) Text("0x001：本地无互联网 AP；仅车辆 TCP 使用此 Wi-Fi，地图/互联网保留默认移动网络。")
                }
            },
            confirmButton = {
                TextButton(onClick = { confirmVehicleConfig(config) }) { Text("确认") }
            },
            dismissButton = {
                TextButton(onClick = { pendingVehicleConfig = null }) { Text("取消") }
            },
        )
    }
    pendingBleConfig?.let { config ->
        BackHandler { pendingBleConfig = null }
        AlertDialog(
            onDismissRequest = { pendingBleConfig = null },
            title = { Text("已识别 BLE 仪表") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("型号：${config.modelId}")
                    Text("SN：${config.serialNumber}")
                    Text("BLE 地址：${config.address}")
                    Text("APK：${config.apkUrl}", maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text("确认后将建立 BLE GATT 连接；专用传图 Profile 将在协议确定后接入。")
                }
            },
            confirmButton = {
                TextButton(onClick = { confirmBleConfig(config) }) { Text("连接") }
            },
            dismissButton = {
                TextButton(onClick = { pendingBleConfig = null }) { Text("取消") }
            },
        )
    }
    scanError?.let { error ->
        AlertDialog(
            onDismissRequest = { scanError = null },
            title = { Text("车辆二维码无效") },
            text = { Text(error) },
            confirmButton = { TextButton(onClick = { scanError = null }) { Text("返回") } },
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

        val w = castWidth.toIntOrNull() ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_WIDTH
        val h = castHeight.toIntOrNull() ?: com.example.map1.navi.NaviCaptureService.DEFAULT_JPG_HEIGHT
        val fps = tcpFps.toIntOrNull() ?: 5

        // 1) 启动 NaviCaptureService (host="" → 不走 TCP)
        val intent = Intent(context, NaviProjectionActivity::class.java).apply {
            putExtra(NaviActivity.EXTRA_START_LAT, s.latitude)
            putExtra(NaviActivity.EXTRA_START_LNG, s.longitude)
            putExtra(NaviActivity.EXTRA_END_LAT, e.latitude)
            putExtra(NaviActivity.EXTRA_END_LNG, e.longitude)
            putExtra(NaviActivity.EXTRA_SPEED, speed.toIntOrNull() ?: 60)
            putExtra(NaviActivity.EXTRA_TCP_HOST, "")  // 不走 TCP
            putExtra(NaviActivity.EXTRA_TCP_PORT, 0)
            putExtra(NaviActivity.EXTRA_TCP_FPS, fps)
            putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_DPI, virtualDpi.toInt())
            putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_WIDTH, w)
            putExtra(com.example.map1.navi.NaviCaptureService.EXTRA_HEIGHT, h)
        }
        context.startActivity(intent)

        // 2) 创建并启动 BLE 投屏发送器
        val sender = NaviBleFrameSender(
            onStatus = { msg -> scope.launch { snackbarHostState.showSnackbar(msg) } },
        )
        bleSender = sender
        VehicleBleManager.onNaviNotify = { uuid, value -> sender.onNotify(uuid, value) }
        sender.start(w, h, fps, qual = 60)
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
            title = if (target) "选择起点" else "选择终点",
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
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            NaviJpgPreviewWindow(
                aspectRatio = run {
                    val w = castWidth.toIntOrNull()?.takeIf { it > 0 } ?: 400
                    val h = castHeight.toIntOrNull()?.takeIf { it > 0 } ?: 480
                    w.toFloat() / h.toFloat()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { stopVirtualNavi() },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (bleProjecting) "结束 BLE 投屏" else "结束虚拟屏导航")
                }
            }
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
            Text(text = "高德模拟导航", style = MaterialTheme.typography.headlineSmall)
            TextButton(
                onClick = {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                        PackageManager.PERMISSION_GRANTED
                    ) openScanner() else cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                },
            ) {
                Icon(Icons.Outlined.QrCodeScanner, contentDescription = null)
                Text("扫一扫", modifier = Modifier.padding(start = 4.dp))
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
                    "BLE 仪表：正在连接 ${s.config.address}"
                is VehicleBleManager.State.Connected ->
                    "BLE 仪表：已连接 ${s.config.modelId} (${s.config.address})"
                is VehicleBleManager.State.NaviReady ->
                    "BLE 仪表：投屏就绪 ${s.config.modelId}"
                is VehicleBleManager.State.Disconnected ->
                    "BLE 仪表：${s.config.address} 已断开"
                is VehicleBleManager.State.Error -> "BLE 仪表：${s.message}"
                else -> "BLE 仪表：—"
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
                    "车辆 Wi-Fi：等待系统批准并连接 ${s.ssid}"
                is VehicleWifiManager.State.Available -> "车辆 Wi-Fi：已连接 ${s.ssid}"
                is VehicleWifiManager.State.Lost -> "车辆 Wi-Fi：${s.ssid} 已断开"
                is VehicleWifiManager.State.Error -> "车辆 Wi-Fi：${s.message}"
                else -> "车辆 Wi-Fi：—"
            }
            connColor = when (vehicleWifiState) {
                is VehicleWifiManager.State.Error, is VehicleWifiManager.State.Lost ->
                    MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.outline
            }
        } else {
            connText = "连接仪表：未连接（扫描车辆二维码以建立连接）"
            connColor = MaterialTheme.colorScheme.outline
        }
        Text(
            text = connText,
            style = MaterialTheme.typography.bodySmall,
            color = connColor,
        )
        if (bleActive && vehicleBleState !is VehicleBleManager.State.NaviReady) {
            TextButton(onClick = { VehicleBleManager.disconnect() }) { Text("断开 BLE 仪表") }
        } else if (!bleActive && wifiActive) {
            TextButton(onClick = { VehicleWifiManager.disconnect() }) { Text("断开车辆 Wi-Fi") }
        }

        // 起点 / 终点放同一行节省纵向空间
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PlaceSelector(
                label = "起点",
                place = startPlace,
                onClick = { searchingForStart = true },
                modifier = Modifier.weight(1f),
            )
            PlaceSelector(
                label = "终点",
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
                label = { Text("速度 km/h") },
                singleLine = true,
                modifier = Modifier.weight(0.45f)
            )
            OutlinedTextField(
                value = tcpHost,
                onValueChange = { tcpHost = it },
                label = { Text("接收端 IP（留空不发）") },
                singleLine = true,
                modifier = Modifier.weight(0.55f)
            )
        }

        Text(
            text = localIp?.let { "本机局域网 IP：$it" } ?: "未检测到局域网 IP",
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
                Text(if (scanning) "扫描中… $scanProgress%" else "扫描局域网设备")
            }

            if (lanDevices.isNotEmpty()) {
                Box {
                    TextButton(onClick = { deviceMenuExpanded = true }) {
                        Text("选择设备 (${lanDevices.size})")
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
                label = { Text("端口") },
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
            text = "投屏分辨率（宽×高，像素）",
            style = MaterialTheme.typography.bodySmall,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = castWidth,
                onValueChange = { castWidth = it.filter { c -> c.isDigit() } },
                label = { Text("宽") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = castHeight,
                onValueChange = { castHeight = it.filter { c -> c.isDigit() } },
                label = { Text("高") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Box {
                TextButton(onClick = { resolutionMenuExpanded = true }) {
                    Text("预设")
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
            text = "导航 UI 缩放：${virtualDpi.toInt()}（越大 UI 越小，160=原始）",
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
                bleReady -> "BLE 投屏"
                tcpHost.isNotBlank() -> "开始虚拟屏导航 (WiFi)"
                else -> "开始虚拟屏导航 (仅预览)"
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
    val imageBitmap = remember(frame) {
        val jpeg = frame?.jpeg ?: return@remember null
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)?.asImageBitmap()
    }

    Card(modifier = modifier) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant),
            contentAlignment = Alignment.Center,
        ) {
            if (imageBitmap != null) {
                Image(
                    bitmap = imageBitmap,
                    contentDescription = "投屏 JPG 预览",
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(aspectRatio),
                )
            } else {
                Text(
                    text = "投屏预览",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.outline,
                )
            }

            // 左上角叠加流程耗时日志，帮助定位帧率瓶颈。
            Text(
                text = perf.toOverlayText(),
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
                text = place?.name ?: "点击搜索地点",
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
                Text("← 返回")
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
            label = { Text("搜索地点 / 地址") },
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
