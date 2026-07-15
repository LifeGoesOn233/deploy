#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
source "$HOME/.cargo/env"
require_ubuntu
arch=$(architecture)

install_git() {
  local prefix="/opt/git/$GIT_VERSION"
  should_install "$prefix/bin/git" || return 0
  local tmp archive
  tmp=$(make_temp_dir)
  archive="$tmp/git.tar.xz"
  curl_download "https://www.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.xz" "$archive"
  tar -xJf "$archive" -C "$tmp"
  pushd "$tmp/git-$GIT_VERSION" >/dev/null
  make configure
  ./configure --prefix="$prefix" --with-openssl --with-curl --with-expat
  make -j"$BUILD_JOBS" all
  as_root make install
  popd >/dev/null
  rm -rf "$tmp"
}

install_cmake() {
  local prefix="/opt/cmake/$CMAKE_VERSION"
  should_install "$prefix/bin/cmake" || return 0
  local tmp archive asset_arch source_dir
  tmp=$(make_temp_dir)
  archive="$tmp/cmake.tar.gz"
  case "$arch" in
    x86_64) asset_arch=x86_64 ;;
    aarch64) asset_arch=aarch64 ;;
  esac
  github_download_asset Kitware/CMake "v$CMAKE_VERSION" \
    "^cmake-$CMAKE_VERSION-linux-${asset_arch}\\.tar\\.gz$" "$archive"
  mkdir -p "$tmp/extracted"
  tar -xzf "$archive" -C "$tmp/extracted"
  source_dir=$(find "$tmp/extracted" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [[ -n "$source_dir" ]] || die 'CMake archive did not contain a top-level directory'
  install_tree_to_opt "$source_dir" cmake "$CMAKE_VERSION"
  rm -rf "$tmp"
}

install_ninja() {
  local prefix="/opt/ninja/$NINJA_VERSION"
  should_install "$prefix/bin/ninja" || return 0
  local tmp archive
  tmp=$(make_temp_dir)
  as_root rm -rf "$prefix"
  as_root mkdir -p "$prefix/bin"
  if [[ "$arch" == x86_64 ]]; then
    archive="$tmp/ninja.zip"
    github_download_asset ninja-build/ninja "v$NINJA_VERSION" '^ninja-linux\.zip$' "$archive"
    unzip -q "$archive" -d "$tmp/extracted"
    as_root install -m 0755 "$tmp/extracted/ninja" "$prefix/bin/ninja"
  else
    archive="$tmp/ninja-source.tar.gz"
    curl_download "https://github.com/ninja-build/ninja/archive/refs/tags/v$NINJA_VERSION.tar.gz" "$archive"
    tar -xzf "$archive" -C "$tmp"
    pushd "$tmp/ninja-$NINJA_VERSION" >/dev/null
    python3 configure.py --bootstrap
    as_root install -m 0755 ninja "$prefix/bin/ninja"
    popd >/dev/null
  fi
  rm -rf "$tmp"
}

log "Installing Git $GIT_VERSION"
install_git
link_system_binary "/opt/git/$GIT_VERSION/bin/git" git
link_system_binary "/opt/git/$GIT_VERSION/bin/git-receive-pack" git-receive-pack
link_system_binary "/opt/git/$GIT_VERSION/bin/git-upload-archive" git-upload-archive
link_system_binary "/opt/git/$GIT_VERSION/bin/git-upload-pack" git-upload-pack

log "Installing CMake $CMAKE_VERSION"
install_cmake
for tool in cmake cpack ctest; do
  link_system_binary "/opt/cmake/$CMAKE_VERSION/bin/$tool" "$tool"
done

log "Installing Ninja $NINJA_VERSION"
install_ninja
link_system_binary "/opt/ninja/$NINJA_VERSION/bin/ninja" ninja

log 'Git, CMake and Ninja installed'
