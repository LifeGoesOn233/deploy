#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
group=$(id -gn "$TARGET_USER")
config_dir="$home/.config/tmux"
repo_dir="$config_dir/oh-my-tmux"
main_conf="$config_dir/tmux.conf"
local_conf="$config_dir/tmux.conf.local"

log "Installing Oh my tmux! for $TARGET_USER"
run_as_target mkdir -p "$config_dir"

if [[ -d "$repo_dir/.git" ]]; then
  current_origin=$(run_as_target git -C "$repo_dir" remote get-url origin)
  [[ "$current_origin" == "$OH_MY_TMUX_REPO" ]] || \
    die "Unexpected Oh my tmux! origin: $current_origin"
else
  if [[ -e "$repo_dir" ]]; then
    die "$repo_dir exists but is not a Git checkout"
  fi
  run_as_target git clone --filter=blob:none "$OH_MY_TMUX_REPO" "$repo_dir"
fi

run_as_target git -C "$repo_dir" fetch --depth 1 origin "$OH_MY_TMUX_REF"
run_as_target git -C "$repo_dir" checkout -f FETCH_HEAD

if [[ -e "$main_conf" && ! -L "$main_conf" ]]; then
  backup="${main_conf}.before-dev-deploy.$(date +%Y%m%d%H%M%S)"
  warn "Backing up existing $main_conf to $backup"
  run_as_target mv "$main_conf" "$backup"
fi
run_as_target ln -sfn "$repo_dir/.tmux.conf" "$main_conf"

if [[ ! -f "$local_conf" ]]; then
  run_as_target cp "$repo_dir/.tmux.conf.local" "$local_conf"
fi

TMUX_LOCAL_BLOCK=$(cat <<'TMUX_LOCAL'
# Keep new windows and panes in the current working directory.
tmux_conf_new_window_retain_current_path=true
tmux_conf_new_pane_retain_current_path=true

# Maple Mono NF CN includes these Powerline separators.
tmux_conf_theme_left_separator_main='\uE0B0'
tmux_conf_theme_left_separator_sub='\uE0B1'
tmux_conf_theme_right_separator_main='\uE0B2'
tmux_conf_theme_right_separator_sub='\uE0B3'

# Terminal capabilities required by Neovim, true color and extended keys.
set -g default-terminal "tmux-256color" #!important
set -s extended-keys on #!important
set -as terminal-features ",xterm*:RGB:extkeys" #!important
set -as terminal-features ",xterm-kitty:RGB:extkeys" #!important
set -as terminal-features ",foot*:RGB:extkeys" #!important
set -as terminal-features ",alacritty*:RGB:extkeys" #!important
set -g focus-events on #!important
set -g set-clipboard on #!important
set -g history-limit 100000 #!important
set -g mouse on #!important
setw -g mode-keys vi #!important
TMUX_LOCAL
)
append_user_managed_block "$local_conf" oh-my-tmux "$TMUX_LOCAL_BLOCK"

as_root chown -R "$TARGET_USER:$group" "$config_dir"

log 'Oh my tmux! installed. Restart the tmux server to load it in existing environments.'
