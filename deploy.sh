#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Pinned stable versions (verified 2026-07-15; zsh refreshed 2026-07-15)
# Override any value in the environment before running this script.
# -----------------------------------------------------------------------------
: "${MAPLE_MONO_VERSION:=7.9}"
: "${FZF_VERSION:=0.74.0}"
: "${RIPGREP_VERSION:=15.1.0}"
: "${FD_VERSION:=10.4.2}"
: "${TMUX_VERSION:=3.7b}"
: "${ZSH_VERSION:=5.9.2}"
: "${OH_MY_ZSH_REF:=master}"
: "${OH_MY_TMUX_REPO:=https://github.com/gpakosz/.tmux.git}"
: "${OH_MY_TMUX_REF:=master}"
: "${NEOVIM_VERSION:=0.12.4}"
: "${NEOVIM_CONFIG_REPO:=https://github.com/LifeGoesOn233/neovim.git}"
: "${NEOVIM_CONFIG_REF:=main}"
: "${BOOTSTRAP_NEOVIM_CONFIG:=1}"
: "${GIT_VERSION:=2.55.0}"
: "${CMAKE_VERSION:=4.3.3}"
: "${NINJA_VERSION:=1.13.2}"
: "${LLVM_VERSION:=21}"
: "${GDB_VERSION:=17.2}"
: "${TREE_SITTER_VERSION:=0.26.11}"
: "${RUST_TOOLCHAIN:=stable}"
: "${NVM_VERSION:=0.40.5}"
: "${NODE_VERSION:=24.18.0}"
: "${NPM_VERSION:=12.0.1}"
: "${LAZYGIT_VERSION:=0.63.0}"
: "${YAZI_VERSION:=26.5.6}"
: "${CODEX_VERSION:=0.144.4}"
: "${CODEX_ACP_VERSION:=0.16.0}"
: "${GIT_LFS_VERSION:=3.7.1}"
: "${UV_VERSION:=0.11.28}"
: "${RUFF_VERSION:=0.15.21}"
: "${CCACHE_VERSION:=4.13.6}"
: "${BAT_VERSION:=0.26.1}"
: "${EZA_VERSION:=0.23.5}"
: "${PRE_COMMIT_VERSION:=4.6.0}"

# Optional extras.
: "${INSTALL_CLAUDE:=0}"
: "${CHANGE_DEFAULT_SHELL:=1}"
: "${FORCE_REINSTALL:=0}"

if [[ -z "${BUILD_JOBS:-}" ]]; then
  BUILD_JOBS=$(nproc)
  ((BUILD_JOBS > 8)) && BUILD_JOBS=8
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${DEPLOY_USER:-${SUDO_USER:-$(id -un)}}"
ONLY=""
SKIP=""
LIST_ONLY=0

usage() {
  cat <<'USAGE'
Usage: ./deploy.sh [options]

Options:
  --user USER       Configure user-owned tools for USER.
  --only PATTERN    Run only scripts whose filename contains PATTERN.
  --skip PATTERN    Skip scripts whose filename contains PATTERN.
  --force           Reinstall even when the requested version is present.
  --no-chsh         Do not change the target user's login shell.
  --list            List modules and exit.
  -h, --help        Show this help.

Examples:
  ./deploy.sh
  sudo ./deploy.sh --user "$USER"
  ./deploy.sh --only locale
  ./deploy.sh --skip gdb
USAGE
}

while (($#)); do
  case "$1" in
    --user)
      TARGET_USER="$2"
      shift 2
      ;;
    --only)
      ONLY="$2"
      shift 2
      ;;
    --skip)
      SKIP="$2"
      shift 2
      ;;
    --force)
      FORCE_REINSTALL=1
      shift
      ;;
    --no-chsh)
      CHANGE_DEFAULT_SHELL=0
      shift
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

MODULES=(
  scripts/00_base.sh
  scripts/10_locale.sh
  scripts/20_terminal.sh
  scripts/21_oh_my_tmux.sh
  scripts/30_font.sh
  scripts/40_shell.sh
  scripts/50_runtimes.sh
  scripts/51_python_tools.sh
  scripts/60_cli.sh
  scripts/61_cli_extras.sh
  scripts/70_build_tools.sh
  scripts/71_llvm.sh
  scripts/72_gdb.sh
  scripts/73_ccache.sh
  scripts/74_git_lfs.sh
  scripts/80_neovim.sh
  scripts/90_ai_tools.sh
  scripts/91_neovim_config.sh
  scripts/95_environment.sh
  scripts/99_verify.sh
)

if ((LIST_ONLY)); then
  printf '%s\n' "${MODULES[@]}"
  exit 0
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Target user does not exist: $TARGET_USER" >&2
  exit 1
fi

export SCRIPT_DIR TARGET_USER FORCE_REINSTALL CHANGE_DEFAULT_SHELL INSTALL_CLAUDE BUILD_JOBS
export MAPLE_MONO_VERSION FZF_VERSION RIPGREP_VERSION FD_VERSION TMUX_VERSION
export ZSH_VERSION OH_MY_ZSH_REF OH_MY_TMUX_REPO OH_MY_TMUX_REF
export NEOVIM_VERSION NEOVIM_CONFIG_REPO NEOVIM_CONFIG_REF BOOTSTRAP_NEOVIM_CONFIG
export GIT_VERSION CMAKE_VERSION
export NINJA_VERSION LLVM_VERSION GDB_VERSION TREE_SITTER_VERSION RUST_TOOLCHAIN
export NVM_VERSION NODE_VERSION NPM_VERSION LAZYGIT_VERSION YAZI_VERSION
export CODEX_VERSION CODEX_ACP_VERSION
export GIT_LFS_VERSION UV_VERSION RUFF_VERSION CCACHE_VERSION BAT_VERSION EZA_VERSION PRE_COMMIT_VERSION

printf '\nUbuntu development environment deploy\n'
printf '  target user: %s\n' "$TARGET_USER"
printf '  force:       %s\n' "$FORCE_REINSTALL"
printf '  build jobs:  %s\n\n' "$BUILD_JOBS"

for module in "${MODULES[@]}"; do
  name="$(basename "$module")"
  if [[ -n "$ONLY" && "$name" != *"$ONLY"* ]]; then
    continue
  fi
  if [[ -n "$SKIP" && "$name" == *"$SKIP"* ]]; then
    echo "==> Skipping $name"
    continue
  fi

  echo
  echo "==============================================================================="
  echo "==> Running $name"
  echo "==============================================================================="
  bash "$SCRIPT_DIR/$module"
done

cat <<'DONE'

Deployment complete.
Open a new login shell so every environment change is loaded:

  exec /usr/local/bin/zsh -l

For a non-root target user, log out and back in if the login shell was changed.
DONE
