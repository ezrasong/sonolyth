<div align="center">
  <img width="160" src="assets/branding/sonolyth-logo.png" alt="Sonolyth logo">

  <h1>Sonolyth</h1>

An Android music player for lossless streaming, built on your own metadata plugins.<br>
A personal fork of [Spotube](https://github.com/KRTirtho/spotube).

</div>

---

## What it is

Sonolyth separates where the music list comes from and where the audio comes from.

**Metadata** covers your library, playlists, albums, artists and search, and it
is served by plugins. Two are bundled: a patched build of the unofficial Spotify
plugin, and MusicBrainz/ListenBrainz. Any other service can be added by writing
one.

**Audio** is lossless FLAC, from Qobuz, then Tidal, then Deezer. There is no
lossy fallback and no YouTube, so a track neither catalog carries simply does
not play.

## Features

- **Lossless only.** FLAC from Qobuz, Tidal and Deezer, with a per-source
  priority order you control. Nothing is transcoded and nothing drops to a lower
  quality without telling you.
- **Plugin-powered metadata.** Bring any music service through a plugin. The
  bundled Spotify plugin is patched to return items nested inside Spotify
  folders and to retry on rate limits (HTTP 429).
- **Seamless playback.** Crossfade with a real overlap, gapless transitions,
  adaptive buffering, and edge-silence trimming for local files.
- **Lyrics.** Time-synced from LRCLib, and read straight out of the file when a
  FLAC carries its own tags or an `.lrc` sits beside it.
- **Downloads.** Tracks are saved as tagged FLAC and play offline.
- **Local files.** Folders you add are first-class, browsed and queued and
  played like anything else.
- **Connect.** Control playback from another device on the same network.
- **No telemetry**, no diagnostics, no user-data collection. See
  [PRIVACY_POLICY.md](PRIVACY_POLICY.md).

### One thing to expect

Qobuz and Tidal require a one-time human check (a Cloudflare Turnstile) before
they will serve audio. Sonolyth attempts it silently at launch. When that is not
enough the player says so and offers a **Verify lossless** button that opens the
challenge. Until it passes, streaming tracks will not play. Local files and
completed downloads are unaffected.

## Repository layout

Sonolyth is a monorepo. The app and its edited Spotify metadata plugin live in
the same repository and are versioned together. See
[MONOREPO.md](MONOREPO.md) for the full layout, the upstream-sync workflow, and
how to rebuild the plugin.

```
sonolyth/
  lib/  android/  assets/  ...          the app (fork of KRTirtho/spotube)
  plugins/spotube-plugin-spotify/       bundled Spotify metadata plugin (+ our patches)
```

## Building from source

Sonolyth targets **Android only**. The desktop and web platforms Spotube
supports have been removed from this fork. Full setup is in the
[contribution guide](CONTRIBUTION.md#your-first-code-contribution). The short
version:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor stable -d <android-device-id>
```

Two flavors are defined, `stable` and `nightly`, which install side by side.

## Relationship to Spotube

Sonolyth is a personal fork of [Spotube](https://github.com/KRTirtho/spotube),
created by [Kingkor Roy Tirtho](https://github.com/KRTirtho) and the Spotube
contributors. The plugin runtime, the metadata system, routing and much of the
component layer are upstream work, and the credit for them is theirs.

What this fork adds: the lossless audio-source stack and its session handling,
the track matcher, a rebuilt interface, the native FLAC download pipeline, the
crossfade engine, and an Android-only build with the desktop and web platforms
removed. App updates are pulled from upstream as described in
[MONOREPO.md](MONOREPO.md).

## Maintainer

- [Ezra Song](https://github.com/ezrasong), fork maintainer

Upstream Spotube is maintained by [Kingkor Roy
Tirtho](https://github.com/KRTirtho) and the Spotube team.

## License

Sonolyth inherits Spotube's [BSD-4-Clause](/LICENSE) license. Copyright for the
upstream work remains with Kingkor Roy Tirtho and the Spotube authors. Fork
modifications are © Ezra Song.

<details>
  <summary><h3><code>[Click to show]</code> Credits</h3></summary>

Sonolyth stands on the same open-source foundation as Spotube. Key projects and
services:

- [Flutter](https://flutter.dev), [media_kit](https://github.com/media-kit/media-kit) and [mpv](https://mpv.io) for the interface and playback
- [hetu_script](https://github.com/hetu-script/hetu-script) for the plugin runtime
- [MusicBrainz](https://musicbrainz.org) and [ListenBrainz](https://listenbrainz.org) for open metadata and scrobbling
- [LRCLib](https://lrclib.net) for synced lyrics
- [SpotiFLAC-Mobile](https://github.com/zarzet/SpotiFLAC-Mobile) for the lossless source gateway
- [drift](https://drift.simonbinder.eu) for the local database

The full list of third-party packages and their licenses lives in
[`pubspec.yaml`](pubspec.yaml) and in upstream Spotube's README.

</details>

<div align="center"><h4>© 2026 Sonolyth, a fork of Spotube</h4></div>
