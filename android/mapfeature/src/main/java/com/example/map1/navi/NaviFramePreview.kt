package com.example.map1.navi

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * 进程内共享的投屏 JPG 预览帧。
 *
 * [NaviCaptureService] 每生成一帧要发送的 JPG 后发布到这里，主界面用一个小窗口同步显示。
 */
object NaviFramePreview {
    data class Frame(
        val seq: Int,
        val jpeg: ByteArray,
        val timestampMs: Long = System.currentTimeMillis(),
    )

    private val _latestFrame = MutableStateFlow<Frame?>(null)
    val latestFrame: StateFlow<Frame?> = _latestFrame

    /**
     * 虚拟屏导航是否正在运行。[NaviCaptureService] 启动时置 true，销毁（包括到达终点后自行停止）
     * 时置 false，主界面据此在「开始 / 结束虚拟屏导航」间切换，并决定是否全屏显示投屏预览。
     */
    private val _running = MutableStateFlow(false)
    val running: StateFlow<Boolean> = _running

    fun setRunning(running: Boolean) {
        _running.value = running
    }

    fun publish(seq: Int, jpeg: ByteArray) {
        _latestFrame.value = Frame(seq = seq, jpeg = jpeg)
    }

    fun clear() {
        _latestFrame.value = null
    }
}
