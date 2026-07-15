#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
home=$(target_home)
[[ -r /etc/profile.d/10-dev-locale.sh ]] && source /etc/profile.d/10-dev-locale.sh
[[ -r /etc/profile.d/90-dev-tools.sh ]] && source /etc/profile.d/90-dev-tools.sh
export HOME="$home"
export PATH="/usr/local/bin:$home/.local/bin:$home/.cargo/bin:$PATH"
export NVM_DIR="$home/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

manifest=$(mktemp)
missing=0

print_value() {
  local label=$1
  shift
  local output
  if output=$("$@" 2>&1); then
    output=$(printf '%s\n' "$output" | head -n 1)
    printf '%-18s %s\n' "$label" "$output" | tee -a "$manifest"
  else
    printf '%-18s %s\n' "$label" 'MISSING/FAILED' | tee -a "$manifest"
    missing=$((missing + 1))
  fi
}

print_shell_value() {
  local label=$1
  local command_text=$2
  local output
  if output=$(bash -lc "$command_text" 2>&1); then
    output=$(printf '%s\n' "$output" | head -n 1)
    printf '%-18s %s\n' "$label" "$output" | tee -a "$manifest"
  else
    printf '%-18s %s\n' "$label" 'MISSING/FAILED' | tee -a "$manifest"
    missing=$((missing + 1))
  fi
}

printf '\nInstalled tool versions\n' | tee "$manifest"
printf '%s\n' '-----------------------' | tee -a "$manifest"
print_value 'zsh' zsh --version
print_value 'tmux' tmux -V
print_value 'neovim' nvim --version
print_value 'git' git --version
print_value 'git-lfs' git lfs version
print_value 'ripgrep' rg --version
print_value 'fd' fd --version
print_value 'cmake' cmake --version
print_value 'ninja' ninja --version
print_value 'clang' clang --version
print_value 'clang++' clang++ --version
print_value 'clangd' clangd --version
print_value 'clang-format' clang-format --version
print_value 'clang-tidy' clang-tidy --version
print_value 'lld' lld --version
print_value 'lldb' lldb --version
print_value 'llvm-ar' llvm-ar --version
print_value 'gdb' gdb --version
print_value 'tree-sitter' tree-sitter --version
print_value 'rustc' rustc --version
print_value 'cargo' cargo --version
print_value 'uv' uv --version
print_value 'ruff' ruff --version
print_value 'pre-commit' pre-commit --version
print_value 'node' node --version
print_value 'npm' npm --version
print_value 'lazygit' lazygit --version
print_value 'codex' codex --version
print_value 'codex-acp' codex-acp --version
print_value 'yazi' yazi --version
print_value 'fzf' fzf --version
print_value 'ccache' ccache --version
print_value 'bat' bat --version
print_value 'eza' eza --version

if [[ -d "$home/.config/tmux/oh-my-tmux/.git" && -L "$home/.config/tmux/tmux.conf" ]]; then
  omt_commit=$(git -C "$home/.config/tmux/oh-my-tmux" rev-parse --short HEAD)
  printf '%-18s %s\n' 'oh-my-tmux' "$omt_commit" | tee -a "$manifest"
else
  printf '%-18s %s\n' 'oh-my-tmux' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi

if [[ -d "$home/.config/nvim/.git" ]]; then
  nvim_config_commit=$(git -C "$home/.config/nvim" rev-parse --short HEAD)
  printf '%-18s %s\n' 'nvim-config' "$nvim_config_commit" | tee -a "$manifest"
else
  printf '%-18s %s\n' 'nvim-config' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi

if [[ -d "$home/.oh-my-zsh/.git" ]]; then
  omz_commit=$(git -C "$home/.oh-my-zsh" rev-parse --short HEAD)
  printf '%-18s %s\n' 'oh-my-zsh' "$omz_commit" | tee -a "$manifest"
else
  printf '%-18s %s\n' 'oh-my-zsh' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi

printf '\nEnvironment checks\n' | tee -a "$manifest"
printf '%s\n' '------------------' | tee -a "$manifest"
printf '%-18s %s\n' 'locale-default' "${LANG:-unset}" | tee -a "$manifest"
if locale -a | grep -qi '^zh_CN\.utf8$'; then
  printf '%-18s %s\n' 'locale-zh_CN' 'available' | tee -a "$manifest"
else
  printf '%-18s %s\n' 'locale-zh_CN' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi
printf '%-18s %s\n' 'COLORTERM' "${COLORTERM:-unset}" | tee -a "$manifest"

for llvm_tool in clang clang++ clangd clang-format clang-tidy lld lldb llvm-ar; do
  llvm_safe_name=${llvm_tool//+/x}
  llvm_safe_name=${llvm_safe_name//./-}
  llvm_safe_name=${llvm_safe_name//_/-}
  llvm_group="dev-deploy-llvm-$llvm_safe_name"
  llvm_value=$(update-alternatives --query "$llvm_group" 2>/dev/null | awk '$1 == "Value:" {print $2}' || true)
  llvm_command=$(command -v "$llvm_tool" 2>/dev/null || true)
  if [[ -n "$llvm_command" && "$llvm_value" == *"-$LLVM_VERSION" ]]; then
    printf '%-18s %s\n' "llvm-link:$llvm_tool" "$llvm_value" | tee -a "$manifest"
  else
    printf '%-18s %s\n' "llvm-link:$llvm_tool" "UNEXPECTED: command=${llvm_command:-missing}, alternative=${llvm_value:-missing}" | tee -a "$manifest"
    missing=$((missing + 1))
  fi
done

if lfs_process=$(run_as_target env HOME="$home" PATH="/usr/local/bin:$PATH" git config --global --get filter.lfs.process 2>/dev/null) && [[ -n "$lfs_process" ]]; then
  printf '%-18s %s\n' 'git-lfs-filter' 'configured' | tee -a "$manifest"
else
  printf '%-18s %s\n' 'git-lfs-filter' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi

if [[ -r "$home/.config/ccache/ccache.conf" ]]; then
  printf '%-18s %s\n' 'ccache-config' "$home/.config/ccache/ccache.conf" | tee -a "$manifest"
else
  printf '%-18s %s\n' 'ccache-config' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi
if fc-list | grep -qi 'Maple Mono'; then
  font_match=$(fc-match 'Maple Mono NF CN' | head -n 1 || true)
  printf '%-18s %s\n' 'Maple Mono' "${font_match:-available}" | tee -a "$manifest"
else
  printf '%-18s %s\n' 'Maple Mono' 'MISSING' | tee -a "$manifest"
  missing=$((missing + 1))
fi

as_root install -m 0644 "$manifest" /var/lib/dev-deploy/manifest.txt
rm -f "$manifest"

if ((missing > 0)); then
  die "$missing required checks failed. See /var/lib/dev-deploy/manifest.txt"
fi

log 'All required checks passed'
