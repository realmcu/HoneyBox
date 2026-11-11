package com.example.map1

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.map1.ui.theme.Map1Theme

/**
 * Manual device discovery for vehicles that cannot show a QR code.
 *
 * Mirrors the eBadge / Watch scan pages: open -> list of admissible devices ->
 * tap to connect. Discovery is advertisement-filtered by [VehicleAdvFilter];
 * connecting reuses [VehicleBleManager], so the dashboard's connection banner
 * updates exactly like the QR path does.
 */
class AddBleDeviceActivity : ComponentActivity() {

    private lateinit var scanner: VehicleDeviceScanner

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scanner = VehicleDeviceScanner(applicationContext)
        enableEdgeToEdge()
        setContent {
            Map1Theme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    AddDeviceScreen(
                        scanner = scanner,
                        onClose = { finish() },
                        modifier = Modifier
                            .padding(innerPadding)
                            .consumeWindowInsets(innerPadding),
                    )
                }
            }
        }
    }

    override fun onStop() {
        // Keep the radio quiet while the page is not visible; the page restarts
        // scanning from its own refresh action / re-entry.
        scanner.stop()
        super.onStop()
    }
}

/** One advertisement, merged by MAC. */
internal data class AdvDevice(
    val address: String,
    val name: String,
    val rssi: Int,
    val match: VehicleAdvFilter.Match?,
    val info: VehicleAdvFilter.AdvInfo?,
    val rawAdv: String,
)

/**
 * Thin wrapper over [BluetoothLeScanner] that de-duplicates by MAC and republishes
 * a RSSI-sorted snapshot. All callbacks are delivered on the main thread.
 */
internal class VehicleDeviceScanner(context: Context) {

    private val appContext = context.applicationContext
    private val adapter =
        appContext.getSystemService(BluetoothManager::class.java)?.adapter
    private val handler = Handler(Looper.getMainLooper())
    private val seen = LinkedHashMap<String, AdvDevice>()
    private val publishRunnable = Runnable { publish() }

    private var callback: ScanCallback? = null

    /**
     * Mirrors the "show all" switch. Filtering is done in software as well as via
     * [ScanFilter], because some OEM stacks (ColorOS among them) ignore the
     * filter list and deliver every advertisement to the callback.
     */
    private var includeUnmatched = false

    var onDevices: ((List<AdvDevice>) -> Unit)? = null
    var onScanning: ((Boolean) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    var isScanning: Boolean = false
        private set

    /** Starts (or restarts) scanning. Returns false when scanning cannot start. */
    @SuppressLint("MissingPermission")
    fun start(showAll: Boolean): Boolean {
        stop()
        if (!hasScanPermission()) return false

        val scanner: BluetoothLeScanner = adapter?.bluetoothLeScanner ?: return false
        if (adapter?.isEnabled != true) return false

        synchronized(seen) { seen.clear() }
        includeUnmatched = showAll
        publish()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        val filters = if (showAll) null else VehicleAdvFilter.scanFilters()

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                onAdvertisement(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach(::onAdvertisement)
            }

            override fun onScanFailed(errorCode: Int) {
                handler.post {
                    setScanning(false)
                    onError?.invoke("扫描启动失败（错误码 $errorCode），请关闭蓝牙后重试。")
                }
            }
        }

        return try {
            scanner.startScan(filters, settings, scanCallback)
            callback = scanCallback
            setScanning(true)
            true
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        val active = callback
        callback = null
        if (active != null) {
            try {
                adapter?.bluetoothLeScanner?.stopScan(active)
            } catch (_: SecurityException) {
                // Permission revoked mid-scan: the stack already dropped it.
            }
        }
        handler.removeCallbacks(publishRunnable)
        setScanning(false)
    }

    @SuppressLint("MissingPermission")
    private fun onAdvertisement(result: ScanResult) {
        val record = result.scanRecord
        val match = VehicleAdvFilter.match(record)
        // Software half of the filter: never trust the framework's filter list alone.
        if (!includeUnmatched && match == null) return

        // platformName needs BLUETOOTH_CONNECT; the advertised name is usually
        // enough, so a denial here only costs the fallback label.
        val platformName = runCatching { result.device.name.orEmpty() }.getOrDefault("")
        val name = record?.deviceName?.trim().orEmpty().ifEmpty { platformName.trim() }

        val device = AdvDevice(
            address = result.device.address,
            name = name,
            rssi = result.rssi,
            match = match,
            info = VehicleAdvFilter.parseInfo(record),
            rawAdv = VehicleAdvFilter.describe(record),
        )

        synchronized(seen) {
            val previous = seen[device.address]
            // Merge instead of replace: the name arrives with SCAN_RSP, so an
            // ADV-only packet must never blank it out again.
            seen[device.address] = if (previous == null) {
                device
            } else {
                device.copy(
                    name = device.name.ifBlank { previous.name },
                    match = device.match ?: previous.match,
                    info = device.info ?: previous.info,
                )
            }
        }
        // Coalesce bursts: several advertisements can land in the same frame.
        handler.removeCallbacks(publishRunnable)
        handler.post(publishRunnable)
    }

    private fun publish() {
        val snapshot = synchronized(seen) {
            seen.values.sortedByDescending { it.rssi }
        }
        onDevices?.invoke(snapshot)
    }

    private fun setScanning(value: Boolean) {
        if (isScanning == value) return
        isScanning = value
        onScanning?.invoke(value)
    }

    private fun hasScanPermission(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return permissions.all {
            ContextCompat.checkSelfPermission(appContext, it) == PackageManager.PERMISSION_GRANTED
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddDeviceScreen(
    scanner: VehicleDeviceScanner,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var devices by remember { mutableStateOf<List<AdvDevice>>(emptyList()) }
    var scanning by remember { mutableStateOf(false) }
    var showAll by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var scanNonce by remember { mutableStateOf(0) }
    var connecting by remember { mutableStateOf<String?>(null) }

    DisposableEffect(scanner) {
        scanner.onDevices = { devices = it }
        scanner.onScanning = { scanning = it }
        scanner.onError = { error = it }
        onDispose {
            scanner.onDevices = null
            scanner.onScanning = null
            scanner.onError = null
            scanner.stop()
        }
    }

    LaunchedEffect(showAll, scanNonce) {
        error = null
        connecting = null
        if (!scanner.start(showAll)) {
            error = "无法开始扫描。请确认蓝牙已开启，且已授予「附近的设备」权限。"
        }
    }

    // The activity stops the radio in onStop(); restart it when the page becomes
    // visible again so the list does not sit there frozen after a trip to settings.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) scanNonce++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun connect(device: AdvDevice) {
        if (connecting != null) return
        connecting = device.address
        scanner.stop()
        // Only the MAC is needed to connect; the QR path gets model/SN from the
        // QR payload, so reuse the advertised name — or the payload model code
        // when SCAN_RSP has not arrived yet — as the display model.
        VehicleBleManager.connect(
            context.applicationContext,
            VehicleQrProtocol.BleConfig(
                modelId = device.name.ifBlank {
                    device.info?.modelName ?: "HMIS 仪表"
                },
                serialNumber = "",
                address = device.address,
                apkUrl = "",
            ),
        )
        onClose()
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "返回",
                        )
                    }
                },
                title = { Text("添加设备") },
                actions = {
                    Text(
                        text = "显示全部",
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Switch(
                        checked = showAll,
                        onCheckedChange = { showAll = it },
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                    IconButton(
                        onClick = { scanNonce++ },
                        enabled = connecting == null,
                    ) {
                        Icon(Icons.Outlined.Refresh, contentDescription = "重新扫描")
                    }
                },
            )
        },
    ) { contentPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(contentPadding),
        ) {
            RuleHint(showAll = showAll)

            val failure = error
            when {
                failure != null -> ErrorState(
                    message = failure,
                    onRetry = {
                        scanNonce++
                    },
                )

                devices.isEmpty() -> EmptyState(scanning = scanning, showAll = showAll)

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(devices, key = { it.address }) { device ->
                        DeviceRow(
                            device = device,
                            connecting = connecting == device.address,
                            showRawAdv = showAll,
                            onClick = { connect(device) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun RuleHint(showAll: Boolean) {
    val colorScheme = MaterialTheme.colorScheme
    Text(
        text = if (showAll) {
            "已显示全部广播设备。仅用于排查：不符合过滤规则的设备也会出现在列表里。"
        } else {
            "仅显示广播中含 HMIS 服务（484D4953…）或 Realtek 厂商 ID（0x005D）的设备。"
        },
        style = MaterialTheme.typography.bodySmall,
        color = if (showAll) colorScheme.error else colorScheme.outline,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun DeviceRow(
    device: AdvDevice,
    connecting: Boolean,
    showRawAdv: Boolean,
    onClick: () -> Unit,
) {
    val colorScheme = MaterialTheme.colorScheme
    // The name comes from SCAN_RSP, so it lands on the second callback. Until
    // then (and on passive scanners) fall back to the payload model + MAC tail.
    val hasName = device.name.isNotBlank()
    val title = if (hasName) device.name else fallbackTitle(device)
    val detail = payloadDetail(device, includeModel = hasName)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !connecting, onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = colorScheme.surface),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "${device.rssi} dBm",
                        style = MaterialTheme.typography.labelSmall,
                        color = colorScheme.outline,
                    )
                }
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = device.address,
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                )
                Spacer(modifier = Modifier.height(6.dp))
                MatchBadge(match = device.match)
                // With "show all" on, the raw digest always gets its own line, so
                // don't print it twice when there is no decodable payload.
                val primaryDetail = detail ?: if (showRawAdv) null else device.rawAdv
                if (primaryDetail != null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = primaryDetail,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (detail != null) colorScheme.secondary else colorScheme.outline,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (showRawAdv) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = device.rawAdv,
                        style = MaterialTheme.typography.labelSmall,
                        color = colorScheme.outline,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(modifier = Modifier.width(12.dp))
            if (connecting) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                )
            } else {
                Button(onClick = onClick) { Text("连接") }
            }
        }
    }
}

/** "RTL8773G · 8A2F" — readable stand-in until SCAN_RSP delivers the real name. */
private fun fallbackTitle(device: AdvDevice): String {
    val model = device.info?.modelName
        ?: if (device.match != null) "HMIS 仪表" else "未命名设备"
    val tail = device.address.replace(":", "").takeLast(4).uppercase()
    return "$model · $tail"
}

/** Human-readable payload line; null when the device carries no decodable payload. */
private fun payloadDetail(device: AdvDevice, includeModel: Boolean): String? {
    val info = device.info ?: return null
    val parts = mutableListOf<String>()
    if (includeModel) info.modelName?.let { parts += it }
    info.batteryPercent?.let { parts += "电量 $it%" }
    if (info.charging) parts += "充电中"
    if (info.naviReady) parts += "可投屏"
    if (info.bound) parts += "已绑定"
    return parts.joinToString(" · ").ifBlank { null }
}

@Composable
private fun MatchBadge(match: VehicleAdvFilter.Match?) {
    val colorScheme = MaterialTheme.colorScheme
    val color: Color = if (match != null) colorScheme.primary else colorScheme.outline
    Text(
        text = match?.let { "匹配：${it.label}" } ?: "未匹配过滤规则",
        style = MaterialTheme.typography.labelSmall,
        color = color,
        modifier = Modifier
            .background(
                color = color.copy(alpha = 0.12f),
                shape = RoundedCornerShape(6.dp),
            )
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}

@Composable
private fun EmptyState(scanning: Boolean, showAll: Boolean) {
    val colorScheme = MaterialTheme.colorScheme
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (scanning) {
            CircularProgressIndicator()
            Spacer(modifier = Modifier.height(20.dp))
            Text("正在搜索附近的仪表…", style = MaterialTheme.typography.bodyLarge)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = if (showAll) "可打开「显示全部」核对广播内容" else "请让仪表上电并靠近手机",
                style = MaterialTheme.typography.bodySmall,
                color = colorScheme.outline,
            )
        } else {
            Text("未在扫描", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "点右上角刷新重新开始扫描",
                style = MaterialTheme.typography.bodySmall,
                color = colorScheme.outline,
            )
        }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.error,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(20.dp))
        TextButton(onClick = onRetry) { Text("重新扫描") }
    }
}
