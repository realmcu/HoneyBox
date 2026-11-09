package com.example.map1

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID

/** GATT session for RTL8773G/E — HoneyProtocol 2.2 "BLE HMIS private service":
 *  service 484D4953-0000-1000-8000-00805F9B34FB, write 0xFFC1, notify 0xFFC2. */
object VehicleBleManager {
    private const val TAG = "VehicleBleManager"

    /** HoneyProtocol 2.2.1 HMIS service UUID (full 128-bit form). */
    private const val HMIS_SERVICE_UUID = "484D4953-0000-1000-8000-00805F9B34FB"

    sealed interface State {
        data object Idle : State
        data class Connecting(val config: VehicleQrProtocol.BleConfig) : State
        data class Connected(val config: VehicleQrProtocol.BleConfig) : State
        data class NaviReady(val config: VehicleQrProtocol.BleConfig) : State
        data class Disconnected(val config: VehicleQrProtocol.BleConfig) : State
        data class Error(val message: String) : State
    }

    private val mutableState = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = mutableState

    private var gatt: BluetoothGatt? = null
    @Volatile private var generation = 0L

    // HoneyProtocol HMIS characteristics
    @Volatile var naviCtrlTx: BluetoothGattCharacteristic? = null  // 0xFFC1 write
    @Volatile var naviCtrlRx: BluetoothGattCharacteristic? = null  // 0xFFC2 notify
    @Volatile var naviRead: BluetoothGattCharacteristic? = null     // 0xFFC3 read (status only)

    val isNaviReady get() = naviCtrlTx != null && naviCtrlRx != null

    /** 0xFFC2 notify forwarder. Set by [NaviBleFrameSender] when projection starts. */
    @Volatile var onNaviNotify: ((String, ByteArray) -> Unit)? = null

    // ── GATT operation serializer ──────────────────────────────────────────────
    /**
     * Mutex that serializes all GATT operations requiring a callback (MTU request, descriptor
     * writes, WRITE_WITH_RESPONSE). Held from issuing the call until the callback fires.
     * WRITE_NO_RESPONSE acquires the mutex only during characteristic-value assignment + the
     * writeCharacteristic() call itself, then releases immediately (no callback expected).
     */
    private val gattMutex = Mutex()

    /** Completion slot for the single in-flight serialized GATT op. */
    @Volatile private var pendingOp: CompletableDeferred<Boolean>? = null

    /** Negotiated ATT MTU; updated in onMtuChanged. Default = 23 (BLE spec minimum). */
    @Volatile var negotiatedMtu: Int = 23
        private set

    /** Maximum bytes that fit in one ATT write PDU: MTU − 3 overhead bytes. */
    val attPayload: Int get() = (negotiatedMtu - 3).coerceAtLeast(1)

    /** Scope for GATT setup coroutines (MTU + CCCD enable) launched from GATT callbacks. */
    private val gattScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── Connection ─────────────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    @Synchronized
    fun connect(context: Context, config: VehicleQrProtocol.BleConfig) {
        disconnect()
        val adapter = context.applicationContext
            .getSystemService(BluetoothManager::class.java)
            ?.adapter
        if (adapter == null) {
            mutableState.value = State.Error("此设备不支持蓝牙")
            return
        }
        if (!adapter.isEnabled) {
            mutableState.value = State.Error("蓝牙未开启，请开启后重试")
            return
        }
        val device = try {
            adapter.getRemoteDevice(config.address)
        } catch (_: IllegalArgumentException) {
            mutableState.value = State.Error("二维码中的蓝牙地址无效")
            return
        }
        val currentGeneration = ++generation
        negotiatedMtu = 23  // reset for new connection
        mutableState.value = State.Connecting(config)

        val callback = object : BluetoothGattCallback() {

            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                synchronized(this@VehicleBleManager) {
                    if (generation != currentGeneration) { gatt.close(); return }
                    when {
                        status == BluetoothGatt.GATT_SUCCESS &&
                            newState == BluetoothProfile.STATE_CONNECTED -> {
                            this@VehicleBleManager.gatt = gatt
                            mutableState.value = State.Connected(config)
                            requestHighThroughput(gatt)
                            if (!gatt.discoverServices()) {
                                mutableState.value = State.Error("已连接，但无法发现 GATT 服务")
                            }
                        }
                        newState == BluetoothProfile.STATE_DISCONNECTED -> {
                            this@VehicleBleManager.gatt = null
                            clearChars()
                            gatt.close()
                            mutableState.value = if (status == BluetoothGatt.GATT_SUCCESS)
                                State.Disconnected(config)
                            else
                                State.Error("BLE 连接失败，GATT 状态：$status")
                        }
                    }
                }
            }

            @SuppressLint("MissingPermission")
            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) return
                synchronized(this@VehicleBleManager) {
                    if (generation != currentGeneration) return
                    discoverNaviChars(gatt)
                    if (isNaviReady) {
                        Log.i(TAG, "Navi chars found (FFD1-FFD4); starting MTU + CCCD setup")
                        // NaviReady is published only AFTER MTU negotiation attempt AND both
                        // FFD2/FFD4 CCCD writes succeed for this generation.
                        // Serialize: ① request MTU, ② enable FFD2 CCCD, ③ enable FFD4 CCCD
                        gattScope.launch {
                            if (generation != currentGeneration) return@launch
                            val mtuOk = doMtuRequest(gatt, 512)
                            Log.i(TAG,
                                "MTU request ok=$mtuOk negotiated=$negotiatedMtu attPayload=$attPayload")
                            if (!mtuOk) {
                                // MTU failure is non-fatal: negotiatedMtu stays at 23 (reset in
                                // connect()), which is a safe baseline; continue with CCCDs.
                                Log.w(TAG,
                                    "MTU negotiation failed; continuing with fallback MTU=$negotiatedMtu")
                            }
                            if (generation != currentGeneration) return@launch
                            val cccdOk = enableNaviNotifiesSeq(gatt, currentGeneration)
                            if (generation != currentGeneration) return@launch
                            if (cccdOk) {
                                Log.i(TAG, "NaviReady: MTU=$negotiatedMtu CCCDs enabled successfully")
                                mutableState.value = State.NaviReady(config)
                            } else {
                                Log.e(TAG, "CCCD enable failed; navi projection unavailable")
                                mutableState.value =
                                    State.Error("无法启用 BLE 通知，投影功能无法启动")
                            }
                        }
                    }
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                negotiatedMtu = mtu
                Log.i(TAG, "onMtuChanged mtu=$mtu attPayload=${mtu - 3} status=$status")
                pendingOp?.let { op ->
                    pendingOp = null
                    op.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
            }

            override fun onPhyUpdate(
                gatt: BluetoothGatt,
                txPhy: Int,
                rxPhy: Int,
                status: Int,
            ) {
                Log.i(TAG, "onPhyUpdate tx=$txPhy rx=$rxPhy status=$status")
            }

            override fun onPhyRead(
                gatt: BluetoothGatt,
                txPhy: Int,
                rxPhy: Int,
                status: Int,
            ) {
                Log.i(TAG, "onPhyRead tx=$txPhy rx=$rxPhy status=$status")
            }

            override fun onDescriptorWrite(
                gatt: BluetoothGatt,
                descriptor: BluetoothGattDescriptor,
                status: Int,
            ) {
                val charUuid = descriptor.characteristic.uuid.toString().uppercase().takeLast(8)
                Log.d(TAG, "onDescriptorWrite char=$charUuid status=$status")
                pendingOp?.let { op ->
                    pendingOp = null
                    op.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                // Write Command (no response) still reports here once the PDU has
                // left the controller: that is the real "ready for the next write"
                // edge, and it replaces sleep-polling on a busy stack.
                writeSignal.trySend(status)
                pendingOp?.let { op ->
                    pendingOp = null
                    op.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
            }

            // ── Notify: handle both pre-API-33 (deprecated) and API-33+ signatures ──

            @Deprecated("Deprecated in Java")
            @Suppress("DEPRECATION")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    val value = characteristic.value ?: return
                    onNaviNotify?.invoke(characteristic.uuid.toString().uppercase(), value)
                }
                // On API 33+, the override below is called instead; this one is skipped.
            }

            @RequiresApi(Build.VERSION_CODES.TIRAMISU)
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                onNaviNotify?.invoke(characteristic.uuid.toString().uppercase(), value)
            }
        }

        try {
            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context.applicationContext, false, callback,
                    BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context.applicationContext, false, callback)
            }
            if (gatt == null) mutableState.value = State.Error("无法发起 BLE 连接")
        } catch (_: SecurityException) {
            mutableState.value = State.Error("缺少附近设备权限，无法连接 BLE 仪表")
        } catch (_: RuntimeException) {
            mutableState.value = State.Error("Android 无法发起 BLE 连接")
        }
    }

    // ── Serialized GATT helpers ────────────────────────────────────────────────

    /** Requests [requestedMtu] and suspends until onMtuChanged fires or times out. */
    @SuppressLint("MissingPermission")
    private suspend fun doMtuRequest(gatt: BluetoothGatt, requestedMtu: Int): Boolean {
        return gattMutex.withLock {
            val deferred = CompletableDeferred<Boolean>()
            pendingOp = deferred
            if (!gatt.requestMtu(requestedMtu)) {
                pendingOp = null
                false
            } else {
                deferred.await()
            }
        }
    }

    /** Writes a descriptor and suspends until onDescriptorWrite fires. */
    @SuppressLint("MissingPermission")
    private suspend fun doDescriptorWrite(
        gatt: BluetoothGatt,
        descriptor: BluetoothGattDescriptor,
        value: ByteArray,
    ): Boolean {
        return gattMutex.withLock {
            val deferred = CompletableDeferred<Boolean>()
            pendingOp = deferred
            // API 33+: writeDescriptor(descriptor, value) returns Int status code;
            // 0 == BluetoothStatusCodes.SUCCESS means the write was initiated.
            // Pre-33: set value on the descriptor object then call the no-value overload.
            val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, value) == 0
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = value
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
            if (!started) {
                pendingOp = null
                false
            } else {
                deferred.await()
            }
        }
    }

    /**
     * Enables the CCCD of the HMIS notify characteristic (0xFFC2). HoneyProtocol only needs this
     * single subscription: write and notify are parallel carriers of the same L2 frames.
     */
    @SuppressLint("MissingPermission")
    private suspend fun enableNaviNotifiesSeq(gatt: BluetoothGatt, expectedGen: Long): Boolean {
        val cccdUuid = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
        val char = naviCtrlRx ?: run {
            Log.e(TAG, "enableNaviNotifiesSeq: 0xFFC2 notify characteristic missing")
            return false
        }
        if (generation != expectedGen) return false
        return try {
            gatt.setCharacteristicNotification(char, true)
            val desc = char.getDescriptor(cccdUuid)
            if (desc == null) {
                Log.e(TAG, "CCCD descriptor missing for ${char.uuid}")
                return false
            }
            val ok = doDescriptorWrite(gatt, desc,
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            Log.i(TAG, "CCCD 0xFFC2 enabled=$ok")
            ok
        } catch (e: Exception) {
            Log.e(TAG, "enableNaviNotifiesSeq: ${char.uuid} → $e")
            false
        }
    }

    /** Fires from onCharacteristicWrite: one slot per completed ATT write. */
    private val writeSignal = kotlinx.coroutines.channels.Channel<Int>(
        kotlinx.coroutines.channels.Channel.CONFLATED)

    // ── Public write API (suspend; serialized via gattMutex) ───────────────────

    /**
     * Writes [bytes] to the HMIS write characteristic (0xFFC1), splitting into ATT-sized
     * fragments. HoneyProtocol 2.2 declares 0xFFC1 as "Write / Write No Rsp"; streaming uses
     * Write Command so that several L1 frames can share one connection event. Reliability is the
     * protocol's business (L1 CRC16 + 0x10 CRC32), not ATT's.
     */
    @SuppressLint("MissingPermission")
    suspend fun writeCtrl(bytes: ByteArray): Boolean {
        if (naviCtrlTx == null) {
            Log.w(TAG, "writeCtrl: 0xFFC1 not ready"); return false
        }
        if (bytes.isEmpty()) return true
        val payload = attPayload
        var off = 0
        while (off < bytes.size) {
            val end = minOf(off + payload, bytes.size)
            // Each fragment's value is set fresh - never reuse a stale char.value length.
            if (!writeFragment(bytes.copyOfRange(off, end))) {
                Log.w(TAG, "writeCtrl: fragment off=$off/${bytes.size} failed")
                return false
            }
            off = end
        }
        return true
    }

    /**
     * Sends one ATT Write Command. Android's Java GATT layer keeps a single write in
     * flight, so a rejected call means "wait for the previous onCharacteristicWrite
     * before retrying" -- waiting on that callback instead of sleeping is what keeps
     * the pipeline at one packet per event instead of paying a 2-16 ms backoff tax.
     */
    @SuppressLint("MissingPermission")
    private suspend fun writeFragment(fragment: ByteArray): Boolean {
        val char = naviCtrlTx ?: return false
        var attempt = 0
        while (attempt < 8) {
            val ok = gattMutex.withLock { rawWrite(char, fragment) }
            if (ok) return true
            attempt++
            val signalled = withTimeoutOrNull(30L) {
                writeSignal.receive()
                true
            } ?: false
            if (!signalled) delay(1)
        }
        return false
    }

    @SuppressLint("MissingPermission")
    private fun rawWrite(char: BluetoothGattCharacteristic, fragment: ByteArray): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt?.writeCharacteristic(char, fragment,
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) == 0
        } else {
            @Suppress("DEPRECATION")
            char.value = fragment
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            @Suppress("DEPRECATION")
            gatt?.writeCharacteristic(char) == true
        }
    }

    // ── Misc ───────────────────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    fun requestHighThroughput(gatt: BluetoothGatt? = null) {
        val g = gatt ?: this.gatt ?: return
        try {
            val priorityStarted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
            } else {
                false
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                g.setPreferredPhy(
                    BluetoothDevice.PHY_LE_2M_MASK,
                    BluetoothDevice.PHY_LE_2M_MASK,
                    BluetoothDevice.PHY_OPTION_NO_PREFERRED,
                )
            }

            Log.i(TAG, "requestHighThroughput priorityStarted=$priorityStarted preferPhy=2M")
        } catch (e: Exception) {
            Log.w(TAG, "requestHighThroughput failed", e)
        }
    }

    @SuppressLint("MissingPermission")
    fun requestHighPriority(gatt: BluetoothGatt?) {
        requestHighThroughput(gatt)
    }

    private fun discoverNaviChars(gatt: BluetoothGatt) {
        clearChars()
        for (service in gatt.services) {
            val serviceUuid = service.uuid.toString().uppercase()
            val isHmis = serviceUuid == HMIS_SERVICE_UUID ||
                serviceUuid.startsWith("0000FF") && serviceUuid.contains("484D4953")
            for (char in service.characteristics) {
                val uuid = char.uuid.toString().uppercase()
                // 16-bit UUIDs surface as "0000FFC1-0000-1000-8000-00805F9B34FB".
                val short = uuid.take(8)
                if (short == "0000FFC1" &&
                    (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0) {
                    naviCtrlTx = char
                    val noRsp = (char.properties and
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
                    Log.i(TAG, "found 0xFFC1 (HMIS write) props=0x${char.properties.toString(16)} " +
                        "writeNoRsp=$noRsp in $serviceUuid")
                }
                if (short == "0000FFC2" &&
                    (char.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
                    naviCtrlRx = char
                    Log.i(TAG, "found 0xFFC2 (HMIS notify)")
                }
                if (short == "0000FFC3" &&
                    (char.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) {
                    naviRead = char
                    Log.i(TAG, "found 0xFFC3 (HMIS read)")
                }
            }
        }
        if (naviCtrlTx != null && naviCtrlRx != null) {
            Log.i(TAG, "HoneyProtocol L0 ready: service=$HMIS_SERVICE_UUID write=FFC1 notify=FFC2")
        }
    }

    private fun clearChars() {
        naviCtrlTx = null; naviCtrlRx = null; naviRead = null
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun disconnect() {
        generation++
        // Cancel any in-flight serialized op so waiting coroutines unblock immediately.
        pendingOp?.cancel()
        pendingOp = null
        val oldGatt = gatt
        gatt = null
        clearChars()
        if (oldGatt != null) {
            try { oldGatt.disconnect() } catch (_: RuntimeException) {}
            oldGatt.close()
        }
        mutableState.value = State.Idle
    }
}
