package com.example.map1.i18n

import android.content.res.Configuration

/**
 * Languages the native dashboard ships with.
 *
 * [SYSTEM] follows the device locale at read time; the two explicit values are
 * the in-app override the user can pick from the dashboard header.
 */
enum class AppLanguage(val tag: String) {
    SYSTEM("system"),
    ZH_HANS("zh-Hans"),
    EN("en");

    companion object {
        /** Parses a persisted tag, falling back to [SYSTEM] for unknown values. */
        fun fromTag(tag: String?): AppLanguage =
            entries.firstOrNull { it.tag == tag } ?: SYSTEM
    }
}

/**
 * Resolves the language actually used for rendering.
 *
 * Only Simplified Chinese and English are supported, so every `zh*` locale
 * (including zh-Hant) maps to [AppLanguage.ZH_HANS] and everything else to
 * [AppLanguage.EN].
 */
fun resolveLanguage(preference: AppLanguage, configuration: Configuration): AppLanguage =
    when (preference) {
        AppLanguage.ZH_HANS -> AppLanguage.ZH_HANS
        AppLanguage.EN -> AppLanguage.EN
        AppLanguage.SYSTEM ->
            if (configuration.locales[0].language.equals("zh", ignoreCase = true)) {
                AppLanguage.ZH_HANS
            } else {
                AppLanguage.EN
            }
    }

/** Menu label for [language], rendered in the language currently displayed. */
fun AppLanguage.label(strings: AppStrings): String = when (this) {
    AppLanguage.SYSTEM -> strings.languageFollowSystem
    AppLanguage.ZH_HANS -> strings.languageZhHans
    AppLanguage.EN -> strings.languageEn
}
