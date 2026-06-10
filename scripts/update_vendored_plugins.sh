#!/usr/bin/env bash
# Update the vendored Spotify metadata plugin (and its dependencies) that live
# in this monorepo.
#
# These directories are NOT git submodules — they were imported with
# `git subtree` so a plain `git clone` gets the full source with no
# `git submodule init/update` step. That also means there is no `.gitmodules`
# file and no submodule entry in `.git/config`; if you ever see a stray
# `[submodule]` section in `.git/config`, remove it with:
#     git config --remove-section submodule
#
# To pull upstream changes into a vendored subtree, run this script. It adds a
# temporary remote, fetches it, and `git subtree pull --squash`es it into the
# right prefix. Each pull creates a single squashed merge commit.
#
# NOTE: the fork's Spotify plugin has diverged well past upstream
# (sonic-liberation is frozen around 0.2.2 while the vendored copy is 0.2.16+),
# so a blind subtree pull will likely conflict. Treat upstream pulls as a
# manual, reviewed merge — not an automatic sync.
set -euo pipefail

declare -A PREFIXES=(
  ["plugins/spotube-plugin-spotify"]="https://github.com/sonic-liberation/spotube-plugin-spotify.git|main"
  ["plugins/spotube-plugin-spotify/dependencies/hetu_otp_util"]="https://github.com/sonic-liberation/hetu_otp_util.git|main"
  ["plugins/spotube-plugin-spotify/dependencies/hetu_spotify_gql_client"]="https://github.com/sonic-liberation/hetu_spotify_gql_client.git|main"
)

pull_subtree() {
  local prefix="$1" url="$2" branch="$3"
  echo ">> Pulling $url ($branch) into $prefix"
  git subtree pull --prefix="$prefix" "$url" "$branch" --squash
}

target="${1:-all}"
for prefix in "${!PREFIXES[@]}"; do
  IFS='|' read -r url branch <<<"${PREFIXES[$prefix]}"
  if [[ "$target" == "all" || "$target" == "$prefix" ]]; then
    pull_subtree "$prefix" "$url" "$branch"
  fi
done

echo "Done. Rebuild the bundled plugin afterwards:"
echo "  (cd plugins/spotube-plugin-spotify && make compile && make archive)"
echo "  cp plugins/spotube-plugin-spotify/build/plugin.smplug \\"
echo "     assets/plugins/spotube-plugin-spotify/plugin.smplug"
