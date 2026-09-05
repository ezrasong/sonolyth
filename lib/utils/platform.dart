import 'dart:io';

/// Android is the only platform this app builds for: `838e2db2` deleted
/// `linux/`, `windows/`, `macos/`, `ios/` and `web/`, and §40 removed the last
/// code that branched on them. `kIsIOS` survives because the iOS *sources*
/// (home-widget app group, the NewPipe-less engine default) are still written
/// for a platform that could be re-added with `flutter create --platforms=ios`;
/// nothing desktop is.
final kIsMobile = kIsAndroid || kIsIOS;

final kIsAndroid = Platform.isAndroid;
final kIsIOS = Platform.isIOS;
