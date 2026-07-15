#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
font_dir="/usr/local/share/fonts/maple-mono-$MAPLE_MONO_VERSION"

if should_install "$font_dir"; then
  log "Installing Maple Mono NF CN $MAPLE_MONO_VERSION"
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/maple-mono.zip"
  github_download_asset \
    subframe7536/maple-font \
    "v$MAPLE_MONO_VERSION" \
    '^MapleMono-NF-CN-unhinted\.zip$' \
    "$archive"
  mkdir -p "$tmp/font"
  unzip -q "$archive" -d "$tmp/font"
  as_root rm -rf "$font_dir"
  as_root mkdir -p "$font_dir"
  font_count=$(find "$tmp/font" -type f \( -iname '*.ttf' -o -iname '*.otf' \) | wc -l)
  [[ "$font_count" -gt 0 ]] || die 'Maple Mono archive contained no TTF/OTF files'
  find "$tmp/font" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 | \
    as_root xargs -0 -r -I{} cp -f '{}' "$font_dir/"
  as_root chmod -R a+rX "$font_dir"
else
  log "Maple Mono $MAPLE_MONO_VERSION is already installed"
fi

as_root fc-cache -f
fc-match 'Maple Mono NF CN' || true
log 'Maple Mono font installed inside the container'
