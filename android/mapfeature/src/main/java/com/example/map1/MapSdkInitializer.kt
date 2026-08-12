package com.example.map1

import android.content.Context
import android.content.pm.PackageManager
import com.amap.api.maps.MapsInitializer
import com.amap.api.navi.AMapNavi
import com.amap.api.services.core.ServiceSettings

/** Initializes AMap only after the user has explicitly accepted its privacy terms. */
object MapSdkInitializer {
    private const val AMAP_KEY_METADATA = "com.amap.api.v2.apikey"
    private const val PREFERENCES_NAME = "amap_privacy"
    private const val CONSENT_KEY = "privacy_consent_granted"

    @Volatile
    private var initialized = false

    fun hasConsent(context: Context): Boolean =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getBoolean(CONSENT_KEY, false)

    fun persistConsent(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(CONSENT_KEY, true)
            .apply()
    }

    fun initialize(context: Context) {
        require(hasConsent(context)) { "AMap privacy consent has not been granted" }
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            val appContext = context.applicationContext

            // AMap requires privacy-display notification before privacy agreement,
            // and both calls must precede API-key setup or use of any SDK feature.
            MapsInitializer.updatePrivacyShow(appContext, true, true)
            MapsInitializer.updatePrivacyAgree(appContext, true)
            ServiceSettings.updatePrivacyShow(appContext, true, true)
            ServiceSettings.updatePrivacyAgree(appContext, true)
            val applicationInfo = appContext.packageManager.getApplicationInfo(
                appContext.packageName,
                PackageManager.GET_META_DATA,
            )
            val apiKey = applicationInfo.metaData?.getString(AMAP_KEY_METADATA)
                ?.takeIf { it.isNotBlank() }
                ?: error("AMap API key is missing from the application manifest")
            AMapNavi.setApiKey(appContext, apiKey)
            ServiceSettings.getInstance().setApiKey(apiKey)
            initialized = true
        }
    }
}
