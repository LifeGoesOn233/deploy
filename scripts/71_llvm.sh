#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
log "Installing LLVM/Clang stable major $LLVM_VERSION from apt.llvm.org"

tmp=$(make_temp_dir)
trap 'rm -rf "$tmp"' EXIT
curl_download https://apt.llvm.org/llvm.sh "$tmp/llvm.sh"
chmod 0755 "$tmp/llvm.sh"
as_root "$tmp/llvm.sh" "$LLVM_VERSION"
as_root apt-get update

# Install both the compiler-facing tools and the versioned LLVM utilities. The
# apt.llvm.org packages intentionally expose most commands with a major suffix
# (for example clangd-21 and llvm-ar-21).
apt_install \
  "clang-$LLVM_VERSION" \
  "clang-tools-$LLVM_VERSION" \
  "clangd-$LLVM_VERSION" \
  "clang-format-$LLVM_VERSION" \
  "clang-tidy-$LLVM_VERSION" \
  "llvm-$LLVM_VERSION" \
  "llvm-$LLVM_VERSION-tools" \
  "lld-$LLVM_VERSION" \
  "lldb-$LLVM_VERSION"

if [[ "$LLVM_VERSION" =~ ^[0-9]+$ ]]; then
  llvm_priority=$((LLVM_VERSION * 10 + 1))
else
  llvm_priority=210
fi

# Register a private alternatives group whose public link lives in
# /usr/local/bin. This avoids taking ownership of distribution-managed links in
# /usr/bin while still ensuring the unversioned command wins in the normal PATH.
# It also upgrades direct symlinks created by older versions of this bundle.
register_llvm_alternative() {
  local command_name=$1
  local candidate=$2
  local safe_name group link current_target

  if [[ ! -x "$candidate" ]]; then
    warn "LLVM command is unavailable and will not be linked: $candidate"
    return 0
  fi

  safe_name=${command_name//+/x}
  safe_name=${safe_name//./-}
  safe_name=${safe_name//_/-}
  group="dev-deploy-llvm-$safe_name"
  link="/usr/local/bin/$command_name"

  if ! command -v update-alternatives >/dev/null 2>&1; then
    warn "update-alternatives is unavailable; using a direct symlink for $command_name"
    link_system_binary "$candidate" "$command_name"
    return 0
  fi

  # A previous release used direct /usr/local/bin symlinks. Remove only
  # symlinks, never an unrelated regular file supplied by the user.
  if [[ -L "$link" ]]; then
    current_target=$(readlink "$link" || true)
    if [[ "$current_target" != "/etc/alternatives/$group" ]]; then
      as_root rm -f "$link"
    fi
  elif [[ -e "$link" ]]; then
    warn "$link is not a symlink; leaving it untouched and skipping $command_name"
    return 0
  fi

  as_root update-alternatives \
    --install "$link" "$group" "$candidate" "$llvm_priority"
  as_root update-alternatives --set "$group" "$candidate"
}

# Public command name followed by its apt.llvm.org versioned binary.
LLVM_ALTERNATIVES=(
  "clang:/usr/bin/clang-$LLVM_VERSION"
  "clang++:/usr/bin/clang++-$LLVM_VERSION"
  "clangd:/usr/bin/clangd-$LLVM_VERSION"
  "clang-format:/usr/bin/clang-format-$LLVM_VERSION"
  "clang-tidy:/usr/bin/clang-tidy-$LLVM_VERSION"
  "clang-check:/usr/bin/clang-check-$LLVM_VERSION"
  "scan-build:/usr/bin/scan-build-$LLVM_VERSION"
  "lld:/usr/bin/lld-$LLVM_VERSION"
  "ld.lld:/usr/bin/ld.lld-$LLVM_VERSION"
  "lldb:/usr/bin/lldb-$LLVM_VERSION"
  "llvm-ar:/usr/bin/llvm-ar-$LLVM_VERSION"
  "llvm-config:/usr/bin/llvm-config-$LLVM_VERSION"
  "llvm-cov:/usr/bin/llvm-cov-$LLVM_VERSION"
  "llvm-nm:/usr/bin/llvm-nm-$LLVM_VERSION"
  "llvm-objcopy:/usr/bin/llvm-objcopy-$LLVM_VERSION"
  "llvm-objdump:/usr/bin/llvm-objdump-$LLVM_VERSION"
  "llvm-ranlib:/usr/bin/llvm-ranlib-$LLVM_VERSION"
  "llvm-readelf:/usr/bin/llvm-readelf-$LLVM_VERSION"
  "llvm-readobj:/usr/bin/llvm-readobj-$LLVM_VERSION"
  "llvm-size:/usr/bin/llvm-size-$LLVM_VERSION"
  "llvm-strings:/usr/bin/llvm-strings-$LLVM_VERSION"
  "llvm-strip:/usr/bin/llvm-strip-$LLVM_VERSION"
  "llvm-symbolizer:/usr/bin/llvm-symbolizer-$LLVM_VERSION"
  "llc:/usr/bin/llc-$LLVM_VERSION"
  "opt:/usr/bin/opt-$LLVM_VERSION"
)

for entry in "${LLVM_ALTERNATIVES[@]}"; do
  register_llvm_alternative "${entry%%:*}" "${entry#*:}"
done

log 'LLVM/Clang tools installed and unversioned commands configured'
