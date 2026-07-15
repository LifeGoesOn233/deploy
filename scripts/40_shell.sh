#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
prefix="/opt/zsh/$ZSH_VERSION"

if should_install "$prefix/bin/zsh"; then
  log "Building zsh $ZSH_VERSION"
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/zsh.tar.xz"
  curl_download_any "$archive" \
    "https://downloads.sourceforge.net/project/zsh/zsh/$ZSH_VERSION/zsh-$ZSH_VERSION.tar.xz" \
    "https://sourceforge.net/projects/zsh/files/zsh/$ZSH_VERSION/zsh-$ZSH_VERSION.tar.xz/download" \
    "https://www.zsh.org/pub/zsh-$ZSH_VERSION.tar.xz"
  xz -t "$archive"
  tar -xJf "$archive" -C "$tmp"
  [[ -x "$tmp/zsh-$ZSH_VERSION/configure" ]] || \
    die "The zsh source archive is invalid or missing configure: $archive"
  pushd "$tmp/zsh-$ZSH_VERSION" >/dev/null
  ./configure \
    --prefix="$prefix" \
    --enable-multibyte \
    --enable-pcre \
    --with-tcsetpgrp
  make -j"$BUILD_JOBS"
  as_root make install
  popd >/dev/null
else
  log "zsh $ZSH_VERSION is already installed"
fi

link_system_binary "$prefix/bin/zsh" zsh
if ! grep -qxF '/usr/local/bin/zsh' /etc/shells; then
  echo '/usr/local/bin/zsh' | as_root tee -a /etc/shells >/dev/null
fi

omz="$home/.oh-my-zsh"
if [[ ! -d "$omz/.git" ]]; then
  log "Installing Oh My Zsh for $TARGET_USER"
  run_as_target git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
else
  log 'Updating Oh My Zsh checkout'
  run_as_target git -C "$omz" fetch --depth 1 origin "$OH_MY_ZSH_REF"
  run_as_target git -C "$omz" checkout -f FETCH_HEAD
fi

if [[ "$OH_MY_ZSH_REF" != master ]]; then
  run_as_target git -C "$omz" fetch --depth 1 origin "$OH_MY_ZSH_REF"
  run_as_target git -C "$omz" checkout -f FETCH_HEAD
fi

zshrc="$home/.zshrc"
[[ -f "$zshrc" ]] || as_root install -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" -m 0644 /dev/null "$zshrc"

SHELL_BLOCK='export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git fzf)
zstyle ":omz:update" mode disabled
source "$ZSH/oh-my-zsh.sh"'
append_user_managed_block "$zshrc" oh-my-zsh "$SHELL_BLOCK"

if [[ "$CHANGE_DEFAULT_SHELL" == 1 ]]; then
  log "Changing $TARGET_USER login shell to /usr/local/bin/zsh"
  as_root usermod -s /usr/local/bin/zsh "$TARGET_USER"
fi

log 'zsh and Oh My Zsh configured'
