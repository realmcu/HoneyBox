/// Central app metadata.
///
/// [version] must be kept in sync with the `version:` field in pubspec.yaml
/// (currently `1.0.0+1`) — bump both together on release. If runtime-accurate
/// versioning is needed later, swap this for the `package_info_plus` plugin.
class AppInfo {
  AppInfo._();

  static const String version = '1.0.0';
}
