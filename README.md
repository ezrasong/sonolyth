<div align="center">
  <img width="160" src="assets/branding/sonolyth-logo.png" alt="Sonolyth logo">

  <h1>Sonolyth</h1>

A cross-platform, extensible, open-source music streaming app — an Android-focused fork of [Spotube](https://github.com/KRTirtho/spotube).<br>
Bring your own music metadata, playlists, and audio sources through plugins. A small step towards the decentralized music streaming era!

</div>

---

<div align="center">

![Sonolyth on Android](assets/branding/mobile-screenshots/combined.jpg)

</div>

## 🌃 Features

- 🧩 **Plugin powered** — supports any platform or custom music service through plugins.
- 🎶 **Bundled Spotify metadata plugin** — ships a patched build of the unofficial Spotify plugin that returns playlists/albums/artists nested inside Spotify folders and retries on rate-limit (HTTP 429).
- ⬇️ Freely downloadable tracks with tagged metadata.
- 🕒 Time-synced lyrics regardless of plugin support.
- ✋ No telemetry, diagnostics, or user-data collection.
- 🚀 Native performance.
- 📖 Open source / libre software.

## 📦 Repository layout

Sonolyth is a **monorepo**: the app and its edited Spotify metadata plugin live in the same repository and are versioned together. See **[MONOREPO.md](MONOREPO.md)** for the full layout, the upstream-sync workflow, and how to rebuild the plugin.

```
sonolyth/
  lib/  android/  assets/  …            the app (fork of KRTirtho/spotube)
  plugins/spotube-plugin-spotify/       bundled Spotify metadata plugin (+ our patches)
```

## 🕳️ Building from source

Sonolyth targets **Android**. Full setup is in the [contribution guide](CONTRIBUTION.md#your-first-code-contribution); the short version:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor stable -d <android-device-id>
```

## 🔗 Relationship to Spotube

Sonolyth is a personal fork of [Spotube](https://github.com/KRTirtho/spotube), created by [Kingkor Roy Tirtho](https://github.com/KRTirtho) and the Spotube contributors — all upstream credit belongs to them. This fork adds an Android-focused build, a bundled and patched Spotify metadata plugin, and Sonolyth branding. App updates are pulled from upstream as described in [MONOREPO.md](MONOREPO.md).

## 👥 Maintainer

- [Ezra Song](https://github.com/ezrasong) — fork maintainer

Upstream Spotube is maintained by [Kingkor Roy Tirtho](https://github.com/KRTirtho) and the Spotube team.

## 💼 License

Sonolyth inherits Spotube's [BSD-4-Clause](/LICENSE) license. Copyright for the upstream work remains with Kingkor Roy Tirtho and the Spotube authors; fork modifications © Ezra Song.

<details>
  <summary><h3><code>[Click to show]</code> 🙏 Credits</h3></summary>

Sonolyth stands on the same services and open-source packages as Spotube. Key services:

- [Flutter](https://flutter.dev) and [media_kit](https://github.com/media-kit/media-kit) / [MPV](https://mpv.io) — UI & playback
- [MusicBrainz](https://musicbrainz.org) / [ListenBrainz](https://listenbrainz.org) — metadata & scrobbling
- [Piped](https://piped-docs.kavin.rocks/), [Invidious](https://invidious.io/), [yt-dlp](https://github.com/yt-dlp/yt-dlp), [NewPipeExtractor](https://github.com/TeamNewPipe/NewPipeExtractor), [YouTubeExplodeDart](https://github.com/Hexer10/youtube_explode_dart) — audio sources
- [LRCLib](https://lrclib.net/) — synced lyrics
- [SponsorBlock](https://sponsor.ajay.app) — sponsor-segment skipping
- [hetu_script](https://github.com/hetu-script/hetu-script) — the plugin runtime

The full list of third-party packages and their licenses lives in [`pubspec.yaml`](pubspec.yaml) and in upstream Spotube's README.

</details>

<div align="center"><h4>© 2026 Sonolyth — a fork of Spotube</h4></div>
