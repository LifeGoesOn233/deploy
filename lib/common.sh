#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_ubuntu() {
  [[ -r /etc/os-release ]] || die '/etc/os-release is missing'
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || die "This bundle supports Ubuntu only; detected ${ID:-unknown}"
  case "${VERSION_ID:-}" in
    20.04|22.04|24.04|25.04|25.10|26.04) ;;
    *) warn "Ubuntu ${VERSION_ID:-unknown} is not in the tested list; continuing." ;;
  esac
}

as_root() {
  if [[ $(id -u) -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die 'Root privileges are required; install sudo or run as root.'
  fi
}

target_home() {
  getent passwd "$TARGET_USER" | cut -d: -f6
}

run_as_target() {
  if [[ $(id -un) == "$TARGET_USER" ]]; then
    "$@"
  elif [[ $(id -u) -eq 0 ]]; then
    runuser -u "$TARGET_USER" -- "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$TARGET_USER" "$@"
  else
    die "Cannot run command as $TARGET_USER"
  fi
}

run_bash_as_target() {
  local command_text=$1
  local home
  home=$(target_home)
  if [[ $(id -un) == "$TARGET_USER" ]]; then
    HOME="$home" bash -lc "$command_text"
  elif [[ $(id -u) -eq 0 ]]; then
    runuser -u "$TARGET_USER" -- env HOME="$home" bash -lc "$command_text"
  else
    sudo -H -u "$TARGET_USER" bash -lc "$command_text"
  fi
}

apt_install() {
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

version_contains() {
  local command_name=$1
  local expected=$2
  shift 2
  command -v "$command_name" >/dev/null 2>&1 || return 1
  "$@" 2>&1 | head -n 1 | grep -Fq "$expected"
}

should_install() {
  local path=$1
  if [[ "$FORCE_REINSTALL" == 1 ]]; then
    return 0
  fi
  [[ ! -e "$path" ]]
}

make_temp_dir() {
  mktemp -d "/tmp/dev-deploy.XXXXXX"
}

curl_download() {
  local url=$1
  local output=$2
  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 20 \
    "$url" -o "$output"
}

curl_download_any() {
  local output=$1
  shift
  local url

  for url in "$@"; do
    log "Trying download: $url"
    rm -f "$output"
    if curl -fL \
      --retry 3 \
      --retry-all-errors \
      --retry-delay 2 \
      --retry-connrefused \
      --connect-timeout 20 \
      "$url" -o "$output"; then
      return 0
    fi
    warn "Download failed, trying the next source: $url"
  done

  rm -f "$output"
  die "All download sources failed for $(basename "$output")"
}

github_download_asset() {
  local repo=$1
  local tag=$2
  local regex=$3
  local output=$4
  local tmp json row name url digest

  tmp=$(make_temp_dir)
  json="$tmp/release.json"
  curl_download "https://api.github.com/repos/$repo/releases/tags/$tag" "$json"

  row=$(jq -r --arg re "$regex" '
    [.assets[] | select(.name | test($re; "i"))]
    | sort_by(.name)
    | .[0]
    | if . == null then empty else [.name, .browser_download_url, (.digest // "")] | @tsv end
  ' "$json")

  [[ -n "$row" ]] || {
    jq -r '.assets[].name' "$json" >&2
    rm -rf "$tmp"
    die "No GitHub asset in $repo tag $tag matched regex: $regex"
  }

  IFS=$'\t' read -r name url digest <<<"$row"
  log "Downloading $name"
  curl_download "$url" "$output"

  if [[ "$digest" == sha256:* ]]; then
    printf '%s  %s\n' "${digest#sha256:}" "$output" | sha256sum -c -
  else
    warn "GitHub did not expose a SHA-256 digest for $name"
  fi

  rm -rf "$tmp"
}

install_tree_to_opt() {
  local source_dir=$1
  local tool=$2
  local version=$3
  local destination="/opt/$tool/$version"

  as_root mkdir -p "/opt/$tool"
  as_root rm -rf "$destination"
  as_root mkdir -p "$destination"
  as_root cp -a "$source_dir"/. "$destination"/
}

link_system_binary() {
  local source=$1
  local name=${2:-$(basename "$source")}
  as_root mkdir -p /usr/local/bin
  as_root ln -sfn "$source" "/usr/local/bin/$name"
}

append_managed_block() {
  local file=$1
  local marker=$2
  local content=$3
  local begin="# >>> dev-deploy:$marker >>>"
  local end="# <<< dev-deploy:$marker <<<"
  local tmp

  tmp=$(mktemp)
  if [[ -f "$file" ]]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "$file" > "$tmp"
  fi

  {
    cat "$tmp"
    printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"
  } > "${tmp}.new"

  if [[ $(id -u) -eq 0 ]]; then
    install -m 0644 "${tmp}.new" "$file"
  else
    sudo install -m 0644 "${tmp}.new" "$file"
  fi
  rm -f "$tmp" "${tmp}.new"
}

append_user_managed_block() {
  local file=$1
  local marker=$2
  local content=$3
  local home owner group tmp begin end
  home=$(target_home)
  owner=$TARGET_USER
  group=$(id -gn "$TARGET_USER")
  begin="# >>> dev-deploy:$marker >>>"
  end="# <<< dev-deploy:$marker <<<"
  tmp=$(mktemp)

  if [[ -f "$file" ]]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "$file" > "$tmp"
  fi

  {
    cat "$tmp"
    printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"
  } > "${tmp}.new"

  as_root install -o "$owner" -g "$group" -m 0644 "${tmp}.new" "$file"
  rm -f "$tmp" "${tmp}.new"
}

architecture() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64\n' ;;
    aarch64|arm64) printf 'aarch64\n' ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
}
