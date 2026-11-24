import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_info.dart';
import '../../i18n/app_strings.dart';
import '../../services/update_service.dart';

/// Runs the full "检查更新" flow off [context]: pick a mirror → query it →
/// compare versions → (if newer) confirm, download with a progress dialog,
/// then hand the APK to the system installer. Manages its own dialogs and
/// snackbars, so the caller only needs to supply a live [context].
Future<void> runUpdateCheck(BuildContext context) async {
  final strings = AppStrings.of(context);
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.updateIosOnly)),
    );
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.macOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.updateMacOnly)),
    );
    return;
  }

  // Capture navigator/messenger up front so they can be used across the awaits
  // below without tripping `use_build_context_synchronously`.
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  // Show feedback on the *root* overlay so it layers above an open drawer;
  // fall back to a SnackBar only if that overlay is somehow unavailable.
  void snack(String msg) {
    final overlay = navigator.overlay;
    if (overlay != null) {
      _showTopToast(overlay, msg);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // 0. Ask which mirror to check. GitHub is usually freshest; Gitee is the
  // mainland-friendly fallback. Dismissing the dialog cancels the whole flow.
  final source = await _pickSource(context);
  if (!context.mounted || source == null) return;

  // 1. Query the release page behind a blocking spinner.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CheckingDialog(),
  );

  UpdateInfo? info;
  Object? error;
  try {
    info = await UpdateService.checkForUpdate(AppInfo.version, source: source);
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  navigator.pop(); // dismiss the spinner

  if (error != null) {
    snack(strings.updateCheckFailed(error));
    return;
  }
  final result = info!;
  if (!result.hasUpdate) {
    snack(strings.updateUpToDate(result.currentVersion));
    return;
  }

  // 2. Ask whether to update, showing the release notes.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dctx) {
      final cs = Theme.of(dctx).colorScheme;
      return AlertDialog(
        title: Text(strings.updateFoundTitle(result.latestVersion)),
        content: SingleChildScrollView(
          child: Text(
            result.releaseNotes.isEmpty
                ? strings.updateConfirmBody(result.currentVersion)
                : result.releaseNotes,
          ),
        ),
        // Two full-width buttons stacked vertically — install on top, neutral
        // "later" below — mirroring the 断开连接 dialog's layout and colors.
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dctx, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(strings.updateDownloadInstall),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dctx, false),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                  ),
                  child: Text(strings.updateLater),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  // 3. Reuse a previously downloaded & verified APK when one exists, so the
  // user isn't forced to re-download after returning from the system's
  // "install unknown apps" permission screen. Otherwise download afresh.
  File? apk = await UpdateService.cachedApk(result.latestVersion,
      expectedSha256: result.apkSha256);
  if (!context.mounted) return;

  if (apk != null) {
    final reuse = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        final cs = Theme.of(dctx).colorScheme;
        return AlertDialog(
          title: Text(strings.updateAlreadyTitle(result.latestVersion)),
          content: Text(strings.updateAlreadyBody),
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(strings.updateContinueInstall),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: cs.surfaceContainerHighest,
                      foregroundColor: cs.onSurface,
                    ),
                    child: Text(strings.updateRedownload),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (reuse == null) return; // dismissed → cancel the whole flow
    if (reuse == false) apk = null; // fall through to a fresh download
  }

  // 4. Download when there's no reusable package (or the user chose to
  // redownload), streaming progress into a dialog.
  if (apk == null) {
    final progress = ValueNotifier<double?>(0);
    if (!context.mounted) {
      progress.dispose();
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(progress: progress),
    );

    Object? downloadError;
    try {
      apk = await UpdateService.downloadApk(
        result.apkUrl,
        result.latestVersion,
        expectedSha256: result.apkSha256,
        onProgress: (p) => progress.value = p,
      );
    } catch (e) {
      downloadError = e;
    }
    if (!context.mounted) {
      progress.dispose();
      return;
    }
    navigator.pop(); // dismiss the progress dialog
    progress.dispose();

    if (downloadError != null || apk == null) {
      snack(strings
          .updateDownloadFailed(downloadError ?? strings.updateUnknownError));
      return;
    }
  }

  // 5. Ensure the "install unknown apps" grant, then launch the installer.
  if (Platform.isAndroid) {
    final status = await Permission.requestInstallPackages.request();
    if (!context.mounted) return;
    if (!status.isGranted) {
      snack(strings.updateNeedInstallPermission);
      return;
    }
  }
  final opened = await OpenFilex.open(apk.path);
  if (!context.mounted) return;
  if (opened.type != ResultType.done) {
    snack(strings.updateCannotOpenInstaller(opened.message));
  }
}

/// Asks which mirror to check for updates. Returns the chosen [UpdateSource],
/// or null when the user dismisses the dialog (cancelling the whole flow).
/// Uses the same stacked full-width button layout as the other update dialogs.
Future<UpdateSource?> _pickSource(BuildContext context) {
  return showDialog<UpdateSource>(
    context: context,
    builder: (dctx) {
      final cs = Theme.of(dctx).colorScheme;
      final strings = AppStrings.of(dctx);
      return AlertDialog(
        title: Text(strings.updatePickTitle),
        content: Text(strings.updatePickBody),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dctx, UpdateSource.github),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(strings.updateFromGithub),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dctx, UpdateSource.gitee),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                  ),
                  child: Text(strings.updateFromGitee),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Small centred spinner shown while the release API is queried.
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 20),
          Text(AppStrings.of(context).updateChecking),
        ],
      ),
    );
  }
}

/// Determinate (or indeterminate) download progress bar with a percentage.
class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.progress});

  final ValueNotifier<double?> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.of(context).updateDownloadingTitle),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (context, value, _) {
          final pct = value == null
              ? null
              : (value.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text(
                pct == null
                    ? AppStrings.of(context).updateDownloading
                    : '$pct%',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Briefly shows [message] near the bottom on the *root* overlay, so it layers
/// above page chrome such as an open navigation drawer. Auto-dismisses.
void _showTopToast(OverlayState overlay, String message) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// Fading, self-dismissing toast body used by [_showTopToast].
class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    _timer = Timer(const Duration(milliseconds: 2600), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _fade.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomInset + 48,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
