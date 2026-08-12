package com.example.map1

import android.annotation.SuppressLint
import android.util.Log
import com.example.map1.navi.NaviFramePreview
import com.example.map1.navi.NaviPerfStats
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.CRC32

/**
 * BLE 导航投屏帧发送器 — 完整的 L1 封装 + L2 协议栈。
 *
 * 通过 VehicleBleManager 的 FFD1-FFD4 特征收发。轮询 NaviFramePreview
 * 获取 JPEG 帧，按 NAIV_PROJ 协议分包、流控发送。
 */
class NaviBleFrameSender(
    private val onStatus: (String) -> Unit = {},
    private val onState: (State) -> Unit = {},
) {
    enum class State { IDLE, OPENING, SENDING, ERROR }

    companion object {
        private const val TAG = "NaviBleSender"
        private const val CMD_NAVI = 0x11
        private const val KEY_OPEN = 0x01
        private const val KEY_ACK = 0x02
        private const val KEY_CLOSE = 0x03
        private const val KEY_ERROR = 0x04
        private const val KEY_FRAME = 0x05
        private const val KEY_CREDIT = 0x06
        private const val KEY_REPORT = 0x07

        private const val L1_CTRL_DATA = 0x00
        private const val L1_CTRL_ACK = 0x10
        private const val L1_CTRL_ERROR = 0x30

        private const val ACK_RESULT_OK = 0x00

        private const val FFD2_UUID = "FFD2"
        private const val FFD4_UUID = "FFD4"

        private const val PROTOCOL_VERSION = 0x02
        private const val FEATURE_RAW_ATT_PACKET = 0x01
        private const val FEATURE_FRAME_CRC32 = 0x02
        private const val REQUIRED_FEATURES = FEATURE_RAW_ATT_PACKET or FEATURE_FRAME_CRC32
        private const val FRAME_HEADER_SIZE = 8
        private const val FRAME_FIRST_HEADER_SIZE = 12
        private const val MIN_PROTOCOL_PACKET = 104
        private const val DEFAULT_MAX_PACKET = 20
        private const val OPEN_TIMEOUT_MS = 5000L
        private const val CREDIT_TIMEOUT_MS = 3000L
        private const val RETX_KEEP_FRAMES = 3
    }

    @Volatile var state = State.IDLE
        private set

    private val running = AtomicBoolean(false)
    private var senderJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Protocol state
    private val frameSeq = AtomicInteger(0)
    private val credits = AtomicInteger(0)
    @Volatile private var maxPacket = DEFAULT_MAX_PACKET
    @Volatile private var waitCredits = false

    // L1 sequence for control channel
    private val l1Seq = AtomicInteger(0)

    private data class RetxFrame(
        val total: Int,
        val crc32: Long,
        val packets: Map<Int, ByteArray>,
        val refundedOffsets: MutableSet<Int> = mutableSetOf(),
    )

    /** Retransmit buffers: frameSeq → immutable frame metadata and offset-indexed JPEG chunks. */
    private val retxBufs = LinkedHashMap<Int, RetxFrame>()

    /** Serializes writes to FFD3 at the L2-packet level so ATT fragments from different
     *  L2 packets (forward and retransmit) never interleave on the wire. */
    private val sendMutex = Mutex()

    // Last sent seq from NaviFramePreview (for dedup)
    private var lastNaviSeq = -1

    // Frame loop params
    private var fps = 5
    private var width = 400
    private var height = 480
    private var quality = 60

    // ═══════════════════════════════════════════════════════════════
    // Public API
    // ═══════════════════════════════════════════════════════════════

    fun start(w: Int, h: Int, fps: Int, qual: Int) {
        if (running.get()) return
        width = w; height = h; this.fps = fps; quality = qual

        running.set(true)
        state = State.IDLE
        frameSeq.set(0); credits.set(0); l1Seq.set(0)
        maxPacket = DEFAULT_MAX_PACKET; waitCredits = false
        lastNaviSeq = -1
        retxBufs.clear()

        onStatus("BLE 投屏初始化中…")

        senderJob = scope.launch {
            if (!handshake()) return@launch
            state = State.SENDING
            frameLoop()
        }
    }

    fun stop() {
        running.set(false)
        senderJob?.cancel()
        scope.launch { sendClose() }
        state = State.IDLE
        onStatus("BLE 投屏已停止")
    }

    // ═══════════════════════════════════════════════════════════════
    // Handshake
    // ═══════════════════════════════════════════════════════════════

    private suspend fun handshake(): Boolean {
        state = State.OPENING
        onStatus("BLE 握手…")

        val requestedMaxPacket = minOf(VehicleBleManager.attPayload, 244)
        if (requestedMaxPacket < MIN_PROTOCOL_PACKET) {
            onStatus("BLE MTU过小，无法启动v2投屏"); state = State.ERROR; return false
        }
        val openL2 = buildNaviOpen(width, height, fps, quality, requestedMaxPacket)
        val openL1 = buildL1Frame(L1_CTRL_DATA, openL2)

        if (!VehicleBleManager.writeCtrl(openL1)) {
            onStatus("FFD1 写入失败"); state = State.ERROR; return false
        }
        Log.i(TAG,
            "→ NAVI_OPEN v2 ${width}x$height @${fps}fps q=$quality% packet=$requestedMaxPacket")

        // Wait for ACK via FFD2 notify.
        // Poll-based wait since notify callback runs on Binder thread.
        val deadline = System.currentTimeMillis() + OPEN_TIMEOUT_MS
        while (running.get() && state == State.OPENING) {
            if (System.currentTimeMillis() > deadline) {
                onStatus("OPEN 握手超时"); state = State.ERROR; return false
            }
            delay(50)
        }
        return state == State.SENDING
    }

    private suspend fun sendClose() {
        val closeL2 = buildNaviClose(0x00)
        val closeL1 = buildL1Frame(L1_CTRL_DATA, closeL2)
        VehicleBleManager.writeCtrl(closeL1)
        Log.i(TAG, "→ NAVI_CLOSE")
    }

    // ═══════════════════════════════════════════════════════════════
    // Frame loop
    // ═══════════════════════════════════════════════════════════════

    private suspend fun frameLoop() {
        val intervalMs = (1000L / fps).coerceAtLeast(50L)
        while (running.get() && state == State.SENDING) {
            val cycleStartMs = System.currentTimeMillis()
            val frame = NaviFramePreview.latestFrame.value
            // Capture the frame reference once; sendFrame awaits full transmission before
            // returning, ensuring one JPEG is fully sent before we check for a newer one.
            if (frame != null && frame.seq != lastNaviSeq) {
                lastNaviSeq = frame.seq
                val protocolSeq = frameSeq.getAndIncrement() and 0xFFFF
                sendFrame(protocolSeq, frame.jpeg)
            }

            val remainingMs = intervalMs - (System.currentTimeMillis() - cycleStartMs)
            if (remainingMs > 0) {
                delay(remainingMs)
            } else {
                yield()
            }
        }
    }

    private suspend fun sendFrame(seq: Int, jpeg: ByteArray) {
        val sendStartNs = System.nanoTime()
        val total = jpeg.size
        val packetLimit = minOf(maxPacket, VehicleBleManager.attPayload)
        val firstCapacity = packetLimit - FRAME_FIRST_HEADER_SIZE
        val normalCapacity = packetLimit - FRAME_HEADER_SIZE
        if (firstCapacity <= 0 || normalCapacity <= 0) {
            Log.e(TAG, "ATT payload too small for v2 packet: limit=$packetLimit")
            state = State.ERROR
            return
        }

        val crc = CRC32().apply { update(jpeg) }.value
        val chunks = linkedMapOf<Int, ByteArray>()
        var buildOff = 0
        while (buildOff < total) {
            val capacity = if (buildOff == 0) firstCapacity else normalCapacity
            val end = (buildOff + capacity).coerceAtMost(total)
            chunks[buildOff] = jpeg.copyOfRange(buildOff, end)
            buildOff = end
        }

        // Publish a complete immutable retransmit map before the terminal packet can trigger a
        // REPORT notification. This closes the race where REPORT arrived just before registration.
        val retx = RetxFrame(total, crc, chunks.toMap())
        synchronized(retxBufs) {
            retxBufs[seq] = retx
            while (retxBufs.size > RETX_KEEP_FRAMES) {
                retxBufs.remove(retxBufs.keys.first())
            }
        }

        var failed = false
        for ((off, chunk) in retx.packets) {
            if (waitCredits) {
                val creditDeadline = System.currentTimeMillis() + CREDIT_TIMEOUT_MS
                while (credits.get() <= 0) {
                    if (!running.get() || System.currentTimeMillis() > creditDeadline) {
                        Log.w(TAG, "credit timeout seq=$seq off=$off/$total")
                        synchronized(retxBufs) { retxBufs.remove(seq) }
                        return
                    }
                    delay(50)
                }
            }

            val packet = buildNaviPacket(seq, off, total, crc, chunk)
            if (!sendMutex.withLock { VehicleBleManager.writeData(packet) }) {
                Log.w(TAG, "FFD3 write failed seq=$seq off=$off/$total")
                failed = true
                break
            }
            credits.decrementAndGet()
        }

        if (failed) {
            synchronized(retxBufs) { retxBufs.remove(seq) }
            Log.w(TAG, "frame seq=$seq send incomplete total=$total")
        } else {
            val sendMs = (System.nanoTime() - sendStartNs) / 1_000_000L
            NaviPerfStats.onSendThroughput(
                if (sendMs > 0) total * 1_000L / sendMs else total.toLong(),
            )
            NaviPerfStats.onSent(seq, sendMs, 0)
            Log.i(TAG,
                "→ FRAME v2 seq=$seq total=${total}B packets=${retx.packets.size} " +
                "packetLimit=$packetLimit sendMs=$sendMs crc32=0x${crc.toString(16)}")
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Inbound notify callback — called from VehicleBleManager GATT thread
    // ═══════════════════════════════════════════════════════════════

    fun onNotify(charUuid: String, value: ByteArray) {
        when {
            charUuid.contains(FFD2_UUID) -> handleCtrlNotify(value)
            charUuid.contains(FFD4_UUID) -> handleDataNotify(value)
        }
    }

    private fun handleCtrlNotify(data: ByteArray) {
        // L1 frame: parse from raw bytes
        var idx = 0
        while (idx < data.size) {
            if (data[idx] != 0xAB.toByte()) { idx++; continue }
            if (idx + 8 > data.size) break
            val ctrl = data[idx + 1].toInt() and 0xFF
            val len = ((data[idx + 2].toInt() and 0xFF) shl 8) or (data[idx + 3].toInt() and 0xFF)
            if (len > 32 * 1024 || idx + 8 + len > data.size) { idx++; continue }

            val payload = data.copyOfRange(idx + 8, idx + 8 + len)

            if (ctrl == L1_CTRL_ACK) {
                // L1 ACK — no action needed for our outgoing data
            } else if (ctrl == L1_CTRL_DATA) {
                // Send L1 ACK back — writeCtrl is now suspend, so launch a coroutine.
                val seq = ((data[idx + 6].toInt() and 0xFF) shl 8) or (data[idx + 7].toInt() and 0xFF)
                val ackFrame = buildL1Frame(L1_CTRL_ACK, ByteArray(0), seq)
                scope.launch { VehicleBleManager.writeCtrl(ackFrame) }

                // Parse L2
                if (payload.size >= 5 && (payload[0].toInt() and 0xFF) == CMD_NAVI) {
                    val key = payload[2].toInt() and 0xFF
                    val vLen = ((payload[3].toInt() and 0xFF) shl 8) or (payload[4].toInt() and 0xFF)
                    val v = payload.copyOfRange(5, (5 + vLen).coerceAtMost(payload.size))
                    when (key) {
                        KEY_ACK -> handleAck(v)
                        KEY_ERROR -> {
                            val code = if (v.isNotEmpty()) v[0].toInt() and 0xFF else 0
                            Log.w(TAG, "← NAVI_ERROR code=0x${Integer.toHexString(code)}")
                        }
                    }
                }
            }
            idx += 8 + len
        }
    }

    private fun handleDataNotify(data: ByteArray) {
        if (data.size < 5 || (data[0].toInt() and 0xFF) != CMD_NAVI) return
        val key = data[2].toInt() and 0xFF
        val vLen = ((data[3].toInt() and 0xFF) shl 8) or (data[4].toInt() and 0xFF)
        val v = data.copyOfRange(5, (5 + vLen).coerceAtMost(data.size))
        when (key) {
            KEY_CREDIT -> {
                if (v.size >= 2) {
                    val n = ((v[0].toInt() and 0xFF) shl 8) or (v[1].toInt() and 0xFF)
                    credits.addAndGet(n)
                    Log.d(TAG, "← CREDIT +$n → ${credits.get()}")
                }
            }
            KEY_REPORT -> {
                if (v.size < 3) return
                val repSeq = ((v[0].toInt() and 0xFF) shl 8) or (v[1].toInt() and 0xFF)
                val gapCount = v[2].toInt() and 0xFF

                val retx = synchronized(retxBufs) { retxBufs[repSeq] } ?: return
                if (gapCount == 0) {
                    synchronized(retxBufs) { retxBufs.remove(repSeq) }
                    return
                }

                val gaps = buildList {
                    for (i in 0 until gapCount) {
                        val base = 3 + i * 6
                        if (base + 6 > v.size) break
                        val start = ((v[base].toInt() and 0xFF) shl 16) or
                            ((v[base + 1].toInt() and 0xFF) shl 8) or
                            (v[base + 2].toInt() and 0xFF)
                        val end = ((v[base + 3].toInt() and 0xFF) shl 16) or
                            ((v[base + 4].toInt() and 0xFF) shl 8) or
                            (v[base + 5].toInt() and 0xFF)
                        add(start until end)
                    }
                }
                val packetsToRetry = retx.packets.filter { (off, chunk) ->
                    gaps.any { gap -> off < gap.last + 1 && off + chunk.size > gap.first }
                }
                val newlyRefunded = synchronized(retx) {
                    val fresh = packetsToRetry.keys.filter { retx.refundedOffsets.add(it) }
                    fresh.size
                }
                if (newlyRefunded > 0) credits.addAndGet(newlyRefunded)

                Log.d(TAG,
                    "← REPORT seq=$repSeq gaps=$gapCount total=${retx.total} refund=$newlyRefunded")
                scope.launch {
                    packetsToRetry.forEach { (boff, chunk) ->
                        val packet = buildNaviPacket(
                            repSeq, boff, retx.total, retx.crc32, chunk)
                        sendMutex.withLock { VehicleBleManager.writeData(packet) }
                    }
                }
            }
        }
    }

    private fun handleAck(v: ByteArray) {
        if (v.isEmpty()) return
        val result = v[0].toInt() and 0xFF
        if (result != ACK_RESULT_OK) {
            onStatus("设备拒绝投屏: result=0x${Integer.toHexString(result)}")
            state = State.ERROR
            return
        }
        if (v.size >= 3) {
            maxPacket = ((v[1].toInt() and 0xFF) or
                ((v[2].toInt() and 0xFF) shl 8)).coerceAtLeast(1)
        }
        val ic = if (v.size >= 5)
            ((v[3].toInt() and 0xFF) or ((v[4].toInt() and 0xFF) shl 8))
        else 0

        waitCredits = ic != 0xFFFF
        credits.set(if (waitCredits) ic else Int.MAX_VALUE / 2)
        state = State.SENDING
        onStatus("BLE 投屏已握手 (packet=$maxPacket, credit=${credits.get()})")
        Log.i(TAG, "← NAVI_ACK v2 OK packet=$maxPacket credit=${credits.get()}")
    }

    // ═══════════════════════════════════════════════════════════════
    // L1 engine
    // ═══════════════════════════════════════════════════════════════

    private fun buildL1Frame(ctrl: Int, payload: ByteArray, seqOverride: Int = -1): ByteArray {
        val seq = if (seqOverride >= 0) seqOverride else l1Seq.getAndIncrement() and 0xFFFF
        val crc = crc16(payload)
        val frame = ByteArray(8 + payload.size)
        frame[0] = 0xAB.toByte()
        frame[1] = ctrl.toByte()
        frame[2] = ((payload.size shr 8) and 0xFF).toByte()
        frame[3] = (payload.size and 0xFF).toByte()
        frame[4] = ((crc shr 8) and 0xFF).toByte()
        frame[5] = (crc and 0xFF).toByte()
        frame[6] = ((seq shr 8) and 0xFF).toByte()
        frame[7] = (seq and 0xFF).toByte()
        System.arraycopy(payload, 0, frame, 8, payload.size)
        return frame
    }

    private fun crc16(data: ByteArray): Int {
        var crc = 0x0000
        for (b in data) {
            crc = crc xor (b.toInt() and 0xFF)
            for (j in 0 until 8) {
                crc = if ((crc and 1) != 0) (crc shr 1) xor 0xA001 else crc shr 1
            }
        }
        return crc and 0xFFFF
    }

    // ═══════════════════════════════════════════════════════════════
    // L2 builders
    // ═══════════════════════════════════════════════════════════════

    private fun buildL2Frame(key: Int, value: ByteArray): ByteArray {
        val out = ByteArray(5 + value.size)
        out[0] = CMD_NAVI.toByte()
        out[1] = 0
        out[2] = key.toByte()
        out[3] = ((value.size shr 8) and 0xFF).toByte()
        out[4] = (value.size and 0xFF).toByte()
        System.arraycopy(value, 0, out, 5, value.size)
        return out
    }

    private fun buildNaviOpen(
        w: Int,
        h: Int,
        fps: Int,
        qual: Int,
        requestedMaxPacket: Int,
    ): ByteArray {
        val v = ByteArray(11)
        v[0] = (w and 0xFF).toByte(); v[1] = ((w shr 8) and 0xFF).toByte()
        v[2] = (h and 0xFF).toByte(); v[3] = ((h shr 8) and 0xFF).toByte()
        v[4] = fps.toByte(); v[5] = qual.toByte()
        v[6] = 1 // flags: flow_ctrl_enable
        v[7] = PROTOCOL_VERSION.toByte()
        v[8] = REQUIRED_FEATURES.toByte()
        v[9] = (requestedMaxPacket and 0xFF).toByte()
        v[10] = ((requestedMaxPacket shr 8) and 0xFF).toByte()
        return buildL2Frame(KEY_OPEN, v)
    }

    private fun buildNaviClose(reason: Int): ByteArray =
        buildL2Frame(KEY_CLOSE, byteArrayOf(reason.toByte()))

    private fun buildNaviPacket(
        seq: Int,
        off: Int,
        total: Int,
        frameCrc32: Long,
        data: ByteArray,
    ): ByteArray {
        val headerSize = if (off == 0) FRAME_FIRST_HEADER_SIZE else FRAME_HEADER_SIZE
        val out = ByteArray(headerSize + data.size)
        out[0] = ((seq shr 8) and 0xFF).toByte(); out[1] = (seq and 0xFF).toByte()
        out[2] = ((off shr 16) and 0xFF).toByte(); out[3] = ((off shr 8) and 0xFF).toByte()
        out[4] = (off and 0xFF).toByte()
        out[5] = ((total shr 16) and 0xFF).toByte(); out[6] = ((total shr 8) and 0xFF).toByte()
        out[7] = (total and 0xFF).toByte()
        if (off == 0) {
            out[8] = ((frameCrc32 shr 24) and 0xFF).toByte()
            out[9] = ((frameCrc32 shr 16) and 0xFF).toByte()
            out[10] = ((frameCrc32 shr 8) and 0xFF).toByte()
            out[11] = (frameCrc32 and 0xFF).toByte()
        }
        System.arraycopy(data, 0, out, headerSize, data.size)
        return out
    }
}
