#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
group=$(id -gn "$TARGET_USER")
node_bin="$home/.nvm/versions/node/v$NODE_VERSION/bin"

[[ -s "$home/.nvm/nvm.sh" ]] || die 'nvm is not installed; run 50_runtimes.sh first.'

log "Installing OpenAI Codex CLI $CODEX_VERSION"
ai_script=$(mktemp)
cat > "$ai_script" <<EOF_AI
#!/usr/bin/env bash
set -Eeuo pipefail
export HOME="$home"
export NVM_DIR="$home/.nvm"
source "\$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION" >/dev/null
npm install -g "@openai/codex@$CODEX_VERSION"

# codex-acp has existed under two npm scopes. A previous installation can
# leave its executable in the active NVM bin directory even after the package
# metadata has changed or disappeared. npm then aborts with EEXIST instead of
# replacing that stale entry. Select the exact package first, uninstall both
# historical package names, and remove only the managed codex-acp entry before
# installing the requested version.
codex_acp_package=''
if npm view "@agentclientprotocol/codex-acp@$CODEX_ACP_VERSION" version >/dev/null 2>&1; then
  codex_acp_package='@agentclientprotocol/codex-acp'
elif npm view "@zed-industries/codex-acp@$CODEX_ACP_VERSION" version >/dev/null 2>&1; then
  codex_acp_package='@zed-industries/codex-acp'
else
  exit 42
fi

npm uninstall -g \
  '@agentclientprotocol/codex-acp' \
  '@zed-industries/codex-acp' \
  >/dev/null 2>&1 || true

npm_prefix=\$(npm prefix -g)
npm_bin_dir="\$npm_prefix/bin"
case "\$npm_bin_dir" in
  "\$NVM_DIR"/versions/node/*/bin) ;;
  *)
    echo "Refusing to clean unexpected npm bin directory: \$npm_bin_dir" >&2
    exit 43
    ;;
esac
rm -f "\$npm_bin_dir/codex-acp"

npm install -g "\$codex_acp_package@$CODEX_ACP_VERSION"
EOF_AI
as_root chown "$TARGET_USER:$group" "$ai_script"
as_root chmod 0755 "$ai_script"

set +e
run_as_target env HOME="$home" bash "$ai_script"
status=$?
set -e
if [[ $status -ne 0 ]]; then
  if [[ $status -ne 42 ]]; then
    rm -f "$ai_script"
    die 'npm installation of AI tools failed'
  fi

  warn 'No matching codex-acp npm package was found; using the official GitHub release binary.'
  arch=$(architecture)
  tmp=$(make_temp_dir)
  archive="$tmp/codex-acp.tar"
  case "$arch" in
    x86_64) arch_regex='((x86_64|x64).*linux|linux.*(x86_64|x64)).*(tar\.gz|zip)$' ;;
    aarch64) arch_regex='((aarch64|arm64).*linux|linux.*(aarch64|arm64)).*(tar\.gz|zip)$' ;;
  esac
  github_download_asset zed-industries/codex-acp "v$CODEX_ACP_VERSION" "$arch_regex" "$archive"
  mkdir -p "$tmp/extracted"
  if file "$archive" | grep -qi zip; then
    unzip -q "$archive" -d "$tmp/extracted"
  else
    tar -xf "$archive" -C "$tmp/extracted"
  fi
  binary=$(find "$tmp/extracted" -type f -name codex-acp | head -n 1)
  [[ -n "$binary" ]] || die 'codex-acp binary was not found after extraction'
  as_root install -m 0755 "$binary" /usr/local/bin/codex-acp
  rm -rf "$tmp"
fi
rm -f "$ai_script"

[[ -x "$node_bin/codex" ]] && link_system_binary "$node_bin/codex" codex
[[ -x "$node_bin/codex-acp" ]] && link_system_binary "$node_bin/codex-acp" codex-acp

if [[ "$INSTALL_CLAUDE" == 1 ]]; then
  log 'Installing Claude Code using the official native installer'
  claude_script=$(mktemp)
  curl_download https://claude.ai/install.sh "$claude_script"
  as_root chown "$TARGET_USER:$group" "$claude_script"
  run_as_target env HOME="$home" bash "$claude_script"
  rm -f "$claude_script"
  [[ -x "$home/.local/bin/claude" ]] && link_system_binary "$home/.local/bin/claude" claude
fi

log 'AI command-line tools installed'
