# Sonolyth monorepo

Sonolyth is a fork of [Spotube](https://github.com/KRTirtho/spotube) that bundles
its edited Spotify metadata plugin in the same repository, so the app and the
plugin are versioned together and both stay easy to update from upstream.

## Layout

```
sonolyth/                              the app — fork of KRTirtho/spotube
  lib/  android/  assets/  ...
  plugins/
    spotube-plugin-spotify/           git subtree of sonic-liberation/spotube-plugin-spotify @ main
      src/  plugin.json
      dependencies/
        hetu_otp_util/                git subtree @ pinned 7790606  (third-party, unedited)
        hetu_spotify_gql_client/      git subtree @ pinned 32f3a26  (carries our flatten patch)
```

Everything is vendored with `git subtree` — one `git clone`, no submodule init.
Our edits (e.g. the folder-flatten fix) are normal commits in this repo.

## Git remotes

| remote     | points at                       | use                        |
| ---------- | ------------------------------- | -------------------------- |
| `origin`   | `github.com/ezrasong/sonolyth`  | this fork (push here)      |
| `upstream` | `github.com/KRTirtho/spotube`   | pull app updates from here |

After a fresh `git clone` of `origin`, add the upstream remote once:

```bash
git remote add upstream https://github.com/KRTirtho/spotube.git
```

## Updating from upstream

**App (Spotube):**
```bash
git fetch upstream
git merge upstream/master        # or: git rebase upstream/master
```

**Spotify plugin (top-level):**
```bash
git subtree pull --prefix plugins/spotube-plugin-spotify \
  https://github.com/sonic-liberation/spotube-plugin-spotify.git main --squash
```

**⚠️ gql client is pinned on purpose.** `hetu_spotify_gql_client` is pinned to
commit `32f3a26` because that revision ships the Hetu assets
(`lib/assets/hetu/spotify_gql_api_client.ht`) the plugin imports. Upstream `main`
has since migrated the gql client to TypeScript and **no longer ships those Hetu
files** — pulling `main` will break the plugin build. Only bump this pin when the
plugin's upstream realigns with a newer gql client revision. To bump deliberately:
```bash
git subtree pull --prefix plugins/spotube-plugin-spotify/dependencies/hetu_spotify_gql_client \
  https://github.com/sonic-liberation/hetu_spotify_gql_client.git <known-good-commit> --squash
# then re-apply the flatten patch (below) if it was overwritten
```

## Our plugin patch

`dependencies/hetu_spotify_gql_client/lib/assets/hetu/user.ht` sets
`"flatten": true` (3×: savedPlaylists / savedAlbums / savedArtists) so items
inside Spotify folders are returned instead of being dropped.

## Rebuilding the `.smplug`

The hetu compiler must match the app's `hetu_script 0.4.2+1`. Dart is at
`.tooling/flutter/bin/cache/dart-sdk/bin/dart.exe`.

```bash
# one-time: activate the matching compiler
dart pub global activate hetu_script_dev_tools 0.1.0+2

# from the plugin dir
cd plugins/spotube-plugin-spotify
dart pub global run hetu_script_dev_tools:cli_tool compile src/plugin.ht build/plugin.out
```

Package the `.smplug` (the bundled `zip` is missing on Windows — use PowerShell):
```powershell
# plugin.json + plugin.out + assets/logo.png must sit at the archive ROOT
Compress-Archive -Path build\plugin.out, plugin.json, assets\logo.png -DestinationPath build\plugin.zip -Force
Move-Item build\plugin.zip build\sonolyth-spotify.smplug -Force
```

Keep `name`/`author` in `plugin.json` unchanged so the plugin slug + Spotify auth
persist across reinstalls. Install via Settings → Plugins → Upload, or push to the
device first (`adb -t 11 push ...\sonolyth-spotify.smplug /sdcard/Download/`).
