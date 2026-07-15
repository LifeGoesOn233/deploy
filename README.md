# Ubuntu Development Container Deploy

A modular, repeatable installer for an existing Ubuntu container. It does not require a Dockerfile.

The default configuration keeps interfaces, messages, dates, numbers, and sorting in English (`en_US.UTF-8`) while generating `zh_CN.UTF-8` and installing CJK fonts for full Chinese text support.

## Supported systems

- Ubuntu 20.04, 22.04, 24.04, 25.04, 25.10, and 26.04
- Linux x86_64 and arm64/aarch64
- Root containers and normal users with `sudo`

## Pinned versions

Versions are declared at the top of `deploy.sh` and can be overridden with environment variables.

| Tool | Version/channel |
|---|---:|
| Maple Mono NF CN | 7.9 |
| fzf | 0.74.0 |
| ripgrep | 15.1.0 |
| fd | 10.4.2 |
| tmux | 3.7b |
| zsh | 5.9.2 |
| Oh My Zsh | master, resolved at deployment |
| Oh my tmux! | master, resolved at deployment |
| Neovim | 0.12.4 |
| Neovim configuration | LifeGoesOn233/neovim `main`, resolved at deployment |
| Git | 2.55.0 |
| CMake | 4.3.3 |
| Ninja | 1.13.2 |
| LLVM/Clang | 21 stable branch |
| GDB | 17.2 |
| tree-sitter CLI | 0.26.11 |
| Rust | stable channel |
| nvm | 0.40.5 |
| Node.js | 24.18.0 LTS |
| npm | 12.0.1 |
| lazygit | 0.63.0 |
| Yazi | 26.5.6 |
| OpenAI Codex CLI | 0.144.4 |
| codex-acp | 0.16.0 |
| Git LFS | 3.7.1 |
| uv | 0.11.28 |
| Ruff | 0.15.21 |
| ccache | 4.13.6 |
| bat | 0.26.1 |
| eza | 0.23.5 |
| pre-commit | 4.6.0 |

## Quick start

Inside a root container:

```bash
chmod +x deploy.sh
./deploy.sh
exec /usr/local/bin/zsh -l
```

For a normal Ubuntu user:

```bash
chmod +x deploy.sh
sudo ./deploy.sh --user "$USER"
```

Then log out and back in, or start the configured shell explicitly:

```bash
exec /usr/local/bin/zsh -l
```

## Modules

```text
scripts/00_base.sh         apt dependencies and useful diagnostics
scripts/10_locale.sh       English default locale plus Chinese UTF-8 support
scripts/20_terminal.sh     tmux and 24-bit color configuration
scripts/21_oh_my_tmux.sh   Oh my tmux! user configuration
scripts/30_font.sh         Maple Mono NF CN and font cache
scripts/40_shell.sh        zsh, Oh My Zsh, and login shell
scripts/50_runtimes.sh     Rust/Cargo, nvm, Node.js, and npm
scripts/51_python_tools.sh uv, Ruff, pre-commit, and shell completions
scripts/60_cli.sh          fzf, rg, fd, tree-sitter, lazygit, and Yazi
scripts/61_cli_extras.sh   bat, eza, and user configuration
scripts/70_build_tools.sh  Git, CMake, and Ninja
scripts/71_llvm.sh         versioned LLVM/Clang packages plus unversioned update-alternatives links
scripts/72_gdb.sh          GDB built from the official source release
                           (system GMP/MPFR are auto-detected; do not pass bare --with-gmp/--with-mpfr)
scripts/73_ccache.sh       ccache binary, cache policy, and CMake launchers
scripts/74_git_lfs.sh      Git LFS binary and target-user filter initialization
scripts/80_neovim.sh       official Neovim release tarball
scripts/90_ai_tools.sh     Codex CLI and codex-acp
scripts/91_neovim_config.sh LifeGoesOn233/neovim, Lazy plugins, Mason tools, parsers
scripts/95_environment.sh  PATH, NVM, Cargo, fzf, Yazi, editor, and locale setup
scripts/99_verify.sh       version and environment validation
```

List modules:

```bash
./deploy.sh --list
```

Run one module:

```bash
./deploy.sh --only neovim
./deploy.sh --only locale
```

Skip a module:

```bash
./deploy.sh --skip gdb
```

Force reinstallation:

```bash
./deploy.sh --force
```

Do not change the login shell:

```bash
./deploy.sh --no-chsh
```

## Resume after a failed module

The installer is idempotent. If a network or build step fails, rerun the failed module and then continue with the remaining deployment:

```bash
./deploy.sh --only shell
./deploy.sh
```

The zsh module uses the current official 5.9.2 source archive and tries the SourceForge download hosts before the zsh.org mirror.

## Override versions or options

Environment variables override the defaults declared in `deploy.sh`:

```bash
NEOVIM_VERSION=0.12.4 \
LLVM_VERSION=21 \
BUILD_JOBS=4 \
./deploy.sh
```

Claude Code is included as an optional installer and disabled by default because it follows the vendor's current native release channel rather than a pinned archive:

```bash
INSTALL_CLAUDE=1 ./deploy.sh
```

## Installation layout

Pinned system tools are installed under versioned paths such as:

```text
/opt/neovim/0.12.4
/opt/tmux/3.7b
/opt/zsh/5.9.2
/opt/cmake/4.3.3
```

Stable command names are linked into:

```text
/usr/local/bin
```

User-scoped tools use:

```text
~/.cargo
~/.rustup
~/.nvm
~/.oh-my-zsh
~/.config/tmux/oh-my-tmux
~/.config/nvim
~/.config/bat
~/.config/ccache
~/.cache/uv
~/.cache/ruff
~/.cache/pre-commit
```

The installer updates both `~/.zshrc` and `~/.bashrc` using managed blocks. Running it repeatedly replaces those blocks instead of appending duplicates.


## Added developer-tool configuration

The bundle configures the added tools conservatively:

- Git LFS runs `git lfs install --skip-repo` for the selected target user. It installs the required global Git filters but does not modify repository attributes.
- `uv` and Ruff use user-owned caches under `~/.cache`; generated Bash and Zsh completions are loaded by the managed shell blocks.
- `pre-commit` is installed with `uv tool install`. Hooks are not enabled globally; each repository still opts in with `pre-commit install`.
- ccache uses a 20 GB compressed cache under `~/.cache/ccache`. CMake C, C++, and CUDA compiler launcher environment variables point to ccache.
- LLVM tools are installed with versioned apt.llvm.org names and exposed through `/usr/local/bin` using private `update-alternatives` groups, so commands such as `clangd`, `clang-format`, `clang++`, `lldb`, and `llvm-ar` resolve to the pinned LLVM major. Existing unrelated regular files in `/usr/local/bin` are never overwritten.
- bat uses line numbers, Git change markers, headers, automatic paging, and four-column tabs.
- eza does not replace `ls`; the shell configuration only adds `ll`, `la`, `l`, and `tree` aliases.

Useful checks:

```bash
ccache --show-config
ccache --show-stats
git lfs env
uv tool list
pre-commit --version
```

## Verification

Inspect an LLVM alternatives group or its resolved command:

```bash
update-alternatives --display dev-deploy-llvm-clangd
command -v clangd
readlink -f "$(command -v clangd)"
```

Run the complete version check again at any time:

```bash
./deploy.sh --only verify
```

The last verification result is stored at:

```text
/var/lib/dev-deploy/manifest.txt
```

Test ANSI, 256-color, and true-color rendering:

```bash
./test-colors.sh
```

## Font note

Installing Maple Mono in a container makes it available to programs that render fonts inside that container, including GUI applications, browsers, image/PDF renderers, and fontconfig clients. A terminal running on the host still uses the host's font configuration, so the same font must also be installed on the host to select it in Kitty, GNOME Terminal, VS Code, or another host-side terminal.

## Security and reproducibility

- Release versions are pinned in `deploy.sh`.
- GitHub asset SHA-256 digests are verified when GitHub exposes them through the release API.
- Official release archives and official package repositories are used.
- Oh My Zsh and Oh my tmux! are Git checkouts, so their resolved commits are recorded by the verification script.
- The Neovim configuration follows its configured Git ref and preserves a dirty local working tree instead of overwriting it.
