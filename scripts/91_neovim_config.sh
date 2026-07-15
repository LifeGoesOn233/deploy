#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
group=$(id -gn "$TARGET_USER")
config_parent="$home/.config"
config_dir="$config_parent/nvim"

log "Installing Neovim configuration for $TARGET_USER"
run_as_target mkdir -p "$config_parent"

if [[ -d "$config_dir/.git" ]]; then
  current_origin=$(run_as_target git -C "$config_dir" remote get-url origin)
  [[ "$current_origin" == "$NEOVIM_CONFIG_REPO" ]] || \
    die "Unexpected Neovim config origin: $current_origin"

  if run_as_target git -C "$config_dir" diff --quiet && \
     run_as_target git -C "$config_dir" diff --cached --quiet; then
    run_as_target git -C "$config_dir" fetch --depth 1 origin "$NEOVIM_CONFIG_REF"
    run_as_target git -C "$config_dir" checkout -B "$NEOVIM_CONFIG_REF" FETCH_HEAD
  else
    warn "$config_dir has local changes; preserving them and skipping repository update."
  fi
else
  if [[ -e "$config_dir" ]]; then
    backup="${config_dir}.before-dev-deploy.$(date +%Y%m%d%H%M%S)"
    warn "Backing up existing $config_dir to $backup"
    run_as_target mv "$config_dir" "$backup"
  fi
  run_as_target git clone --filter=blob:none --branch "$NEOVIM_CONFIG_REF" \
    "$NEOVIM_CONFIG_REPO" "$config_dir"
fi

as_root chown -R "$TARGET_USER:$group" "$config_dir"

if [[ "$BOOTSTRAP_NEOVIM_CONFIG" == 1 ]]; then
  log 'Synchronizing Neovim plugins from lazy-lock.json'

  node_bin="$home/.nvm/versions/node/v$NODE_VERSION/bin"
  runtime_path="/usr/local/bin:$home/.local/bin:$home/.cargo/bin:$node_bin:/usr/bin:/bin"

  run_as_target env \
    HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    XDG_CACHE_HOME="$home/.cache" \
    PATH="$runtime_path" \
    nvim --headless '+Lazy! sync' +qa

  log 'Installing Mason tools required by the configuration'
  run_as_target env \
    HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    XDG_CACHE_HOME="$home/.cache" \
    PATH="$runtime_path" \
    nvim --headless \
      -c 'MasonInstall codelldb lua-language-server stylua' \
      -c qall

  log 'Installing Tree-sitter parsers required by the configuration'
  run_as_target env \
    HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    XDG_CACHE_HOME="$home/.cache" \
    PATH="$runtime_path" \
    nvim --headless \
      -c "lua require('nvim-treesitter').install({'c','cpp','lua','python','cmake','json','yaml','toml','markdown','markdown_inline'}):wait(300000)" \
      -c qall

  log 'Running a Neovim headless startup smoke test'
  run_as_target env \
    HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    XDG_CACHE_HOME="$home/.cache" \
    PATH="$runtime_path" \
    nvim --headless -c qall
fi

log 'Neovim configuration installed'
