#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_ubuntu
log 'Generating English and Simplified Chinese UTF-8 locales'

as_root touch /etc/locale.gen
as_root sed -i \
  -e 's/^[#[:space:]]*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
  -e 's/^[#[:space:]]*zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' \
  /etc/locale.gen

grep -qxF 'en_US.UTF-8 UTF-8' /etc/locale.gen || \
  echo 'en_US.UTF-8 UTF-8' | as_root tee -a /etc/locale.gen >/dev/null
grep -qxF 'zh_CN.UTF-8 UTF-8' /etc/locale.gen || \
  echo 'zh_CN.UTF-8 UTF-8' | as_root tee -a /etc/locale.gen >/dev/null

as_root locale-gen en_US.UTF-8 zh_CN.UTF-8

as_root tee /etc/default/locale >/dev/null <<'LOCALE'
LANG=en_US.UTF-8
LANGUAGE=en_US:en
LC_ALL=en_US.UTF-8
LOCALE

as_root tee /etc/profile.d/10-dev-locale.sh >/dev/null <<'LOCALE_ENV'
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
LOCALE_ENV
as_root chmod 0644 /etc/profile.d/10-dev-locale.sh

as_root fc-cache -f
log 'Locale configured: English UI/formatting with full UTF-8 Chinese support'
