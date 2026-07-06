package com.example.map1.navi

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * 进程内共享的投屏流水线耗时统计。
 *
 * 帧率达不到目标时，用它把各阶段耗时（采集/去填充+缩放/JPEG 编码/TCP 发送）分别记录，
 * 定位瓶颈：是采集端（虚拟屏渲染慢、acquireLatestImage 拿不到新帧）、还是编码慢、
 * 还是网络发送慢。数据同时输出到 logcat 并通过 [snapshot] 显示在 App 预览窗口上。
 *
 * 各阶段串行发生在同一帧上：
 *   captureAndSendJpgFrame:
 *     acquireMs   = acquireLatestImage 耗时
 *     toBitmapMs  = Image -> Bitmap（copyPixels + 去行填充 + 缩放）耗时
 *   compressExecutor（另一线程）:
 *     encodeMs    = TurboJpeg / Bitmap.compress 耗时
 *   NaviJpgTcpSender（另一线程）:
 *     sendMs      = 单帧写 socket + flush 耗时
 */
object NaviPerfStats {

    private const val TAG = "NaviPerfStats"

    data class Snapshot(
        // 目标帧率与实际帧率
        val targetFps: Int = 0,
        val captureFps: Double = 0.0,
        val sendFps: Double = 0.0,
        // 各阶段最近一帧耗时（毫秒）
        val acquireMs: Long = 0,
        val toBitmapMs: Long = 0,
        val encodeMs: Long = 0,
        val sendMs: Long = 0,
        // 采集端一个循环两帧之间的间隔（含 postDelayed 等待），用于判断是否被阻塞
        val loopIntervalMs: Long = 0,
        // 各阶段近 1 秒平均耗时（毫秒）
        val avgAcquireMs: Double = 0.0,
        val avgToBitmapMs: Double = 0.0,
        val avgEncodeMs: Double = 0.0,
        val avgSendMs: Double = 0.0,
        // 采集端因为 acquireLatestImage 返回 null（无新帧）而跳过的次数（近 1 秒）
        val emptyAcquireCount: Int = 0,
        // 发送队列长度、TCP 字节率
        val sendQueueSize: Int = 0,
        val bytesPerSecond: Long = 0,
        val lastSeq: Int = -1,
    ) {
        /** 用于叠加在预览窗上的多行文本。 */
        fun toOverlayText(): String = buildString {
            append("目标FPS=$targetFps 采集=${"%.1f".format(captureFps)} 发送=${"%.1f".format(sendFps)}\n")
            append("acquire=${acquireMs}ms(avg ${"%.1f".format(avgAcquireMs)}) 空采=$emptyAcquireCount\n")
            append("bitmap=${toBitmapMs}ms(avg ${"%.1f".format(avgToBitmapMs)})\n")
            append("encode=${encodeMs}ms(avg ${"%.1f".format(avgEncodeMs)})\n")
            append("send=${sendMs}ms(avg ${"%.1f".format(avgSendMs)}) q=$sendQueueSize\n")
            append("loop=${loopIntervalMs}ms kbps=${bytesPerSecond * 8 / 1000} seq=$lastSeq")
        }
    }

    private val _snapshot = MutableStateFlow(Snapshot())
    val snapshot: StateFlow<Snapshot> = _snapshot

    // 目标帧率
    @Volatile private var targetFps = 0

    // 采集端最近一帧
    @Volatile private var lastAcquireMs = 0L
    @Volatile private var lastToBitmapMs = 0L
    @Volatile private var lastLoopIntervalMs = 0L
    @Volatile private var lastLoopStartNs = 0L

    // 编码端最近一帧
    @Volatile private var lastEncodeMs = 0L

    // 发送端最近一帧
    @Volatile private var lastSendMs = 0L
    @Volatile private var lastSendQueueSize = 0
    @Volatile private var lastBytesPerSecond = 0L
    @Volatile private var lastSeq = -1

    // 近 1 秒窗口累计
    private val lock = Any()
    private var windowStartNs = 0L
    private var captureFrames = 0
    private var sendFrames = 0
    private var emptyAcquires = 0
    private var sumAcquireMs = 0L
    private var sumToBitmapMs = 0L
    private var sumEncodeMs = 0L
    private var sumSendMs = 0L

    fun reset(targetFps: Int) {
        this.targetFps = targetFps
        synchronized(lock) {
            windowStartNs = System.nanoTime()
            captureFrames = 0
            sendFrames = 0
            emptyAcquires = 0
            sumAcquireMs = 0
            sumToBitmapMs = 0
            sumEncodeMs = 0
            sumSendMs = 0
        }
        lastLoopStartNs = 0
        _snapshot.value = Snapshot(targetFps = targetFps)
    }

    /** 采集循环每次进入时调用，用于计算两帧循环之间的实际间隔。 */
    fun onCaptureLoopStart() {
        val now = System.nanoTime()
        if (lastLoopStartNs != 0L) {
            lastLoopIntervalMs = (now - lastLoopStartNs) / 1_000_000L
        }
        lastLoopStartNs = now
    }

    /** acquireLatestImage 返回 null（虚拟屏还没渲染出新帧）时调用。 */
    fun onEmptyAcquire(acquireMs: Long) {
        lastAcquireMs = acquireMs
        synchronized(lock) { emptyAcquires += 1 }
        maybePublish()
    }

    /** 成功取到一帧并转成 Bitmap 后调用。 */
    fun onCaptured(acquireMs: Long, toBitmapMs: Long) {
        lastAcquireMs = acquireMs
        lastToBitmapMs = toBitmapMs
        synchronized(lock) {
            captureFrames += 1
            sumAcquireMs += acquireMs
            sumToBitmapMs += toBitmapMs
        }
        maybePublish()
    }

    /** JPEG 编码完成后调用。 */
    fun onEncoded(encodeMs: Long) {
        lastEncodeMs = encodeMs
        synchronized(lock) { sumEncodeMs += encodeMs }
    }

    /** 单帧 TCP 发送完成后调用。 */
    fun onSent(seq: Int, sendMs: Long, queueSize: Int) {
        lastSendMs = sendMs
        lastSendQueueSize = queueSize
        lastSeq = seq
        synchronized(lock) {
            sendFrames += 1
            sumSendMs += sendMs
        }
    }

    /** TCP 发送端 1 秒统计出的字节率。 */
    fun onSendThroughput(bytesPerSecond: Long) {
        lastBytesPerSecond = bytesPerSecond
    }

    private fun maybePublish() {
        val now = System.nanoTime()
        val elapsedNs: Long
        val capF: Int
        val sendF: Int
        val emptyC: Int
        val avgAcq: Double
        val avgBmp: Double
        val avgEnc: Double
        val avgSnd: Double
        synchronized(lock) {
            elapsedNs = now - windowStartNs
            if (elapsedNs < 1_000_000_000L) return
            val secs = elapsedNs / 1_000_000_000.0
            capF = captureFrames
            sendF = sendFrames
            emptyC = emptyAcquires
            avgAcq = if (capF > 0) sumAcquireMs.toDouble() / capF else 0.0
            avgBmp = if (capF > 0) sumToBitmapMs.toDouble() / capF else 0.0
            avgEnc = if (capF > 0) sumEncodeMs.toDouble() / capF else 0.0
            avgSnd = if (sendF > 0) sumSendMs.toDouble() / sendF else 0.0
            val captureFps = capF / secs
            val sendFps = sendF / secs

            val snap = Snapshot(
                targetFps = targetFps,
                captureFps = captureFps,
                sendFps = sendFps,
                acquireMs = lastAcquireMs,
                toBitmapMs = lastToBitmapMs,
                encodeMs = lastEncodeMs,
                sendMs = lastSendMs,
                loopIntervalMs = lastLoopIntervalMs,
                avgAcquireMs = avgAcq,
                avgToBitmapMs = avgBmp,
                avgEncodeMs = avgEnc,
                avgSendMs = avgSnd,
                emptyAcquireCount = emptyC,
                sendQueueSize = lastSendQueueSize,
                bytesPerSecond = lastBytesPerSecond,
                lastSeq = lastSeq,
            )
            _snapshot.value = snap
            Log.i(
                TAG,
                "target=$targetFps capFps=${"%.2f".format(captureFps)} sendFps=${"%.2f".format(sendFps)} " +
                    "acquire(avg=${"%.1f".format(avgAcq)}) bitmap(avg=${"%.1f".format(avgBmp)}) " +
                    "encode(avg=${"%.1f".format(avgEnc)}) send(avg=${"%.1f".format(avgSnd)}) " +
                    "empty=$emptyC loop=${lastLoopIntervalMs}ms q=$lastSendQueueSize " +
                    "kbps=${lastBytesPerSecond * 8 / 1000}",
            )

            // 重置窗口
            windowStartNs = now
            captureFrames = 0
            sendFrames = 0
            emptyAcquires = 0
            sumAcquireMs = 0
            sumToBitmapMs = 0
            sumEncodeMs = 0
            sumSendMs = 0
        }
    }

    fun clear() {
        _snapshot.value = Snapshot()
    }
}
