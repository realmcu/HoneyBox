package com.example.map1

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
 * Dashboard projection sender for HoneyProtocol.
 *
 * Transport: L1 (0xAB / big-endian / CRC-16-ARC over payload only) carried by the
 * HMIS private service (0xFFC1 write, 0xFFC2 notify).
 * Application: 0x10 file transfer, one JPEG frame = one file session:
 *
 *   BEGIN_REQ(total, chunk) -> BEGIN_RSP(status, chunk)
 *   DATA(seq, bytes) x N          (streaming: ACK request bit = 0)
 *   END_REQ(crc32)          -> END_RSP(status, error_code)
 *
 * Streaming mode: data frames never request an L1 ACK, so a whole frame is one
 * uninterrupted burst. Loss is detected by the device's DATA sequence check
 * (XFER_ABORT) or by the CRC32 in END_REQ, and costs exactly one frame.
 */
class NaviBleFrameSender(
    private val onStatus: (String) -> Unit = {},
    private val onState: (State) -> Unit = {},
) {
    enum class State { IDLE, OPENING, SENDING, ERROR }

    companion object {
        private const val TAG = "NaviBleSender"

        // HoneyProtocol 3.12 file transfer
        private const val CMD_XFER = 0x10
        private const val KEY_BEGIN_REQ = 0x01
        private const val KEY_BEGIN_RSP = 0x02
        private const val KEY_DATA = 0x03
        private const val KEY_END_REQ = 0x05
        private const val KEY_END_RSP = 0x06
        private const val KEY_ABORT = 0x07

        private const val FILE_TYPE_IMAGE = 0x01

        // L1 header bits (2.3.2)
        private const val L1_SYNC = 0xAB
        private const val L1_HDR = 8
        private const val L1_ACK_REQ = 0x40
        private const val L1_BIT_ERR = 0x20
        private const val L1_BIT_ACK = 0x10
        private const val L1_CTRL_ACK = 0x10

        // Overhead of one DATA L1 frame: L1(8) + L2 header(5) + seq(2)
        private const val DATA_OVERHEAD = L1_HDR + 5 + 2

        private const val CHUNK_REQUEST = 512
        private const val BEGIN_TIMEOUT_MS = 3000L

        /* Sliding window: keep up to WINDOW L1 frames unacknowledged and never
         * block per packet. An ACK is only *requested* every WINDOW-th frame; the
         * sender stalls only when the window is exhausted, so the pipeline stays
         * full while the device still gets a bounded backlog. */
        private const val WINDOW = 256
        private const val WINDOW_TIMEOUT_MS = 150L
    }

    @Volatile var state = State.IDLE
        private set

    private val running = AtomicBoolean(false)
    private var senderJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    /** L1 sequence: one counter for the whole connection, wraps at 16 bits. */
    private val l1Seq = AtomicInteger(0)

    /** Serializes L1 frames so two frames never interleave on the wire. */
    private val sendMutex = Mutex()

    /** Single-slot response mailbox written by the GATT thread. */
    private val rspLock = Any()
    private var rspKey = -1
    private var rspValue: ByteArray? = null

    /** L1 seq of the newest success ACK seen on 0xFFC2. */
    @Volatile private var lastAckSeq = -1
    /** Reason of the last device XFER_ABORT for this session, -1 when none. */
    @Volatile private var abortReason = -1

    private var agreedChunk = 0
    private var lastNaviSeq = -1

    /** Async session state: the BEGIN/END responses no longer gate the next frame. */
    @Volatile private var beginRejected = false
    @Volatile private var frameStartNs = 0L
    @Volatile private var frameBytes = 0
    @Volatile private var frameIdx = 0

    private var fps = 5
    private var width = 400
    private var height = 480
    private var quality = 45

    // ═══════════════════════════════════════════════════════════════
    // Public API
    // ═══════════════════════════════════════════════════════════════

    fun start(w: Int, h: Int, fps: Int, qual: Int) {
        if (running.get()) return
        width = w; height = h; this.fps = fps; quality = qual

        running.set(true)
        state = State.IDLE
        l1Seq.set(0)
        agreedChunk = 0
        lastNaviSeq = -1

        onStatus("BLE 投屏初始化中…")

        if (VehicleBleManager.attPayload < DATA_OVERHEAD + 1) {
            onStatus("BLE MTU 过小，无法启动投屏")
            state = State.ERROR
            onState(state)
            running.set(false)
            return
        }

        state = State.SENDING
        onState(state)
        onStatus("BLE 投屏已启动 (0x10 流式)")
        senderJob = scope.launch { frameLoop() }
    }

    fun stop() {
        if (!running.getAndSet(false)) return
        senderJob?.cancel()
        senderJob = null
        scope.launch {
            sendMutex.withLock { sendAbort(0x00) }
        }
        state = State.IDLE
        onState(state)
        onStatus("BLE 投屏已停止")
    }

    // ═══════════════════════════════════════════════════════════════
    // Frame loop
    // ═══════════════════════════════════════════════════════════════

    private suspend fun frameLoop() {
        val intervalMs = (1000L / fps).coerceAtLeast(50L)
        while (running.get() && state == State.SENDING) {
            val cycleStartMs = System.currentTimeMillis()
            val frame = NaviFramePreview.latestFrame.value
            if (frame != null && frame.seq != lastNaviSeq) {
                lastNaviSeq = frame.seq
                sendFrame(frame.jpeg)
            }

            val remainingMs = intervalMs - (System.currentTimeMillis() - cycleStartMs)
            if (remainingMs > 0) {
                delay(remainingMs)
            } else {
                yield()
            }
        }
    }

    /** Sends one JPEG as one 0x10 file session. Returns true when the device committed it. */
    private suspend fun sendFrame(jpeg: ByteArray): Boolean {
        val sendStartNs = System.nanoTime()
        val total = jpeg.size
        if (total == 0) return false

        return sendMutex.withLock {
            val attMax = VehicleBleManager.attPayload
            val chunkMax = (attMax - DATA_OVERHEAD).coerceAtMost(2048)
            if (chunkMax <= 0) return@withLock false

            // ── BEGIN ──────────────────────────────────────────────────────
            clearRsp()
            val beginValue = ByteArray(8)
            beginValue[0] = FILE_TYPE_IMAGE.toByte()
            putU32(beginValue, 1, total.toLong())
            putU16(beginValue, 5, CHUNK_REQUEST.coerceAtMost(chunkMax))
            beginValue[7] = 0 // no filename

            beginRejected = false
            if (!writeL1Data(buildL2(KEY_BEGIN_REQ, beginValue))) {
                Log.w(TAG, "BEGIN write failed total=$total")
                return@withLock false
            }
            // The chunk size only depends on the negotiated MTU, so it is learned
            // once and reused: waiting for BEGIN_RSP on every frame would put a
            // full round trip (15-30 ms) on the critical path for no information.
            if (agreedChunk == 0) {
                val beginRsp = awaitRsp(KEY_BEGIN_RSP, BEGIN_TIMEOUT_MS)
                if (beginRsp == null || beginRsp.size < 3) {
                    Log.w(TAG, "BEGIN_RSP timeout/missing")
                    onStatus("设备无响应（BEGIN）")
                    return@withLock false
                }
                val status = beginRsp[0].toInt() and 0xFF
                if (status != 0) {
                    Log.w(TAG, "BEGIN_RSP rejected status=$status")
                    onStatus("设备拒绝投屏 status=$status")
                    return@withLock false
                }
                agreedChunk = (((beginRsp[1].toInt() and 0xFF) shl 8) or
                    (beginRsp[2].toInt() and 0xFF)).coerceIn(1, chunkMax)
            }

            // ── DATA: sliding window, ACKs are advisory ────────────────────
            // Each frame is a fresh session: rebase the window on the current L1
            // sequence so the previous frame's unacknowledged debt is not carried in.
            lastAckSeq = l1Seq.get() - 1
            val crc = CRC32().apply { update(jpeg) }.value
            var off = 0
            var seq = 0
            var idx = 0
            while (off < total) {
                if (beginRejected) {
                    Log.w(TAG, "BEGIN_RSP rejected mid-frame, dropping frame $lastNaviSeq")
                    clearRsp()
                    return@withLock false
                }
                if (!awaitWindowRoom()) {
                    if (abortReason >= 0) {
                        Log.w(TAG, "device ABORT reason=$abortReason at chunk=$seq")
                        onStatus("设备中止传输 reason=$abortReason")
                        clearRsp()
                        return@withLock false
                    }
                    // Window stalled (device stopped ACKing): fall through as best
                    // effort -- the device's seq check and the final CRC32 decide.
                    Log.w(TAG, "window stalled at chunk=$seq, continuing unthrottled")
                    resyncWindow()
                }
                val end = (off + agreedChunk).coerceAtMost(total)
                // v2 parity: blast the whole frame, confirm once at the end.
                // A mid-frame ACK round trip costs a full connection event and
                // was the dominant cost at small frame sizes.
                val wantAck = (end == total)
                if (!writeL1Data(buildDataFrame(seq, jpeg, off, end), requestAck = wantAck)) {
                    Log.w(TAG, "DATA write failed seq=$seq off=$off/$total")
                    clearRsp()
                    sendAbort(0x01)
                    return@withLock false
                }
                if (abortReason >= 0) {
                    Log.w(TAG, "device ABORT reason=$abortReason at chunk=$seq")
                    onStatus("设备中止传输 reason=$abortReason")
                    clearRsp()
                    return@withLock false
                }
                off = end
                seq = (seq + 1) and 0xFFFF
                idx++
            }

            // ── END + CRC32 ────────────────────────────────────────────────
            frameStartNs = sendStartNs
            frameBytes = total
            frameIdx = lastNaviSeq
            val endValue = ByteArray(4)
            putU32(endValue, 0, crc)
            if (!writeL1Data(buildL2(KEY_END_REQ, endValue))) {
                Log.w(TAG, "END write failed")
                return@withLock false
            }
            // END_RSP is collected asynchronously (see parseL2): the next frame's
            // BEGIN goes out immediately, so the device's CRC32/commit work overlaps
            // with the following transfer instead of idling the link.
            return@withLock true
        }
    }

    private suspend fun sendAbort(reason: Int) {
        writeL1Data(buildL2(KEY_ABORT, byteArrayOf(reason.toByte())))
        Log.i(TAG, "→ XFER_ABORT reason=$reason")
    }

    // ═══════════════════════════════════════════════════════════════
    // Inbound notify (GATT thread) — parse L1 frames, stash 0x10 replies
    // ═══════════════════════════════════════════════════════════════

    fun onNotify(charUuid: String, value: ByteArray) {
        var idx = 0
        while (idx + L1_HDR <= value.size) {
            if ((value[idx].toInt() and 0xFF) != L1_SYNC) { idx++; continue }
            val ctrl = value[idx + 1].toInt() and 0xFF
            val len = ((value[idx + 2].toInt() and 0xFF) shl 8) or
                (value[idx + 3].toInt() and 0xFF)
            if (idx + L1_HDR + len > value.size) break
            val seq = ((value[idx + 6].toInt() and 0xFF) shl 8) or
                (value[idx + 7].toInt() and 0xFF)

            if ((ctrl and L1_BIT_ACK) != 0) {
                if ((ctrl and L1_BIT_ERR) != 0) {
                    Log.w(TAG, "← L1 NAK seq=$seq")
                } else {
                    lastAckSeq = seq
                }
            } else if ((ctrl and L1_ACK_REQ) != 0) {
                // Device never asks for ACKs on responses today, but honour it.
                val ack = buildL1Frame(L1_CTRL_ACK, ByteArray(0), seq)
                scope.launch { VehicleBleManager.writeCtrl(ack) }
            }

            if (len >= 5) {
                val payload = value.copyOfRange(idx + L1_HDR, idx + L1_HDR + len)
                parseL2(payload)
            }
            idx += L1_HDR + len
        }
    }

    private fun parseL2(payload: ByteArray) {
        if (payload.size < 5) return
        if ((payload[0].toInt() and 0xFF) != CMD_XFER) return
        val key = payload[2].toInt() and 0xFF
        val vLen = ((payload[3].toInt() and 0xFF) shl 8) or (payload[4].toInt() and 0xFF)
        if (5 + vLen > payload.size) return
        val v = payload.copyOfRange(5, 5 + vLen)

        if (key == KEY_ABORT) {
            abortReason = if (v.isNotEmpty()) v[0].toInt() and 0xFF else 0
            Log.w(TAG, "← XFER_ABORT reason=$abortReason")
            return
        }
        when (key) {
            KEY_BEGIN_RSP -> {
                // Only the first frame waits; anything later just needs to be
                // watched for a rejection so the DATA burst can bail out early.
                if (v.isNotEmpty() && (v[0].toInt() and 0xFF) != 0) beginRejected = true
                synchronized(rspLock) {
                    rspKey = key
                    rspValue = v
                }
            }
            KEY_END_RSP -> {
                run {
                    val status = if (v.isNotEmpty()) v[0].toInt() and 0xFF else 0xFF
                    if (status == 0) {
                        val ms = (System.nanoTime() - frameStartNs) / 1_000_000L
                        NaviPerfStats.onSendThroughput(
                            if (ms > 0) frameBytes * 1_000L / ms else frameBytes.toLong(),
                        )
                        NaviPerfStats.onSent(frameIdx, ms, 0)
                    } else {
                        val err = if (v.size > 1) v[1].toInt() and 0xFF else 0
                        Log.w(TAG, "END_RSP failed status=$status err=$err")
                    }
                }
            }
            else -> Log.d(TAG, "← 0x10 key=0x${Integer.toHexString(key)} ignored")
        }
    }

    private fun clearRsp() {
        abortReason = -1
        synchronized(rspLock) { rspKey = -1; rspValue = null }
    }

    /** Frames handed to the controller but not yet acknowledged by the device. */
    private fun inFlight(): Int = (l1Seq.get() - 1) - lastAckSeq

    /**
     * Waits only while the window is full. Returns false when the wait timed out
     * (the caller then continues unthrottled instead of dropping the frame).
     */
    private suspend fun awaitWindowRoom(): Boolean {
        if (inFlight() < WINDOW) return true
        val deadline = System.currentTimeMillis() + WINDOW_TIMEOUT_MS
        while (running.get() && inFlight() >= WINDOW) {
            if (abortReason >= 0) return false
            if (System.currentTimeMillis() >= deadline) return false
            delay(1)
        }
        return true
    }

    /** Pretend everything outstanding is acknowledged so the window reopens. */
    private fun resyncWindow() {
        lastAckSeq = l1Seq.get() - 1
    }

    private suspend fun awaitRsp(key: Int, timeoutMs: Long): ByteArray? {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (running.get() && System.currentTimeMillis() < deadline) {
            if (abortReason >= 0) return null
            synchronized(rspLock) {
                if (rspKey == key) {
                    val v = rspValue
                    rspKey = -1
                    rspValue = null
                    return v
                }
            }
            delay(4)
        }
        return null
    }

    // ═══════════════════════════════════════════════════════════════
    // L1 / L2 builders
    // ═══════════════════════════════════════════════════════════════

    /** Data frame; [requestAck] sets L1 bit6 so the device answers with an ACK. */
    private suspend fun writeL1Data(payload: ByteArray, requestAck: Boolean = false): Boolean {
        val ctrl = if (requestAck) L1_ACK_REQ else 0x00
        val frame = buildL1Frame(ctrl, payload, l1Seq.getAndIncrement() and 0xFFFF)
        return VehicleBleManager.writeCtrl(frame)
    }

    private fun buildDataFrame(seq: Int, jpeg: ByteArray, from: Int, to: Int): ByteArray {
        val n = to - from
        val out = ByteArray(5 + 2 + n)
        out[0] = CMD_XFER.toByte()
        out[1] = 0
        out[2] = KEY_DATA.toByte()
        putU16(out, 3, 2 + n)
        putU16(out, 5, seq)
        System.arraycopy(jpeg, from, out, 7, n)
        return out
    }

    private fun buildL2(key: Int, value: ByteArray): ByteArray {
        val out = ByteArray(5 + value.size)
        out[0] = CMD_XFER.toByte()
        out[1] = 0
        out[2] = key.toByte()
        putU16(out, 3, value.size)
        System.arraycopy(value, 0, out, 5, value.size)
        return out
    }

    private fun buildL1Frame(ctrl: Int, payload: ByteArray, seq: Int): ByteArray {
        val crc = crc16(payload)
        val frame = ByteArray(L1_HDR + payload.size)
        frame[0] = L1_SYNC.toByte()
        frame[1] = ctrl.toByte()
        putU16(frame, 2, payload.size)
        putU16(frame, 4, crc)
        putU16(frame, 6, seq)
        System.arraycopy(payload, 0, frame, L1_HDR, payload.size)
        return frame
    }

    /** CRC-16/ARC: poly 0x8005 reflected (0xA001), init 0x0000, xorout 0x0000. */
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

    private fun putU16(buf: ByteArray, at: Int, v: Int) {
        buf[at] = ((v shr 8) and 0xFF).toByte()
        buf[at + 1] = (v and 0xFF).toByte()
    }

    private fun putU32(buf: ByteArray, at: Int, v: Long) {
        buf[at] = ((v shr 24) and 0xFF).toByte()
        buf[at + 1] = ((v shr 16) and 0xFF).toByte()
        buf[at + 2] = ((v shr 8) and 0xFF).toByte()
        buf[at + 3] = (v and 0xFF).toByte()
    }
}
