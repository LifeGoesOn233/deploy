#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
arch=$(architecture)
home=$(target_home)
group=$(id -gn "$TARGET_USER")

log 'Installing Cargo-based CLI tools: ripgrep, fd, tree-sitter'
cargo_script=$(mktemp)
cat > "$cargo_script" <<EOF_CARGO
#!/usr/bin/env bash
set -Eeuo pipefail
export HOME="$home"
export PATH="\$HOME/.cargo/bin:\$PATH"
source "\$HOME/.cargo/env"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
cargo install --locked --version "$RIPGREP_VERSION" ripgrep
cargo install --locked --version "$FD_VERSION" fd-find
cargo install --locked --version "$TREE_SITTER_VERSION" tree-sitter-cli
EOF_CARGO
as_root chown "$TARGET_USER:$group" "$cargo_script"
as_root chmod 0755 "$cargo_script"
run_as_target env HOME="$home" bash "$cargo_script"
rm -f "$cargo_script"

for tool in rg fd tree-sitter; do
  link_system_binary "$home/.cargo/bin/$tool" "$tool"
done

install_fzf() {
  local prefix="/opt/fzf/$FZF_VERSION"
  should_install "$prefix/bin/fzf" || return 0
  local tmp archive asset_arch
  tmp=$(make_temp_dir)
  archive="$tmp/fzf.tar.gz"
  case "$arch" in
    x86_64) asset_arch=amd64 ;;
    aarch64) asset_arch=arm64 ;;
  esac
  github_download_asset junegunn/fzf "v$FZF_VERSION" \
    "^fzf-$FZF_VERSION-linux_${asset_arch}\\.tar\\.gz$" "$archive"
  mkdir -p "$tmp/bin" "$tmp/source"
  tar -xzf "$archive" -C "$tmp/bin"
  curl_download "https://github.com/junegunn/fzf/archive/refs/tags/v$FZF_VERSION.tar.gz" "$tmp/source.tar.gz"
  tar -xzf "$tmp/source.tar.gz" -C "$tmp/source" --strip-components=1
  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin" "$prefix/shell"
  as_root install -m 0755 "$tmp/bin/fzf" "$prefix/bin/fzf"
  as_root cp -a "$tmp/source/shell"/. "$prefix/shell/"
  rm -rf "$tmp"
}

install_lazygit() {
  local prefix="/opt/lazygit/$LAZYGIT_VERSION"
  should_install "$prefix/bin/lazygit" || return 0
  local tmp archive asset_arch binary
  tmp=$(make_temp_dir)
  archive="$tmp/lazygit.tar.gz"
  case "$arch" in
    x86_64) asset_arch=x86_64 ;;
    aarch64) asset_arch=arm64 ;;
  esac
  github_download_asset jesseduffield/lazygit "v$LAZYGIT_VERSION" \
    "^lazygit_${LAZYGIT_VERSION}_Linux_${asset_arch}\\.tar\\.gz$" "$archive"
  tar -xzf "$archive" -C "$tmp"
  binary=$(find "$tmp" -type f -name lazygit -perm -u+x | head -n 1)
  [[ -n "$binary" ]] || die 'lazygit binary was not found after extraction'
  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  as_root install -m 0755 "$binary" "$prefix/bin/lazygit"
  rm -rf "$tmp"
}

install_yazi() {
  local prefix="/opt/yazi/$YAZI_VERSION"
  should_install "$prefix/bin/yazi" || return 0
  local tmp archive target binary ya_binary
  tmp=$(make_temp_dir)
  archive="$tmp/yazi.zip"
  case "$arch" in
    x86_64) target=x86_64-unknown-linux-gnu ;;
    aarch64) target=aarch64-unknown-linux-gnu ;;
  esac
  github_download_asset sxyazi/yazi "v$YAZI_VERSION" \
    "^yazi-${target}\\.zip$" "$archive"
  unzip -q "$archive" -d "$tmp/extracted"
  binary=$(find "$tmp/extracted" -type f -name yazi | head -n 1)
  ya_binary=$(find "$tmp/extracted" -type f -name ya | head -n 1)
  [[ -n "$binary" && -n "$ya_binary" ]] || die 'yazi/ya binaries were not found after extraction'
  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  as_root install -m 0755 "$binary" "$prefix/bin/yazi"
  as_root install -m 0755 "$ya_binary" "$prefix/bin/ya"
  rm -rf "$tmp"
}

log "Installing fzf $FZF_VERSION"
install_fzf
link_system_binary "/opt/fzf/$FZF_VERSION/bin/fzf" fzf

log "Installing lazygit $LAZYGIT_VERSION"
install_lazygit
link_system_binary "/opt/lazygit/$LAZYGIT_VERSION/bin/lazygit" lazygit

log "Installing yazi $YAZI_VERSION"
install_yazi
link_system_binary "/opt/yazi/$YAZI_VERSION/bin/yazi" yazi
link_system_binary "/opt/yazi/$YAZI_VERSION/bin/ya" ya

log 'Modern CLI tools installed'
