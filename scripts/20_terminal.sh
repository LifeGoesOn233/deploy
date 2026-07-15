#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
prefix="/opt/tmux/$TMUX_VERSION"

if should_install "$prefix/bin/tmux"; then
  log "Building tmux $TMUX_VERSION"
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/tmux.tar.gz"
  curl_download "https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz" "$archive"
  tar -xzf "$archive" -C "$tmp"
  pushd "$tmp/tmux-$TMUX_VERSION" >/dev/null
  ./configure --prefix="$prefix"
  make -j"$BUILD_JOBS"
  as_root make install
  popd >/dev/null
else
  log "tmux $TMUX_VERSION is already installed"
fi

link_system_binary "$prefix/bin/tmux" tmux

TMUX_CONFIG='set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB"
set -as terminal-features ",screen-256color:RGB"
set -as terminal-features ",tmux-256color:RGB"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g focus-events on
set -g set-clipboard on
set -g history-limit 100000
set -g mouse on'
append_managed_block /etc/tmux.conf truecolor "$TMUX_CONFIG"

if ! infocmp tmux-256color >/dev/null 2>&1; then
  warn 'tmux-256color terminfo is unavailable; falling back to screen-256color.'
  as_root sed -i 's/tmux-256color/screen-256color/g' /etc/tmux.conf
fi

log 'tmux and true-color terminal configuration installed'
