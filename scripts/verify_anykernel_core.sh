#!/usr/bin/env bash
# Check device templates against the pinned AnyKernel3 core interface.
set -Eeuo pipefail
usage(){ printf '%s\n' 'Usage: verify_anykernel_core.sh --core FILE --template FILE...' >&2; }
core=; templates=()
while (($#)); do
 case "$1" in
  --core) [[ $# -gt 1 ]] || { usage; exit 2; }; core=$2; shift 2;;
  --template) [[ $# -gt 1 ]] || { usage; exit 2; }; templates+=("$2"); shift 2;;
  -h|--help) usage; exit 0;; *) echo "unknown option: $1" >&2; usage; exit 2;;
 esac
done
[[ -r $core ]] || { echo "AnyKernel core missing: $core" >&2; exit 1; }
((${#templates[@]} > 0)) || { echo 'at least one template is required' >&2; exit 2; }
for fn in 'split_boot' 'flash_boot' 'setup_ak' 'ui_print'; do grep -Eq "^[[:space:]]*${fn}[[:space:]]*\(\)[[:space:]]*\{" "$core" || { echo "AnyKernel core missing function: $fn" >&2; exit 1; }; done
for var in BLOCK IS_SLOT_DEVICE RAMDISK_COMPRESSION PATCH_VBMETA_FLAG NO_BLOCK_DISPLAY; do
 grep -Eq "^[[:space:]]*${var}=" "${templates[0]}" || { echo "template missing upstream variable: $var" >&2; exit 1; }
done
for template in "${templates[@]}"; do
 [[ -r $template ]] || { echo "template missing: $template" >&2; exit 1; }
 grep -Fq '. tools/ak3-core.sh;' "$template" || { echo "template does not source ak3-core.sh: $template" >&2; exit 1; }
 grep -Fq 'split_boot;' "$template" || { echo "template does not call split_boot: $template" >&2; exit 1; }
 grep -Fq 'flash_boot;' "$template" || { echo "template does not call flash_boot: $template" >&2; exit 1; }
 if grep -Eq '(^|[[:space:]])(block|is_slot_device|ramdisk_compression|patch_vbmeta_flag|no_block_display)=' "$template"; then echo "template uses obsolete lowercase core variable: $template" >&2; exit 1; fi
done
printf 'AnyKernel core contract: PASS (%s)\n' "$core"
