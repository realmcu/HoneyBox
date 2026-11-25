package com.example.map1

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import com.amap.api.maps.MapsInitializer
import com.amap.api.navi.AMapNavi
import com.amap.api.services.core.ServiceSettings

/** Initializes AMap only after the user has explicitly accepted its privacy terms. */
object MapSdkInitializer {
    private const val TAG = "MapSdkInitializer"
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

    /**
     * Returns true when the map SDK is ready. A missing API key is reported as
     * false instead of thrown: local debug builds without android/local.properties
     * have no key, and the dashboard's BLE connection / settings must stay usable.
     * Release builds cannot reach this state — Gradle fails the build when
     * AMAP_RELEASE_KEY is absent.
     */
    fun initialize(context: Context): Boolean {
        require(hasConsent(context)) { "AMap privacy consent has not been granted" }
        if (initialized) return true
        synchronized(this) {
            if (initialized) return true
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
            if (apiKey == null) {
                Log.w(TAG, "AMap API key missing from the manifest; map and search disabled")
                return false
            }
            AMapNavi.setApiKey(appContext, apiKey)
            ServiceSettings.getInstance().setApiKey(apiKey)
            initialized = true
            return true
        }
    }
}
