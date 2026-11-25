#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp="$root/.tmp/kconfig-fixtures"; mkdir -p "$tmp"; trap 'find "$tmp" -mindepth 1 -maxdepth 1 -exec rm -rf {} +' EXIT
make_cfg(){ cat "$root/configs/bakasu_stealth.fragment" "$root/configs/gki_extras.fragment" >> "$1"; cat >> "$1" <<'CFG'
CONFIG_DEBUG_FS=y
CONFIG_KPROBES=y
CONFIG_FTRACE=y
CONFIG_AUDIT=y
CONFIG_PRINTK=y
CFG
}
good="$tmp/good.config"; make_cfg "$good"
"$root/scripts/verify_kconfig.sh" --config "$good" --branch aosp-gki >/dev/null
badlog="$tmp/bad-log.config"; sed 's/^# CONFIG_KSU_SUSFS_ENABLE_LOG is not set$/CONFIG_KSU_SUSFS_ENABLE_LOG=y/' "$good" > "$badlog"
if "$root/scripts/verify_kconfig.sh" --config "$badlog" --branch aosp-gki >/dev/null 2>&1; then echo 'ENABLE_LOG negative fixture unexpectedly passed' >&2; exit 1; fi
baddbg="$tmp/bad-debugfs.config"; sed 's/^CONFIG_DEBUG_FS=y$/# CONFIG_DEBUG_FS is not set/' "$good" > "$baddbg"
if "$root/scripts/verify_kconfig.sh" --config "$baddbg" --branch aosp-gki >/dev/null 2>&1; then echo 'DEBUG_FS negative fixture unexpectedly passed' >&2; exit 1; fi
printf 'kconfig fixtures: PASS\n'
