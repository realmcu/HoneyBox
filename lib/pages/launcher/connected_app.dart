import '../../providers/ble_provider.dart';
import 'app_catalog.dart';

/// Whether [info] is owned by [app].
///
/// `ownerApp` is recorded when the connection is created. The legacy fallback
/// keeps older callers/tests useful: JW devices belong to Watch and non-JW
/// devices belong to eBadge.
bool connectedDeviceMatchesApp(ConnectedDeviceInfo? info, AppId app) {
  if (info == null) return false;
  final owner = info.ownerApp;
  if (owner != null) return owner == app.name;
  return switch (app) {
    AppId.watch => info.isJw,
    AppId.ebadge => !info.isJw,
    _ => false,
  };
}
