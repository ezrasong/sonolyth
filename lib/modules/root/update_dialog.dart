import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/links/anchor_button.dart';
import 'package:sonolyth/services/dio/dio.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:version/version.dart';

class RootAppUpdateDialog extends HookWidget {
  static const _updaterChannel = MethodChannel("com.ezrasong.sonolyth/updater");

  final Version? version;
  final int? nightlyBuildNum;

  const RootAppUpdateDialog({super.key, this.version}) : nightlyBuildNum = null;
  const RootAppUpdateDialog.nightly({super.key, required this.nightlyBuildNum})
      : version = null;

  @override
  Widget build(BuildContext context) {
    const releasesUrl = "https://github.com/ezrasong/sonolyth/releases";
    final tag = nightlyBuildNum != null ? "nightly" : "v$version";
    final apkUrl =
        "https://github.com/ezrasong/sonolyth/releases/download/$tag/Sonolyth-android-all-arch.apk";

    // null = idle, otherwise 0..1 download progress.
    final progress = useState<double?>(null);
    final failed = useState(false);
    // Set once the APK has fully downloaded, so a retry (e.g. after granting
    // the install permission) goes straight to the installer.
    final downloadedPath = useState<String?>(null);

    // Downloads the release APK and hands it to the system package
    // installer. Releases are signed with the same key, so it installs
    // straight over the running app — no browser round-trip.
    Future<void> downloadAndInstall() async {
      try {
        failed.value = false;
        var apkPath = downloadedPath.value;
        if (apkPath == null) {
          progress.value = 0;
          final dir = await getApplicationCacheDirectory();
          apkPath = p.join(dir.path, "sonolyth-update.apk");
          final apkFile = File(apkPath);
          if (await apkFile.exists()) {
            await apkFile.delete();
          }
          var expectedBytes = 0;
          await globalDio.download(
            apkUrl,
            apkPath,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                expectedBytes = total;
                progress.value = received / total;
              }
            },
          );
          // Don't hand a truncated APK to the installer (and don't cache it for
          // reuse on the next tap): a short read here means an interrupted or
          // proxy-mangled download. Require the full advertised length.
          final downloadedBytes = await apkFile.length();
          if (downloadedBytes == 0 ||
              (expectedBytes > 0 && downloadedBytes < expectedBytes)) {
            await apkFile.delete().catchError((_) => apkFile);
            throw const FormatException("Incomplete APK download");
          }
          downloadedPath.value = apkPath;
          progress.value = null;
        }
        final result = await OpenFile.open(apkPath);
        if (result.type == ResultType.permissionDenied) {
          // First-time installs need the "install unknown apps" toggle;
          // open it and let the user tap the button again afterwards.
          await _updaterChannel.invokeMethod("openInstallPermissionSettings");
        } else if (result.type != ResultType.done) {
          failed.value = true;
        }
      } catch (_) {
        progress.value = null;
        failed.value = true;
      }
    }

    final isDownloading = progress.value != null;

    return AlertDialog(
      title: Text(context.l10n.spotube_has_an_update),
      actions: [
        Button.primary(
          onPressed: isDownloading
              ? null
              : kIsAndroid
                  ? downloadAndInstall
                  : () => launchUrlString(
                        releasesUrl,
                        mode: LaunchMode.externalApplication,
                      ),
          child: Text(context.l10n.download_now),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        // Left-align the body to match the (left-aligned) title and avoid the
        // mixed title-left / body-center / button-right look; Column otherwise
        // defaults to centering its children.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nightlyBuildNum != null
                ? context.l10n.nightly_version(nightlyBuildNum!)
                : context.l10n.release_version(version!),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(context.l10n.read_the_latest),
              AnchorButton(
                context.l10n.release_notes,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () => launchUrlString(
                  releasesUrl,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const Gap(16),
            LinearProgressIndicator(value: progress.value),
            const Gap(8),
            Text("${((progress.value ?? 0) * 100).round()}%").muted().small(),
          ],
          if (failed.value) ...[
            const Gap(16),
            // The releases page stays reachable through the link above, so a
            // terse failure note is enough here.
            Text(
              context.l10n.error("downloading update"),
              style: TextStyle(
                color: Theme.of(context).colorScheme.destructive,
              ),
            ).small(),
          ],
        ],
      ),
    );
  }
}
