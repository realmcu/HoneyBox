package com.example.map1

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Bundle
import androidx.activity.ComponentActivity
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Map1Theme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    NaviHomeScreen(
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
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

    // 启动时仅查询本机 IP 作网段提示，不预填接收端地址
    LaunchedEffect(Unit) {
        localIp = withContext(Dispatchers.IO) { NetworkUtils.getLocalIpv4() }
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
        }
        context.startActivity(intent)
    }

    // 结束虚拟屏后台导航（运行状态由 Service 销毁时回置，无需在此手动置位）
    fun stopVirtualNavi() {
        context.startService(
            com.example.map1.navi.NaviCaptureService.stopIntent(context)
        )
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
    if (virtualNaviRunning) {
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            NaviJpgPreviewWindow(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            )
            Button(
                onClick = { stopVirtualNavi() },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("结束虚拟屏导航")
            }
        }
        return
    }

    // 主界面：起点 / 终点选择 + 开始导航（可滚动，防止内容超出屏幕）
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(text = "高德模拟导航", style = MaterialTheme.typography.headlineSmall)

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

        // UI 缩放滑块：通过改变虚拟屏渲染分辨率来真正改变导航 UI 控件尺寸。
        // 值越大 → 渲染画布越大 → 缩放回 400×480 后 UI/字越小。160=原始大小。
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

        // 未开始导航：显示「开始虚拟屏导航」。开始后本分支会被上方全屏导航界面取代。
        Button(
            onClick = {
                val fineGranted = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                if (fineGranted) {
                    launchVirtualNavi()
                } else {
                    pendingNaviLaunch = ::launchVirtualNavi
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
            Text("开始虚拟屏导航")
        }
    }
}

/** 主界面上的小窗口：同步显示虚拟屏服务最新生成的投屏 JPG，并在左上角叠加流程耗时/帧率日志。 */
@Composable
private fun NaviJpgPreviewWindow(modifier: Modifier = Modifier) {
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
                        .aspectRatio(400f / 480f),
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