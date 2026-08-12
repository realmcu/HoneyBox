package com.example.map1

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent

object MapFeature {
    private const val PRIVACY_MESSAGE =
        "地图与导航功能由高德地图 SDK 提供。启用后，高德可能处理设备标识、位置信息、网络信息和导航数据，以提供地图展示、地点搜索、定位与路线规划服务。是否同意启用？"

    interface OpenCallback {
        fun onOpened()
        fun onDeclined()
        fun onError(error: Throwable)
    }

    @JvmStatic
    fun open(activity: Activity, callback: OpenCallback) {
        if (MapSdkInitializer.hasConsent(activity)) {
            openAfterConsent(activity, callback)
            return
        }

        AlertDialog.Builder(activity)
            .setTitle("高德地图隐私授权")
            .setMessage(PRIVACY_MESSAGE)
            .setPositiveButton("同意并打开") { _, _ ->
                MapSdkInitializer.persistConsent(activity)
                openAfterConsent(activity, callback)
            }
            .setNegativeButton("不同意") { _, _ -> callback.onDeclined() }
            .setOnCancelListener { callback.onDeclined() }
            .show()
    }

    private fun openAfterConsent(activity: Activity, callback: OpenCallback) {
        try {
            MapSdkInitializer.initialize(activity.applicationContext)
            activity.startActivity(Intent(activity, MapHomeActivity::class.java))
            callback.onOpened()
        } catch (error: Throwable) {
            callback.onError(error)
        }
    }
}
