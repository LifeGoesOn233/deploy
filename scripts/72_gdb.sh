#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
prefix="/opt/gdb/$GDB_VERSION"

if should_install "$prefix/bin/gdb"; then
  log "Building GDB $GDB_VERSION"
  tmp=$(make_temp_dir)
  trap 'rm -rf "$tmp"' EXIT
  archive="$tmp/gdb.tar.xz"
  curl_download "https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.xz" "$archive"
  tar -xJf "$archive" -C "$tmp"
  mkdir -p "$tmp/build"
  pushd "$tmp/build" >/dev/null

  # GMP and MPFR are mandatory GDB dependencies. The development packages are
  # installed by 00_base.sh, so the top-level configure script can find them in
  # the standard Ubuntu include/library paths.
  #
  # Do not pass bare --with-gmp or --with-mpfr here. Those options take a
  # directory argument; a bare option is interpreted as the literal value
  # "yes", which later makes libtool search in yes/lib and breaks the link.
  configure_args=(
    "--prefix=$prefix"
    "--with-python=/usr/bin/python3"
    --with-system-readline
    --with-expat
    --disable-werror
  )

  "$tmp/gdb-$GDB_VERSION/configure" "${configure_args[@]}"
  make -j"$BUILD_JOBS"
  as_root make install
  popd >/dev/null
else
  log "GDB $GDB_VERSION is already installed"
fi

link_system_binary "$prefix/bin/gdb" gdb
[[ -x "$prefix/bin/gdbserver" ]] && link_system_binary "$prefix/bin/gdbserver" gdbserver
log 'GDB installed'
