#!/usr/bin/env bash
# Verify generated values, never force compiler/pahole capability Kconfig symbols.
set -Eeuo pipefail
[[ $# == 1 && -f $1 ]] || { echo 'usage: verify_oneplus_toolchain_config.sh .config' >&2; exit 1; }
for expected in CONFIG_CC_IS_CLANG=y CONFIG_CLANG_VERSION=170002 CONFIG_AS_VERSION=170002 CONFIG_LD_IS_LLD=y CONFIG_LLD_VERSION=170002 CONFIG_PAHOLE_VERSION=123; do
  grep -Fxq "$expected" "$1" || { echo "OnePlus toolchain config: FAIL expected $expected" >&2; exit 1; }
done
if grep -Fxq CONFIG_PAHOLE_HAS_LANG_EXCLUDE=y "$1"; then echo 'OnePlus toolchain config: FAIL unexpected pahole >=1.24 capability' >&2; exit 1; fi
printf 'OnePlus toolchain config: PASS (clang=170002 lld=170002 pahole=123)\n'
