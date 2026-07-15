#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
group=$(id -gn "$TARGET_USER")

log "Installing Rust toolchain '$RUST_TOOLCHAIN' for $TARGET_USER"
if [[ ! -x "$home/.cargo/bin/rustup" ]]; then
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  curl_download https://sh.rustup.rs "$tmp/rustup-init.sh"
  as_root install -o "$TARGET_USER" -g "$group" -m 0755 "$tmp/rustup-init.sh" "$tmp/rustup-init-user.sh"
  run_as_target env HOME="$home" sh "$tmp/rustup-init-user.sh" \
    -y --profile default --default-toolchain "$RUST_TOOLCHAIN"
else
  run_as_target env HOME="$home" "$home/.cargo/bin/rustup" update "$RUST_TOOLCHAIN"
  run_as_target env HOME="$home" "$home/.cargo/bin/rustup" default "$RUST_TOOLCHAIN"
fi

run_as_target env HOME="$home" "$home/.cargo/bin/rustup" component add rustfmt clippy rust-src

log "Installing nvm $NVM_VERSION and Node.js $NODE_VERSION"
nvm_dir="$home/.nvm"
if [[ ! -d "$nvm_dir/.git" ]]; then
  run_as_target git clone --depth 1 --branch "v$NVM_VERSION" \
    https://github.com/nvm-sh/nvm.git "$nvm_dir"
else
  run_as_target git -C "$nvm_dir" fetch --depth 1 origin "refs/tags/v$NVM_VERSION:refs/tags/v$NVM_VERSION"
  run_as_target git -C "$nvm_dir" checkout -f "v$NVM_VERSION"
fi

node_script=$(mktemp)
cat > "$node_script" <<EOF_NODE
#!/usr/bin/env bash
set -Eeuo pipefail
export HOME="$home"
export NVM_DIR="$nvm_dir"
# shellcheck disable=SC1090
source "\$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use "$NODE_VERSION"
npm install -g "npm@$NPM_VERSION"
corepack enable || true
node --version
npm --version
EOF_NODE
as_root chown "$TARGET_USER:$group" "$node_script"
as_root chmod 0755 "$node_script"
run_as_target env HOME="$home" bash "$node_script"
rm -f "$node_script"
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
log 'Rust, Cargo, NVM, Node.js and npm installed'
