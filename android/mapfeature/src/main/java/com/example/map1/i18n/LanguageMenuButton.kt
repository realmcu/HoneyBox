package com.example.map1.i18n

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext

/**
 * Wraps page content with the copy for the currently selected language.
 *
 * Put this around the activity's `setContent` body; every `LocalAppStrings`
 * read below it recomposes when the user switches language.
 */
@Composable
fun DashboardI18n(content: @Composable () -> Unit) {
    val strings = rememberAppStrings()
    androidx.compose.runtime.CompositionLocalProvider(
        LocalAppStrings provides strings,
        content = content,
    )
}

/**
 * Globe button with a "follow system / 简体中文 / English" menu.
 *
 * Shows a check on the active choice. Selecting a language writes
 * [LanguagePreference] and recomposes the page in place — no activity restart.
 */
@Composable
fun LanguageMenuButton(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val strings = LocalAppStrings.current
    var expanded by remember { mutableStateOf(false) }

    Box(modifier = modifier) {
        IconButton(onClick = { expanded = true }) {
            Icon(
                imageVector = Icons.Outlined.Language,
                contentDescription = strings.languageMenuDescription,
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            AppLanguage.entries.forEach { language ->
                DropdownMenuItem(
                    text = { Text(language.label(strings)) },
                    trailingIcon = {
                        if (LanguagePreference.selected == language) {
                            Icon(Icons.Outlined.Check, contentDescription = null)
                        }
                    },
                    onClick = {
                        LanguagePreference.select(context, language)
                        expanded = false
                    },
                )
            }
        }
    }
}
