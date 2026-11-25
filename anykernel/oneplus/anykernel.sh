#!/bin/sh
# BakaSU AnyKernel3 packaging helper (POSIX sh).  The same script is shipped
# for OGKI and GKI; AK3_FLAVOR identifies the branch for diagnostics.
set -u

ak3_die() { echo "anykernel: $*" >&2; exit 1; }
ak3_note() { echo "anykernel: $*"; }
ak3_truthy() { case "${1:-}" in 1|y|Y|yes|true|TRUE) return 0;; esac; return 1; }
ak3_file() { [ -f "$1" ] || [ -b "$1" ]; }

# Resolve an A/B suffix.  An explicit AK3_SLOT_SUFFIX is intentionally first:
# recovery/getprop state can be stale while the caller's selected slot is not.
ak3_resolve_slot() {
  AK3_RESOLVER_SOURCE=none
  if [ -n "${AK3_SLOT_SUFFIX:-}" ]; then
    case "$AK3_SLOT_SUFFIX" in _a|_b) AK3_SLOT_SUFFIX="$AK3_SLOT_SUFFIX";; *) ak3_die "invalid AK3_SLOT_SUFFIX: $AK3_SLOT_SUFFIX";; esac
    AK3_RESOLVER_SOURCE=AK3_SLOT_SUFFIX; return 0
  fi
  if [ -n "${AK3_GETPROP_FILE:-}" ] && [ -r "$AK3_GETPROP_FILE" ]; then
    value=$(sed -n 's/.*ro\.boot\.slot_suffix[=:][[:space:]]*\(_[ab]\).*/\1/p; s/.*ro\.boot\.slot[=:][[:space:]]*\([ab]\).*/_\1/p' "$AK3_GETPROP_FILE" | head -n1)
    if [ -n "$value" ]; then AK3_SLOT_SUFFIX=$value; AK3_RESOLVER_SOURCE=getprop; return 0; fi
  fi
  if [ -n "${AK3_CMDLINE_FILE:-}" ] && [ -r "$AK3_CMDLINE_FILE" ]; then
    value=$(sed -n 's/.*androidboot\.slot_suffix=\(_[ab]\).*/\1/p' "$AK3_CMDLINE_FILE" | head -n1)
    if [ -n "$value" ]; then AK3_SLOT_SUFFIX=$value; AK3_RESOLVER_SOURCE=cmdline; return 0; fi
  fi
  root=${AK3_PARTITION_ROOT:-/dev/block/by-name}
  a=0; b=0
  [ -e "$root/boot_a" ] || [ -e "$root/init_boot_a" ] && a=1
  [ -e "$root/boot_b" ] || [ -e "$root/init_boot_b" ] && b=1
  if [ "$a" = 1 ] && [ "$b" != 1 ]; then AK3_SLOT_SUFFIX=_a; AK3_RESOLVER_SOURCE=partition; return 0; fi
  if [ "$b" = 1 ] && [ "$a" != 1 ]; then AK3_SLOT_SUFFIX=_b; AK3_RESOLVER_SOURCE=partition; return 0; fi
  AK3_SLOT_SUFFIX=; AK3_RESOLVER_SOURCE=none
}

ak3_page_size() {
  # A dry run is deterministic and must not depend on the host kernel.
  if ak3_truthy "${AK3_DRY_RUN:-0}"; then
    AK3_PAGE_SIZE=${AK3_PAGE_SIZE:-${AK3_PAGE_SIZE_FIXTURE:-4096}}
  elif [ -n "${AK3_PAGE_SIZE:-}" ]; then
    :
  else
    gc= sm=
    if command -v getconf >/dev/null 2>&1; then gc=$(getconf PAGESIZE 2>/dev/null || :); fi
    if [ -n "${AK3_SMAPS_FILE:-}" ] && [ -r "$AK3_SMAPS_FILE" ]; then
      sm=$(sed -n 's/^KernelPageSize:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*kB.*/\1/p' "$AK3_SMAPS_FILE" | sort -u | head -n2 | tr '\n' ' ')
      case "$sm" in *' '*) ak3_die "ambiguous smaps page size: $sm";; esac
      [ -n "$sm" ] && sm=$((sm * 1024))
    fi
    if [ -n "$gc" ] && [ -n "$sm" ] && [ "$gc" != "$sm" ]; then ak3_die "ambiguous page size: getconf=$gc smaps=$sm"; fi
    AK3_PAGE_SIZE=${gc:-${sm:-4096}}
  fi
  case "$AK3_PAGE_SIZE" in 4096|16384|4k|16k) :;; *) ak3_die "unsupported page size: $AK3_PAGE_SIZE";; esac
  case "$AK3_PAGE_SIZE" in 4k) AK3_PAGE_SIZE=4096;; 16k) AK3_PAGE_SIZE=16384;; esac
}

ak3_check_release() {
  actual=${AK3_UNAME_R:-}
  [ -n "$actual" ] || actual=$(uname -r 2>/dev/null || :)
  [ -n "$actual" ] || ak3_die "unable to determine uname -r"
  if [ -n "${AK3_EXPECTED_UNAME_R:-}" ] && [ "$actual" != "$AK3_EXPECTED_UNAME_R" ]; then
    ak3_die "uname -r mismatch: expected=$AK3_EXPECTED_UNAME_R actual=$actual"
  fi
  if [ -n "${AK3_EXPECTED_KMI:-}" ]; then
    kmi=${AK3_RUNTIME_KMI:-${AK3_KMI:-}}
    if [ -z "$kmi" ] && [ -n "${AK3_KMI_FILE:-}" ] && [ -r "$AK3_KMI_FILE" ]; then kmi=$(head -n1 "$AK3_KMI_FILE"); fi
    [ -n "$kmi" ] || kmi=$(printf '%s\n' "$actual" | sed -n 's/.*\(android[0-9][0-9]*-[0-9][0-9]*\).*/\1/p')
    [ "$kmi" = "$AK3_EXPECTED_KMI" ] || ak3_die "KMI mismatch: expected=$AK3_EXPECTED_KMI actual=${kmi:-unknown}"
  fi
  if [ -n "${AK3_EXPECTED_SUBLEVEL:-}" ]; then
    sub=$(printf '%s\n' "$actual" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.\)\([0-9][0-9]*\).*/\2/p')
    [ "$sub" = "$AK3_EXPECTED_SUBLEVEL" ] || ak3_die "sublevel mismatch: expected=$AK3_EXPECTED_SUBLEVEL actual=${sub:-unknown}"
  fi
  AK3_RUNTIME_UNAME_R=$actual
}

ak3_check_markers() {
  root=${AK3_MARKER_ROOT:-${AK3_FIXTURE_ROOT:-}}
  [ -n "$root" ] || return 0
  # Exact paths only.  Similar names (for example foo.backup) are harmless.
  for marker in .backup .magisk data/.backup data/.magisk metadata/.backup metadata/.magisk; do
    if [ -e "$root/$marker" ] && ! ak3_truthy "${AK3_ALLOW_MARKERS:-0}"; then
      case "$marker" in
        *.magisk) ak3_truthy "${AK3_ALLOW_MAGISK:-0}" && continue ;;
        *.backup) ak3_truthy "${AK3_ALLOW_BACKUP:-0}" && continue ;;
      esac
      ak3_die "refusing marker: $marker"
    fi
  done
}

ak3_unpack() {
  image=$1
  AK3_KERNEL_FMT=${AK3_KERNEL_FMT:-}
  [ -n "$AK3_KERNEL_FMT" ] && return 0
  magisk=${AK3_MAGISKBOOT:-magiskboot}
  if ak3_truthy "${AK3_DRY_RUN:-0}"; then AK3_KERNEL_FMT=${AK3_KERNEL_FMT_FIXTURE:-raw}; return 0; fi
  command -v "$magisk" >/dev/null 2>&1 || ak3_die "magiskboot not found"
  out=$("$magisk" unpack "$image" 2>&1) || ak3_die "magiskboot unpack failed: $out"
  AK3_KERNEL_FMT=$(printf '%s\n' "$out" | sed -n 's/.*KERNEL_FMT[=:][[:space:]]*\([^[:space:]]*\).*/\1/p' | tail -n1)
  if [ -z "$AK3_KERNEL_FMT" ]; then
    AK3_KERNEL_FMT=$("$magisk" --format "$image" 2>/dev/null || :)
  fi
  [ -n "$AK3_KERNEL_FMT" ] || AK3_KERNEL_FMT=raw
  export AK3_KERNEL_FMT
}

ak3_main() {
  ak3_resolve_slot
  ak3_page_size
  ak3_check_release
  ak3_check_markers
  root=${AK3_PARTITION_ROOT:-/dev/block/by-name}
  boot=${AK3_BOOT_IMAGE:-$root/boot${AK3_SLOT_SUFFIX}}
  init=${AK3_INIT_BOOT_IMAGE:-$root/init_boot${AK3_SLOT_SUFFIX}}
  if ! ak3_truthy "${AK3_DRY_RUN:-0}" && ! ak3_file "$boot"; then ak3_die "boot image not found: $boot"; fi
  # init_boot is stock: never replace it.  It is optional only when both
  # slot-specific init_boot partitions are absent.
  init_state=absent
  if ak3_file "$init"; then init_state=stock-preserved
  elif [ -n "$AK3_SLOT_SUFFIX" ] && { [ -e "$root/init_boot_a" ] || [ -e "$root/init_boot_b" ]; }; then ak3_die "init_boot missing for active slot $AK3_SLOT_SUFFIX";
  fi
  ak3_unpack "$boot"
  printf 'resolver_source=%s slot_suffix=%s page_size=%s kernel_fmt=%s boot=%s init_boot=%s\n' "$AK3_RESOLVER_SOURCE" "${AK3_SLOT_SUFFIX:-none}" "$AK3_PAGE_SIZE" "$AK3_KERNEL_FMT" "$boot" "$init_state"
}

# AK3_LIB_ONLY lets fixture tests source this file without running packaging.
if ! ak3_truthy "${AK3_LIB_ONLY:-0}"; then ak3_main "$@"; fi
