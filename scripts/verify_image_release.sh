#!/usr/bin/env bash
# Verify the built ARM64 Image advertises exactly the requested UTS release.
set -Eeuo pipefail
usage(){ printf '%s\n' 'Usage: verify_image_release.sh --image FILE --expected RELEASE' >&2; }
image='' expected=''
while (($#)); do
  case "$1" in
    --image) [[ $# -gt 1 ]] || { usage; exit 2; }; image=$2; shift 2;;
    --expected) [[ $# -gt 1 ]] || { usage; exit 2; }; expected=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage; exit 2;;
  esac
done
[[ -s $image ]] || { printf 'image release verification: FAIL: image missing or empty: %s\n' "$image" >&2; exit 1; }
[[ $expected =~ ^[0-9]+\.[0-9]+\.[0-9]+-[^[:space:]+]+$ ]] || { printf 'image release verification: FAIL: invalid expected release: %s\n' "$expected" >&2; exit 1; }
command -v file >/dev/null 2>&1 || { echo 'image release verification: FAIL: file command missing' >&2; exit 1; }
command -v strings >/dev/null 2>&1 || { echo 'image release verification: FAIL: strings command missing' >&2; exit 1; }
format=$(file -b "$image")
[[ $format == *'Linux kernel ARM64 boot executable Image'* ]] || { printf 'image release verification: FAIL: unexpected format: %s\n' "$format" >&2; exit 1; }
mapfile -t releases < <(strings -a "$image" | awk '$1 == "Linux" && $2 == "version" && $3 != "" { print $3 }' | LC_ALL=C sort -u)
((${#releases[@]} == 1)) || { printf 'image release verification: FAIL: expected one Linux version, found %s: %s\n' "${#releases[@]}" "${releases[*]:-none}" >&2; exit 1; }
actual=${releases[0]}
[[ $actual == "$expected" ]] || { printf 'image release verification: FAIL: expected=%s actual=%s\n' "$expected" "$actual" >&2; exit 1; }
[[ $actual != *+ && $actual != *-dirty ]] || { printf 'image release verification: FAIL: forbidden suffix in %s\n' "$actual" >&2; exit 1; }
printf 'image release verification: PASS (format=%s; Linux version %s)\n' "$format" "$actual"
