package com.example.map1.i18n

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Persisted in-app language override.
 *
 * [selected] is Compose state: whoever reads it inside a composition recomposes
 * when the user picks another language, so the dashboard switches without an
 * activity restart. The value survives process death via SharedPreferences and
 * is shared by every native page of the module.
 */
object LanguagePreference {

    private const val PREFS_NAME = "dashboard_prefs"
    private const val KEY_LANGUAGE = "app_language"

    private var loaded = false

    var selected: AppLanguage by mutableStateOf(AppLanguage.SYSTEM)
        private set

    /** Loads the stored choice once per process. Safe to call from onCreate(). */
    fun ensureLoaded(context: Context) {
        if (loaded) return
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        selected = AppLanguage.fromTag(prefs.getString(KEY_LANGUAGE, null))
        loaded = true
    }

    fun select(context: Context, language: AppLanguage) {
        selected = language
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LANGUAGE, language.tag)
            .apply()
    }
}
