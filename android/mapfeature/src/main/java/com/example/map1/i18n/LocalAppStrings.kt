package com.example.map1.i18n

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import com.example.map1.i18n.AppLanguage.EN
import com.example.map1.i18n.AppLanguage.ZH_HANS

/**
 * Copy for the current page tree.
 *
 * Provided once per activity (see the `i18n { }` wrapper in the call sites) so
 * composables deep in the tree can read it without threading parameters.
 */
val LocalAppStrings = staticCompositionLocalOf<AppStrings> { ZhHansStrings }

/**
 * Resolves the copy to render and subscribes the caller to language changes.
 *
 * Reads [LanguagePreference.selected], so switching the language in the menu
 * recomposes every composable that resolved strings this way.
 */
@Composable
fun rememberAppStrings(): AppStrings {
    val context = LocalContext.current
    val preference = LanguagePreference.selected
    return remember(preference, context) { appStrings(context) }
}

/** Non-composable entry point, for toasts and manager callbacks. */
fun appStrings(context: Context): AppStrings {
    val language = resolveLanguage(LanguagePreference.selected, context.resources.configuration)
    return when (language) {
        ZH_HANS -> ZhHansStrings
        EN -> EnglishStrings
        AppLanguage.SYSTEM -> ZhHansStrings // resolveLanguage never returns this
    }
}
