#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
arch=$(architecture)
home=$(target_home)
group=$(id -gn "$TARGET_USER")

install_uv() {
  local prefix="/opt/uv/$UV_VERSION"
  should_install "$prefix/bin/uv" || return 0

  local tmp archive target uv_bin uvx_bin
  tmp=$(make_temp_dir)
  archive="$tmp/uv.tar.gz"
  case "$arch" in
    x86_64) target=x86_64-unknown-linux-gnu ;;
    aarch64) target=aarch64-unknown-linux-gnu ;;
  esac

  github_download_asset astral-sh/uv "$UV_VERSION" \
    "^uv-${target}\\.tar\\.gz$" "$archive"
  tar -xzf "$archive" -C "$tmp"
  uv_bin=$(find "$tmp" -type f -name uv -perm -u+x | head -n 1)
  uvx_bin=$(find "$tmp" -type f -name uvx -perm -u+x | head -n 1)
  [[ -n "$uv_bin" && -n "$uvx_bin" ]] || die 'uv/uvx binaries were not found after extraction'

  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  as_root install -m 0755 "$uv_bin" "$prefix/bin/uv"
  as_root install -m 0755 "$uvx_bin" "$prefix/bin/uvx"
  rm -rf "$tmp"
}

install_ruff() {
  local prefix="/opt/ruff/$RUFF_VERSION"
  should_install "$prefix/bin/ruff" || return 0

  local tmp archive target binary
  tmp=$(make_temp_dir)
  archive="$tmp/ruff.tar.gz"
  case "$arch" in
    x86_64) target=x86_64-unknown-linux-gnu ;;
    aarch64) target=aarch64-unknown-linux-gnu ;;
  esac

  github_download_asset astral-sh/ruff "$RUFF_VERSION" \
    "^ruff-${target}\\.tar\\.gz$" "$archive"
  tar -xzf "$archive" -C "$tmp"
  binary=$(find "$tmp" -type f -name ruff -perm -u+x | head -n 1)
  [[ -n "$binary" ]] || die 'ruff binary was not found after extraction'

  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  as_root install -m 0755 "$binary" "$prefix/bin/ruff"
  rm -rf "$tmp"
}

log "Installing uv $UV_VERSION"
install_uv
link_system_binary "/opt/uv/$UV_VERSION/bin/uv" uv
link_system_binary "/opt/uv/$UV_VERSION/bin/uvx" uvx

log "Installing Ruff $RUFF_VERSION"
install_ruff
link_system_binary "/opt/ruff/$RUFF_VERSION/bin/ruff" ruff

log "Installing pre-commit $PRE_COMMIT_VERSION with uv"
as_root install -o "$TARGET_USER" -g "$group" -d \
  "$home/.cache/uv" \
  "$home/.cache/ruff" \
  "$home/.cache/pre-commit" \
  "$home/.local/bin" \
  "$home/.local/share/uv/tools" \
  "$home/.local/share/dev-deploy/completions"

run_as_target env \
  HOME="$home" \
  PATH="/usr/local/bin:$home/.local/bin:$PATH" \
  UV_CACHE_DIR="$home/.cache/uv" \
  UV_TOOL_DIR="$home/.local/share/uv/tools" \
  UV_TOOL_BIN_DIR="$home/.local/bin" \
  uv tool install --force "pre-commit==$PRE_COMMIT_VERSION"

link_system_binary "$home/.local/bin/pre-commit" pre-commit

completion_dir="$home/.local/share/dev-deploy/completions"
completion_script=$(mktemp)
cat > "$completion_script" <<EOF_COMPLETIONS
#!/usr/bin/env bash
set -Eeuo pipefail
export HOME="$home"
mkdir -p "$completion_dir"
uv generate-shell-completion bash > "$completion_dir/uv.bash"
uv generate-shell-completion zsh > "$completion_dir/uv.zsh"
ruff generate-shell-completion bash > "$completion_dir/ruff.bash"
ruff generate-shell-completion zsh > "$completion_dir/ruff.zsh"
EOF_COMPLETIONS
as_root chown "$TARGET_USER:$group" "$completion_script"
as_root chmod 0755 "$completion_script"
run_as_target env HOME="$home" PATH="/usr/local/bin:$home/.local/bin:$PATH" bash "$completion_script"
rm -f "$completion_script"

log 'uv, Ruff and pre-commit installed and configured'
