import 'dart:ui';

/// Languages the app ships with.
///
/// [system] follows the device locale; the two explicit values are the
/// override the user picks from the launcher's language menu. The tags match
/// the native `AppLanguage` enum so the choice can be pushed to the Android
/// dashboard over the `honeybox/map` channel.
enum AppLanguage { system, zhHans, en }

extension AppLanguageTag on AppLanguage {
  /// Persisted tag / platform-channel value.
  String get tag => switch (this) {
        AppLanguage.system => 'system',
        AppLanguage.zhHans => 'zh-Hans',
        AppLanguage.en => 'en',
      };
}

AppLanguage appLanguageFromTag(String? tag) {
  for (final language in AppLanguage.values) {
    if (language.tag == tag) return language;
  }
  return AppLanguage.system;
}

/// Resolves the preference against the device locale.
///
/// Only Simplified Chinese and English are supported, so every `zh*` locale
/// maps to [AppLanguage.zhHans] and everything else to [AppLanguage.en].
AppLanguage resolveAppLanguage(AppLanguage preference, Locale systemLocale) {
  switch (preference) {
    case AppLanguage.zhHans:
      return AppLanguage.zhHans;
    case AppLanguage.en:
      return AppLanguage.en;
    case AppLanguage.system:
      return systemLocale.languageCode == 'zh'
          ? AppLanguage.zhHans
          : AppLanguage.en;
  }
}

/// Device locale, safe on every engine (desktop/web/tests included).
Locale platformLocale() {
  final locales = PlatformDispatcher.instance.locales;
  return locales.isEmpty ? const Locale('en') : locales.first;
}
