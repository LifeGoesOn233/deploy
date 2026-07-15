#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
log 'Refreshing apt metadata'
as_root apt-get update

log 'Installing base packages and build dependencies'
apt_install \
  ca-certificates curl wget git jq \
  tar gzip bzip2 xz-utils unzip zip p7zip-full file less \
  locales language-pack-en language-pack-zh-hans fontconfig fonts-noto-cjk \
  build-essential autoconf automake libtool pkg-config cmake ninja-build \
  bison flex texinfo make patch \
  libevent-dev libncurses-dev libncursesw5-dev libpcre2-dev \
  libssl-dev zlib1g-dev libcurl4-openssl-dev libexpat1-dev gettext \
  libgmp-dev libmpfr-dev libreadline-dev python3-dev python3-venv python3-pip \
  software-properties-common gnupg lsb-release apt-transport-https \
  ncurses-term procps htop lsof strace rsync openssh-client man-db \
  xclip xsel wl-clipboard \
  ffmpeg imagemagick poppler-utils chafa libimage-exiftool-perl mediainfo

# These improve GDB but are not available on every Ubuntu/architecture pair.
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libsource-highlight-dev libbabeltrace-dev libipt-dev || \
  warn 'Some optional GDB libraries were unavailable; GDB will still be built.'

as_root mkdir -p /opt /usr/local/bin /usr/local/share/fonts /var/lib/dev-deploy
log 'Base packages installed'
