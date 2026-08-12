package com.example.map1.navi

import android.net.Network
import android.util.Log
import java.io.ByteArrayOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 将导航画面 JPG 帧按 assert/send_jpg_sequence.py 相同协议发送到局域网设备。
 *
 * 协议：单个持久 TCP 连接，逐帧发送：
 *   JPG <size> <seq>\n
 *   <JPEG payload>
 */
class NaviJpgTcpSender(
    private val host: String,
    private val port: Int,
    private val connectTimeoutMs: Int = 30_000,
    private val readTimeoutMs: Int = 2_000,
    private val networkProvider: () -> Network? = { null },
    private val onStatus: (String) -> Unit = {},
    private val onFps: (fps: Double, lastSeq: Int, bytesPerSecond: Long) -> Unit = { _, _, _ -> },
    private val onSendTiming: (seq: Int, bytes: Int, sendMs: Long) -> Unit = { _, _, _ -> },
) {
    private data class Frame(val seq: Int, val jpeg: ByteArray)

    private val running = AtomicBoolean(false)
    private val queue = ArrayBlockingQueue<Frame>(2)
    private var worker: Thread? = null
    @Volatile private var socket: Socket? = null
    private var statsWindowStartNs = 0L
    private var statsFrames = 0
    private var statsBytes = 0L

    val isRunning: Boolean
        get() = running.get()

    /** 待发送队列长度。持续 >0 说明网络发送慢于采集/编码。 */
    val queueSize: Int
        get() = queue.size

    fun start() {
        if (!running.compareAndSet(false, true)) return
        worker = Thread(::runSenderLoop, "NaviJpgTcpSender").apply { start() }
    }

    fun stop() {
        running.set(false)
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        worker?.interrupt()
        worker = null
        queue.clear()
    }

    fun enqueue(seq: Int, jpeg: ByteArray) {
        if (!running.get()) return
        // 发送端慢于截图端时丢弃旧帧，只保留最新序列，避免导航 UI 被网络阻塞。
        while (!queue.offer(Frame(seq, jpeg))) {
            queue.poll()
        }
    }

    private fun runSenderLoop() {
        while (running.get()) {
            try {
                val selectedNetwork = networkProvider()
                val createdSocket = selectedNetwork?.socketFactory?.createSocket() ?: Socket()
                createdSocket.use { tcpSocket ->
                    socket = tcpSocket
                    tcpSocket.tcpNoDelay = true
                    try {
                        tcpSocket.sendBufferSize = SOCKET_SEND_BUFFER_BYTES
                    } catch (e: Exception) {
                        Log.w(TAG, "设置 TCP send buffer 失败", e)
                    }
                    tcpSocket.soTimeout = readTimeoutMs
                    tcpSocket.connect(InetSocketAddress(host, port), connectTimeoutMs)
                    onStatus("TCP 已连接 $host:$port, sndbuf=${tcpSocket.sendBufferSize}")

                    readReadyGreeting(tcpSocket)
                    resetStatsWindow()

                    while (running.get()) {
                        val frame = try {
                            queue.take()
                        } catch (_: InterruptedException) {
                            break
                        }
                        sendFrame(tcpSocket, frame)
                        drainAcks(tcpSocket)
                    }
                }
            } catch (e: Exception) {
                if (running.get()) {
                    Log.e(TAG, "TCP JPG 连接/发送失败，准备重连", e)
                    onStatus("TCP 断开：${e.message}，${RECONNECT_DELAY_MS}ms 后重连")
                }
            } finally {
                socket = null
            }

            if (running.get()) {
                sleepBeforeReconnect()
            }
        }

        queue.clear()
        onStatus("TCP 已停止")
    }

    private fun sleepBeforeReconnect() {
        try {
            Thread.sleep(RECONNECT_DELAY_MS)
        } catch (_: InterruptedException) {
            // stop() 会 interrupt 线程；外层 running=false 后退出。
        }
    }

    private fun sendFrame(socket: Socket, frame: Frame) {
        val startedNs = System.nanoTime()
        val out = socket.getOutputStream()
        val header = "JPG ${frame.jpeg.size} ${frame.seq}\n".toByteArray(Charsets.US_ASCII)
        out.write(header)
        var offset = 0
        while (offset < frame.jpeg.size) {
            val chunk = minOf(PAYLOAD_CHUNK_BYTES, frame.jpeg.size - offset)
            out.write(frame.jpeg, offset, chunk)
            offset += chunk
        }
        out.flush()
        val sendMs = (System.nanoTime() - startedNs) / 1_000_000L
        onSendTiming(frame.seq, frame.jpeg.size, sendMs)
        recordSentFrame(frame.seq, frame.jpeg.size)
    }

    private fun resetStatsWindow() {
        statsWindowStartNs = System.nanoTime()
        statsFrames = 0
        statsBytes = 0L
    }

    private fun recordSentFrame(seq: Int, bytes: Int) {
        statsFrames += 1
        statsBytes += bytes.toLong()

        val now = System.nanoTime()
        val elapsedNs = now - statsWindowStartNs
        if (elapsedNs >= 1_000_000_000L) {
            val elapsedSeconds = elapsedNs / 1_000_000_000.0
            val fps = statsFrames / elapsedSeconds
            val bytesPerSecond = (statsBytes / elapsedSeconds).toLong()
            Log.d(
                TAG,
                "actual_send_fps=${"%.2f".format(fps)}, last_seq=$seq, " +
                    "bytes_per_sec=$bytesPerSecond, queue=${queue.size}",
            )
            onFps(fps, seq, bytesPerSecond)
            resetStatsWindow()
        }
    }

    private fun readReadyGreeting(socket: Socket) {
        try {
            val line = readLine(socket)
            if (line.isNotBlank()) {
                Log.i(TAG, "board: $line")
            }
        } catch (_: Exception) {
            // 兼容不发送 READY 的接收端。
        }
    }

    private fun drainAcks(socket: Socket) {
        try {
            socket.soTimeout = 1
            val input = socket.getInputStream()
            val buffer = ByteArray(512)
            while (running.get()) {
                val read = input.read(buffer)
                if (read <= 0) break
            }
        } catch (_: Exception) {
            // 非阻塞式尽力读取 ACK，不等待。
        } finally {
            try {
                socket.soTimeout = readTimeoutMs
            } catch (_: Exception) {
            }
        }
    }

    private fun readLine(socket: Socket, limit: Int = 128): String {
        val input = socket.getInputStream()
        val out = ByteArrayOutputStream()
        while (out.size() < limit) {
            val b = input.read()
            if (b < 0 || b == '\n'.code) break
            if (b != '\r'.code) out.write(b)
        }
        return out.toString(Charsets.US_ASCII.name()).trim()
    }

    companion object {
        private const val TAG = "NaviJpgTcpSender"
        private const val RECONNECT_DELAY_MS = 1_000L
        private const val PAYLOAD_CHUNK_BYTES = 16 * 1024
        private const val SOCKET_SEND_BUFFER_BYTES = 256 * 1024
    }
}
