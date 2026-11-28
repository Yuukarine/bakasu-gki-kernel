#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/oneplus-runtime.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
profile="$root/configs/abi/ace3v-cn01-16.0.3.500"
# Real binary and real additional cellular inputs, never substitute import CRCs.
bash "$root/scripts/verify_radio_abi.sh" --kernel "$profile/radio-kernel-evidence.symvers" > "$tmp/radio.out"
grep -Fq 'PASS (imports=2309 modules=43 missing_provider=0 missing_symbol=0 changed_crc=0)' "$tmp/radio.out"
sed '1d' "$profile/radio-kernel-evidence.symvers" > "$tmp/missing.symvers"
if bash "$root/scripts/verify_radio_abi.sh" --kernel "$tmp/missing.symvers" > "$tmp/missing.out" 2>&1; then echo 'missing radio symbol passed' >&2; exit 1; fi
grep -Fq 'missing_symbol:' "$tmp/missing.out"
awk 'NR == 1 {$1="0x00000000"} {print}' "$profile/radio-kernel-evidence.symvers" > "$tmp/drift.symvers"
if bash "$root/scripts/verify_radio_abi.sh" --kernel "$tmp/drift.symvers" > "$tmp/drift.out" 2>&1; then echo 'radio CRC drift passed' >&2; exit 1; fi
grep -Fq 'changed_crc:' "$tmp/drift.out"
cat "$root/configs/bakasu_stealth.fragment" "$root/configs/oneplus_extras.fragment" > "$tmp/good.config"
printf 'CONFIG_DEBUG_FS=y\nCONFIG_KPROBES=y\nCONFIG_FTRACE=y\nCONFIG_AUDIT=y\nCONFIG_PRINTK=y\n' >> "$tmp/good.config"
"$root/scripts/verify_kconfig.sh" --config "$tmp/good.config" --branch oneplus-ogki
for flag in CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_IP6_NF_TARGET_MASQUERADE CONFIG_BPF_STREAM_PARSER; do
  sed "s/^$flag=y$/# $flag is not set/" "$tmp/good.config" > "$tmp/bad.config"
  if "$root/scripts/verify_kconfig.sh" --config "$tmp/bad.config" --branch oneplus-ogki > "$tmp/bad.out" 2>&1; then echo "dropped $flag passed" >&2; exit 1; fi
  grep -Fq "fragment mismatch $flag=n, expected y" "$tmp/bad.out"
done
python3 - "$root" <<'PY'
from pathlib import Path
import sys,yaml
r=Path(sys.argv[1]); steps=yaml.safe_load((r/'.github/workflows/build-oneplus.yml').read_text())['jobs']['build']['steps']
prepare=next(i for i,s in enumerate(steps) if s.get('name')=='Prepare verified Android toolchain')
first_make=next(i for i,s in enumerate(steps) if 'make -C' in s.get('run',''))
assert prepare < first_make
assert any('scripts/verify_radio_abi.sh --kernel Module.symvers' in s.get('run','') for s in steps)
assert 'clang lld llvm' not in next(s['run'] for s in steps if s.get('name')=='Install kernel build dependencies')
PY
# An arbitrary cache label must fail before any download/build.
if TOOLCHAIN_ID=ubuntu-clang bash "$root/scripts/prepare_oneplus_toolchain.sh" --cache-dir "$tmp/toolchain" > "$tmp/identity.out" 2>&1; then echo 'fake toolchain identity passed' >&2; exit 1; fi
grep -Fq 'unsupported OnePlus toolchain identity' "$tmp/identity.out"
printf 'OnePlus runtime/toolchain/cellular fixtures: PASS\n'
