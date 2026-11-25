import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_language.dart';
import '../i18n/app_strings.dart';
import '../services/app_settings.dart';

/// Language actually rendered, i.e. the saved preference resolved against the
/// device locale when it is [AppLanguage.system].
final resolvedLanguageProvider = Provider<AppLanguage>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return resolveAppLanguage(settings.language, platformLocale());
});

/// Copy for the resolved language. Everything that renders text should read
/// this (directly or through [AppStringsScope]).
final appStringsProvider = Provider<AppStrings>((ref) {
  final language = ref.watch(resolvedLanguageProvider);
  return language == AppLanguage.zhHans ? const ZhStrings() : const EnStrings();
});

/// Method channel shared with `MainActivity`; the native dashboard reads the
/// same value for its own `LanguagePreference`.
const MethodChannel _mapChannel = MethodChannel('honeybox/map');

/// Mirrors the app-wide language into the native side.
///
/// The dashboard is a separate Compose activity with its own preference store,
/// so it has to be told explicitly — otherwise the Flutter UI and the dashboard
/// could disagree after a switch.
Future<void> pushLanguageToNative(AppLanguage language) async {
  try {
    await _mapChannel.invokeMethod<void>('setLanguage', language.tag);
  } on PlatformException {
    // Non-Android hosts (desktop, tests) have no dashboard to notify.
  } on MissingPluginException {
    // Same: the channel only exists in the Android host.
  }
}

/// Writes the new choice and immediately pushes it to the native dashboard.
Future<void> setAppLanguage(WidgetRef ref, AppLanguage language) async {
  ref.read(appSettingsProvider.notifier).setLanguage(language);
  await pushLanguageToNative(language);
}
