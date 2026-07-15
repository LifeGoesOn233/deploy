#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
arch=$(architecture)
prefix="/opt/neovim/$NEOVIM_VERSION"

if should_install "$prefix/bin/nvim"; then
  log "Installing Neovim $NEOVIM_VERSION"
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/neovim.tar.gz"
  case "$arch" in
    x86_64) asset_arch=x86_64 ;;
    aarch64) asset_arch=arm64 ;;
  esac
  github_download_asset neovim/neovim "v$NEOVIM_VERSION" \
    "^nvim-linux-${asset_arch}\\.tar\\.gz$" "$archive"
  mkdir -p "$tmp/extracted"
  tar -xzf "$archive" -C "$tmp/extracted"
  source_dir=$(find "$tmp/extracted" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [[ -n "$source_dir" ]] || die 'Neovim archive did not contain a top-level directory'
  install_tree_to_opt "$source_dir" neovim "$NEOVIM_VERSION"
else
  log "Neovim $NEOVIM_VERSION is already installed"
fi

link_system_binary "$prefix/bin/nvim" nvim
link_system_binary "$prefix/bin/nvim" vim
link_system_binary "$prefix/bin/nvim" vi
log 'Neovim installed'
