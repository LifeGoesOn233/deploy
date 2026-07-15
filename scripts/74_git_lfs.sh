#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
arch=$(architecture)
home=$(target_home)
prefix="/opt/git-lfs/$GIT_LFS_VERSION"

if should_install "$prefix/bin/git-lfs"; then
  log "Installing Git LFS $GIT_LFS_VERSION"
  tmp=$(make_temp_dir)
  archive="$tmp/git-lfs.tar.gz"
  case "$arch" in
    x86_64) asset_arch=amd64 ;;
    aarch64) asset_arch=arm64 ;;
  esac
  github_download_asset git-lfs/git-lfs "v$GIT_LFS_VERSION" \
    "^git-lfs-linux-${asset_arch}-v${GIT_LFS_VERSION}\\.tar\\.gz$" "$archive"
  tar -xzf "$archive" -C "$tmp"
  binary=$(find "$tmp" -type f -name git-lfs -perm -u+x | head -n 1)
  [[ -n "$binary" ]] || die 'git-lfs binary was not found after extraction'
  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  as_root install -m 0755 "$binary" "$prefix/bin/git-lfs"
  rm -rf "$tmp"
else
  log "Git LFS $GIT_LFS_VERSION is already installed"
fi

link_system_binary "$prefix/bin/git-lfs" git-lfs

log "Initializing Git LFS filters for $TARGET_USER"
run_as_target env HOME="$home" PATH="/usr/local/bin:$PATH" git lfs install --skip-repo

log 'Git LFS installed and configured'
