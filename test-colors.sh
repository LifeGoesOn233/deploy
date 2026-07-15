#!/usr/bin/env bash
set -Eeuo pipefail

printf 'TERM=%s\n' "${TERM:-unset}"
printf 'COLORTERM=%s\n\n' "${COLORTERM:-unset}"

printf 'Standard and bright ANSI colors:\n'
for code in {30..37} {90..97}; do
  printf '\033[%sm %3s \033[0m' "$code" "$code"
done
printf '\n\n256-color palette:\n'
for i in $(seq 0 255); do
  printf '\033[48;5;%sm %3s \033[0m' "$i" "$i"
  if (((i + 1) % 16 == 0)); then
    printf '\n'
  fi
done

printf '\nTrue-color gradient:\n'
for i in $(seq 0 76); do
  r=$((255 - i * 255 / 76))
  g=$((i * 510 / 76))
  ((g > 255)) && g=$((510 - g))
  b=$((i * 255 / 76))
  printf '\033[48;2;%s;%s;%sm \033[0m' "$r" "$g" "$b"
done
printf '\n'
