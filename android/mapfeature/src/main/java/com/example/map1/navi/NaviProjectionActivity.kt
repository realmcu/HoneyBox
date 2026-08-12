package com.example.map1.navi

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast

/**
 * 方案 X 的启动入口：只负责确保悬浮窗权限，然后启动 [NaviCaptureService] 并立即 finish。
 * 导航渲染与截图发送全部在 Service 的私有虚拟屏中完成，不再依赖 MediaProjection，
 * 避免锁屏后系统屏幕采集被保护而输出黑帧。
 *
 * 启动参数与原 [NaviActivity] 相同（起终点、速度、TCP 主机/端口/帧率）。
 */
class NaviProjectionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startServiceIfReady()
    }

    /** 先确保悬浮窗权限（Service 显示 Presentation 必需），再启动虚拟屏。 */
    private fun startServiceIfReady() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "请授予『悬浮窗/显示在其他应用上层』权限后返回再试", Toast.LENGTH_LONG)
                .show()
            startActivityForResult(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
                REQUEST_OVERLAY,
            )
            return
        }
        startNaviCaptureService()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_OVERLAY) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
                startNaviCaptureService()
            } else {
                Toast.makeText(this, "未授予悬浮窗权限，无法启动导航投屏", Toast.LENGTH_LONG).show()
                finish()
            }
            return
        }
        finish()
    }

    private fun startNaviCaptureService() {
        val serviceIntent = NaviCaptureService.newIntent(
            context = this,
            host = intent.getStringExtra(NaviActivity.EXTRA_TCP_HOST).orEmpty().trim(),
            port = intent.getIntExtra(NaviActivity.EXTRA_TCP_PORT, 5004),
            fps = intent.getIntExtra(NaviActivity.EXTRA_TCP_FPS, 5),
            speed = intent.getIntExtra(NaviActivity.EXTRA_SPEED, 60),
            dpi = intent.getIntExtra(
                NaviCaptureService.EXTRA_DPI,
                NaviCaptureService.DEFAULT_VIRTUAL_DISPLAY_DPI,
            ),
            width = intent.getIntExtra(
                NaviCaptureService.EXTRA_WIDTH,
                NaviCaptureService.DEFAULT_JPG_WIDTH,
            ),
            height = intent.getIntExtra(
                NaviCaptureService.EXTRA_HEIGHT,
                NaviCaptureService.DEFAULT_JPG_HEIGHT,
            ),
            startLat = intent.getDoubleExtra(NaviActivity.EXTRA_START_LAT, 31.314),
            startLng = intent.getDoubleExtra(NaviActivity.EXTRA_START_LNG, 120.728),
            endLat = intent.getDoubleExtra(NaviActivity.EXTRA_END_LAT, 31.325),
            endLng = intent.getDoubleExtra(NaviActivity.EXTRA_END_LNG, 120.629),
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        Toast.makeText(this, "导航虚拟屏已在后台启动", Toast.LENGTH_SHORT).show()
        finish()
    }

    companion object {
        private const val REQUEST_OVERLAY = 2002
    }
}
