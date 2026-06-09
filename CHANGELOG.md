# Changelog

Sonolyth is an Android-focused fork of [Spotube](https://github.com/KRTirtho/spotube).
This changelog tracks the fork's own changes. For the upstream app's release
history up to **v5.1.2**, see [Spotube's releases](https://github.com/KRTirtho/spotube/releases).

## Sonolyth (unreleased) — based on Spotube v5.1.2

### Added

- Bundle the unofficial Spotify metadata plugin in-repo as git subtrees, so the
  app and plugin are versioned and built together (see [MONOREPO.md](MONOREPO.md)).
- Plugin patch: return playlists, albums, and artists nested inside Spotify
  folders (`flatten: true`) instead of dropping them.
- Plugin patch: retry Spotify requests on HTTP 429 (rate limit) with backoff, so
  album/artist detail pages stop surfacing DioException errors.

### Changed

- Rebrand Spotube → Sonolyth across the app, branding assets, and documentation,
  attributed to Ezra Song.
- Point repository links (about page, update checker, downloads) at
  `github.com/ezrasong/sonolyth`.
- Trim build targets to Android.

### Removed

- Discord link and community widget from the About page.
