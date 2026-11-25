#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

make_config() {
  local branch=$1 out=$2
  cat "$ROOT/configs/shared.config" "$ROOT/configs/$branch.config" > "$out"
  cat >> "$out" <<'CFG'
CONFIG_DEBUG_FS=y
CONFIG_KPROBES=y
CONFIG_FTRACE=y
CONFIG_AUDIT=y
CONFIG_PRINTK=y
CFG
}

aosp="$tmp/aosp.config"; oneplus="$tmp/oneplus.config"
make_config aosp-gki "$aosp"
make_config oneplus-ogki "$oneplus"
"$ROOT/scripts/verify_kconfig.sh" --config "$aosp" --branch aosp-gki >/dev/null
"$ROOT/scripts/verify_kconfig.sh" --config "$oneplus" --branch oneplus-ogki >/dev/null
sed -i 's/^CONFIG_PRINTK=y$/CONFIG_PRINTK=n/' "$oneplus"
if "$ROOT/scripts/verify_kconfig.sh" --config "$oneplus" --branch oneplus-ogki >/dev/null 2>&1; then
  printf 'expected protected-feature failure\n' >&2
  exit 1
fi
printf 'kconfig fixtures: PASS\n'
