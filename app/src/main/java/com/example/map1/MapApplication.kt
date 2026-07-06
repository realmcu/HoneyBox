package com.example.map1

import android.app.Application
import com.amap.api.maps.MapsInitializer
import com.amap.api.navi.AMapNavi
import com.amap.api.services.core.ServiceSettings

/**
 * 应用入口：在使用高德 SDK 前必须先调用隐私合规接口（11.x 版本强制要求）。
 */
class MapApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // 1. 隐私合规：告知 SDK 已经向用户展示并取得同意。
        //    实际产品中应在用户真正同意隐私政策后再调用。
        MapsInitializer.updatePrivacyShow(this, true, true)
        MapsInitializer.updatePrivacyAgree(this, true)

        // 2. 导航 SDK 的隐私合规
        AMapNavi.setApiKey(this, AMAP_KEY)

        // 3. 搜索 SDK（Inputtips/PoiSearch）的隐私合规，否则搜索会报错。
        ServiceSettings.updatePrivacyShow(this, true, true)
        ServiceSettings.updatePrivacyAgree(this, true)
        ServiceSettings.getInstance().setApiKey(AMAP_KEY)
    }

    companion object {
        const val AMAP_KEY = "c0b2e36cff7e98498992046a9a200f39"
    }
}
