#!/bin/sh
# POSIX AnyKernel3 safety/metadata gate for BakaSU OGKI and GKI.
set -u

ak3_die() { printf '%s\n' "anykernel: $*" >&2; exit 1; }
ak3_truthy() { case "${1:-}" in 1|y|Y|yes|true|TRUE) return 0;; esac; return 1; }
ak3_exists() { [ -e "$1" ] || [ -b "$1" ]; }
ak3_norm_slot() {
  case "${1:-}" in
    "") AK3_SLOT_SUFFIX=; return 0;;
    a|-a|_a) AK3_SLOT_SUFFIX=_a;;
    b|-b|_b) AK3_SLOT_SUFFIX=_b;;
    *) ak3_die "invalid slot suffix: $1";;
  esac
}
ak3_roots() {
  printf '%s\n' "${AK3_PARTITION_ROOT:-/dev/block/by-name}"
  printf '%s\n' "${AK3_BOOTDEVICE_ROOT:-/dev/block/bootdevice/by-name}"
}
ak3_part_exists() {
  name=$1
  while IFS= read -r root; do [ -n "$root" ] && ak3_exists "$root/$name" && return 0; done <<EOF_ROOTS
$(ak3_roots)
EOF_ROOTS
  return 1
}
ak3_part_path() {
  name=$1
  while IFS= read -r root; do
    if [ -n "$root" ] && ak3_exists "$root/$name"; then printf '%s\n' "$root/$name"; return 0; fi
  done <<EOF_ROOTS
$(ak3_roots)
EOF_ROOTS
  return 1
}

ak3_resolve_slot() {
  requested_slot=${AK3_SLOT_SUFFIX:-}
  AK3_RESOLVER_SOURCE=none
  AK3_AB=0
  AK3_SLOT_SUFFIX=
  if [ -n "$requested_slot" ]; then
    ak3_norm_slot "$requested_slot"; AK3_RESOLVER_SOURCE=dry-run; AK3_AB=1; return 0
  fi
  if [ -n "${AK3_CORE_SLOT_SUFFIX:-}" ]; then
    ak3_norm_slot "$AK3_CORE_SLOT_SUFFIX"; AK3_RESOLVER_SOURCE=ak3-core; AK3_AB=1; return 0
  fi
  if [ -n "${AK3_GETPROP_FILE:-}" ] && [ -r "$AK3_GETPROP_FILE" ]; then
    value=$(sed -n 's/.*ro\.boot\.slot_suffix[=:][[:space:]]*\(_[ab]\).*/\1/p; s/.*ro\.boot\.slot[=:][[:space:]]*\([ab]\).*/_\1/p' "$AK3_GETPROP_FILE" | head -n 1)
    if [ -n "$value" ]; then ak3_norm_slot "$value"; AK3_RESOLVER_SOURCE=getprop; AK3_AB=1; return 0; fi
  fi
  if [ -n "${AK3_CMDLINE_FILE:-}" ] && [ -r "$AK3_CMDLINE_FILE" ]; then
    value=$(sed -n 's/.*androidboot\.slot_suffix=\(_[ab]\).*/\1/p' "$AK3_CMDLINE_FILE" | head -n 1)
    if [ -n "$value" ]; then ak3_norm_slot "$value"; AK3_RESOLVER_SOURCE=cmdline; AK3_AB=1; return 0; fi
  fi
  a=0; b=0
  if ak3_part_exists boot_a || ak3_part_exists init_boot_a; then a=1; fi
  if ak3_part_exists boot_b || ak3_part_exists init_boot_b; then b=1; fi
  if [ "$a" = 1 ] || [ "$b" = 1 ]; then
    AK3_AB=1; AK3_RESOLVER_SOURCE=partition
    if [ "$a" = 1 ] && [ "$b" != 1 ]; then AK3_SLOT_SUFFIX=_a; fi
    if [ "$b" = 1 ] && [ "$a" != 1 ]; then AK3_SLOT_SUFFIX=_b; fi
  else
    AK3_SLOT_SUFFIX=; AK3_RESOLVER_SOURCE=none
  fi
}

ak3_page_size() {
  if [ -n "${AK3_PAGE_SIZE:-}" ]; then
    AK3_PAGE_SIZE_SOURCE=dry-run
  else
    value=
    if command -v getconf >/dev/null 2>&1; then value=$(getconf PAGESIZE 2>/dev/null || :); fi
    case "$value" in
      4096|16384|4k|16k) AK3_PAGE_SIZE=$value; AK3_PAGE_SIZE_SOURCE='getconf';;
      *) value=;;
    esac
    if [ -z "$value" ]; then
      smaps=${AK3_SMAPS_FILE:-/proc/self/smaps}
      [ -r "$smaps" ] || ak3_die "page size unavailable: getconf and smaps missing"
      # Ignore hugepage VMAs; only the two supported base page sizes are valid.
      values=$(awk '/^KernelPageSize:[[:space:]]+[0-9]+[[:space:]]+kB/ { if ($2 == 4 || $2 == 16) print $2 * 1024 }' "$smaps" | sort -nu)
      count=$(printf '%s\n' "$values" | awk 'NF { n++ } END { print n+0 }')
      [ "$count" -eq 1 ] || ak3_die "ambiguous or invalid smaps page size"
      AK3_PAGE_SIZE=$(printf '%s\n' "$values" | awk 'NF { print; exit }')
      AK3_PAGE_SIZE_SOURCE=smaps
    fi
  fi
  case "$AK3_PAGE_SIZE" in 4k) AK3_PAGE_SIZE=4096;; 16k) AK3_PAGE_SIZE=16384;; esac
  case "$AK3_PAGE_SIZE" in 4096|16384) :;; *) ak3_die "unsupported page size: $AK3_PAGE_SIZE";; esac
}

ak3_numeric_sublevel() { printf '%s\n' "$1" | sed -n 's/^[0-9][0-9]*\.[0-9][0-9]*\.\([0-9][0-9]*\).*/\1/p'; }
ak3_check_release() {
  actual=${AK3_UNAME_R:-}
  [ -n "$actual" ] || actual=$(uname -r 2>/dev/null || :)
  [ -n "$actual" ] || ak3_die "unable to determine uname -r"
  if [ -n "${AK3_EXPECTED_UNAME_R:-}" ] && [ "$actual" != "$AK3_EXPECTED_UNAME_R" ]; then ak3_die "uname -r mismatch: expected=$AK3_EXPECTED_UNAME_R actual=$actual"; fi
  if [ -n "${AK3_EXPECTED_KMI:-}" ]; then
    case "$AK3_EXPECTED_KMI" in
      android13-5.15|android14-6.1|android15-6.6|android16-6.12) :;;
      *) ak3_die "unsupported KMI generation: $AK3_EXPECTED_KMI";;
    esac
    kmi=${AK3_RUNTIME_KMI:-${AK3_KMI:-}}
    if [ -z "$kmi" ]; then
      gen=$(printf '%s\n' "$actual" | sed -n 's/.*\(android[0-9][0-9]*\)-[0-9][0-9]*.*/\1/p')
      line=$(printf '%s\n' "$actual" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
      [ -n "$gen" ] && [ -n "$line" ] && kmi=$gen-$line
    fi
    [ "$kmi" = "$AK3_EXPECTED_KMI" ] || ak3_die "KMI mismatch: expected=$AK3_EXPECTED_KMI actual=${kmi:-unknown}"
    case "$AK3_EXPECTED_KMI" in
      android15-*|android16-*)
        case "$AK3_PAGE_SIZE:$actual" in
          4096:*-4k|16384:*-16k) :;;
          *) ak3_die "KMI page-size suffix mismatch: page_size=$AK3_PAGE_SIZE uname=$actual";;
        esac;;
    esac
  fi
  if [ -n "${AK3_STOCK_SUBLEVEL:-}" ]; then
    built=$(ak3_numeric_sublevel "$actual"); [ -n "$built" ] || ak3_die "cannot parse built sublevel"
    stock=$AK3_STOCK_SUBLEVEL
    case "$stock" in *.*) stock=$(ak3_numeric_sublevel "$stock");; esac
    [ -n "$stock" ] || ak3_die "cannot parse stock sublevel"
    [ "$built" -ge "$stock" ] || ak3_die "built sublevel $built is below stock $stock"
  fi
  export AK3_RUNTIME_UNAME_R="$actual"
}

ak3_check_markers() {
  root=${AK3_MARKER_ROOT:-${AK3_FIXTURE_ROOT:-}}
  [ -n "$root" ] || return 0
  for marker in kernelsu.ko ksuinit magiskinit .backup .magisk .backup/.magisk; do
    [ -e "$root/$marker" ] && ak3_die "refusing init_boot marker: $marker"
  done
}
ak3_inspect_init_boot() {
  image=$1
  root=${AK3_MARKER_ROOT:-${AK3_FIXTURE_ROOT:-}}
  if [ -n "$root" ]; then ak3_check_markers; return 0; fi
  magisk=${AK3_MAGISKBOOT:-magiskboot}; command -v "$magisk" >/dev/null 2>&1 || ak3_die "magiskboot not found"
  tmp=${AK3_TMPDIR:-.tmp/anykernel-initboot}; mkdir -p "$tmp"
  (cd "$tmp" && "$magisk" unpack "$image" >/dev/null 2>&1 && mkdir -p ramdisk && (cd ramdisk && "$magisk" cpio ../ramdisk.cpio extract >/dev/null 2>&1)) || ak3_die "init_boot unpack failed"
  AK3_MARKER_ROOT=$tmp/ramdisk ak3_check_markers
}
ak3_unpack_boot() {
  image=$1; magisk=${AK3_MAGISKBOOT:-magiskboot}
  if ak3_truthy "${AK3_DRY_RUN:-0}"; then AK3_KERNEL_FMT=${AK3_KERNEL_FMT_FIXTURE:-raw}; return 0; fi
  command -v "$magisk" >/dev/null 2>&1 || ak3_die "magiskboot not found"
  tmp=${AK3_TMPDIR:-.tmp/anykernel-boot}; mkdir -p "$tmp"
  out=$(cd "$tmp" && "$magisk" unpack "$image" 2>&1) || ak3_die "magiskboot unpack failed: $out"
  AK3_KERNEL_FMT=$(printf '%s\n' "$out" | sed -n 's/.*KERNEL_FMT[=:][[:space:]]*\([^[:space:]]*\).*/\1/p' | tail -n 1)
  [ -n "$AK3_KERNEL_FMT" ] || [ ! -f "$tmp/KERNEL_FMT" ] || AK3_KERNEL_FMT=$(cat "$tmp/KERNEL_FMT")
  [ -n "${AK3_KERNEL_FMT:-}" ] || ak3_die "KERNEL_FMT not produced by magiskboot unpack"
}

ak3_main() {
  ak3_resolve_slot; ak3_page_size; ak3_check_release
  if [ "$AK3_AB" = 1 ]; then
    [ -n "$AK3_SLOT_SUFFIX" ] || ak3_die "A/B device requires active slot suffix"
    ak3_part_exists "boot$AK3_SLOT_SUFFIX" || ak3_die "active boot$AK3_SLOT_SUFFIX partition not found"
  fi
  if [ -n "${AK3_BOOT_IMAGE:-}" ]; then boot=$AK3_BOOT_IMAGE; else boot=$(ak3_part_path "boot${AK3_SLOT_SUFFIX}" 2>/dev/null || :); fi
  if [ -z "$boot" ] || ! ak3_exists "$boot"; then ak3_die "boot partition/image not found"; fi
  init_state=absent; init=
  if [ -n "${AK3_INIT_BOOT_IMAGE:-}" ]; then init=$AK3_INIT_BOOT_IMAGE; elif [ "$AK3_AB" = 1 ]; then init=$(ak3_part_path "init_boot$AK3_SLOT_SUFFIX" 2>/dev/null || :); else init=$(ak3_part_path init_boot 2>/dev/null || :); fi
  if [ -n "$init" ] && ak3_exists "$init"; then init_state=stock-preserved; ak3_inspect_init_boot "$init"; elif [ "$AK3_AB" -eq 1 ]; then
    if ak3_part_exists init_boot_a || ak3_part_exists init_boot_b; then ak3_die "init_boot missing for active slot $AK3_SLOT_SUFFIX"; fi
    printf '%s\n' 'init_boot: absent on A/B device, inspection skipped'
  else printf '%s\n' 'init_boot: absent, inspection skipped'; fi
  ak3_unpack_boot "$boot"
  printf 'resolver_source=%s slot_suffix=%s page_size=%s page_size_source=%s kernel_fmt=%s boot=%s init_boot=%s\n' "$AK3_RESOLVER_SOURCE" "${AK3_SLOT_SUFFIX:-none}" "$AK3_PAGE_SIZE" "$AK3_PAGE_SIZE_SOURCE" "${AK3_KERNEL_FMT:-unknown}" "$boot" "$init_state"
}

if ! ak3_truthy "${AK3_LIB_ONLY:-0}"; then ak3_main "$@"; fi
