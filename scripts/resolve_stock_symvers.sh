#!/usr/bin/env bash
# Deterministic stock Module.symvers resolver: path -> url -> cache -> prebuilt -> bootstrap.
set -Eeuo pipefail
usage(){ cat <<'USAGE'
Usage: resolve_stock_symvers.sh --output FILE [--input FILE] [--url URL]
       [--cache PATH] [--cache-meta FILE] [--prebuilt FILE] [--bootstrap COMMAND]
       [--expected-cache-key KEY] [--kmi KMI] [--page-size SIZE]
       [--stock-uname RELEASE] [--source-sha SHA] [--toolchain ID]
USAGE
}
out= input=${STOCK_MODULE_SYMVERS_INPUT:-} url=${STOCK_MODULE_SYMVERS_URL:-}
cache=${STOCK_MODULE_SYMVERS_CACHE:-} cache_meta=${STOCK_MODULE_SYMVERS_CACHE_META:-}
prebuilt=${GKI_PREBUILT_MODULE_SYMVERS:-} bootstrap=${BOOTSTRAP_STOCK_SYMVERS:-}
expected_cache_key=${STOCK_MODULE_SYMVERS_CACHE_KEY:-}
expected_kmi=${STOCK_MODULE_SYMVERS_KMI:-} expected_page=${STOCK_MODULE_SYMVERS_PAGE_SIZE:-}
expected_uname=${STOCK_MODULE_SYMVERS_STOCK_UNAME:-} expected_source_sha=${STOCK_MODULE_SYMVERS_SOURCE_SHA:-}
expected_toolchain=${STOCK_MODULE_SYMVERS_TOOLCHAIN:-}
while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0;;
    --output) [[ $# -gt 1 ]] || { echo 'missing output' >&2; exit 2; }; out=$2; shift 2;;
    --input) [[ $# -gt 1 ]] || { echo 'missing input' >&2; exit 2; }; input=$2; shift 2;;
    --url) [[ $# -gt 1 ]] || { echo 'missing url' >&2; exit 2; }; url=$2; shift 2;;
    --cache) [[ $# -gt 1 ]] || { echo 'missing cache' >&2; exit 2; }; cache=$2; shift 2;;
    --cache-meta) [[ $# -gt 1 ]] || { echo 'missing cache metadata' >&2; exit 2; }; cache_meta=$2; shift 2;;
    --prebuilt) [[ $# -gt 1 ]] || { echo 'missing prebuilt' >&2; exit 2; }; prebuilt=$2; shift 2;;
    --bootstrap) [[ $# -gt 1 ]] || { echo 'missing bootstrap command' >&2; exit 2; }; bootstrap=$2; shift 2;;
    --expected-cache-key) expected_cache_key=$2; shift 2;;
    --kmi) expected_kmi=$2; shift 2;;
    --page-size) expected_page=$2; shift 2;;
    --stock-uname) expected_uname=$2; shift 2;;
    --source-sha) expected_source_sha=$2; shift 2;;
    --toolchain) expected_toolchain=$2; shift 2;;
    -*) echo "unknown option: $1" >&2; exit 2;;
    *) if [[ -z $input ]]; then input=$1; elif [[ -z $out ]]; then out=$1; else echo "unexpected argument: $1" >&2; exit 2; fi; shift;;
  esac
done
[[ -n $out ]] || out="${BAKASU_WORK_ROOT:-.tmp}/stock-Module.symvers"
mkdir -p "$(dirname -- "$out")"
resolve_path(){ local p=${1:-}; [[ -d $p ]] && p="$p/Module.symvers"; [[ -f $p ]] && printf '%s\n' "$p"; }
is_valid(){
  local p=$1
  [[ -f $p && -s $p ]] || return 1
  awk 'NF >= 2 && $1 ~ /^0x[[:xdigit:]]+$/ && $2 !~ /^#/ {ok=1} END{exit !ok}' "$p"
}
meta_value(){ local key=$1 file=$2; awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,"",$0); print; exit}' "$file"; }
cache_valid(){
  local p=$1 meta actual key value name pair
  is_valid "$p" || return 1
  if [[ -z $cache_meta ]]; then
    if [[ -d ${cache:-} && -f "$cache/metadata" ]]; then cache_meta="$cache/metadata";
    elif [[ -f "$p.meta" ]]; then cache_meta="$p.meta"; fi
  fi
  [[ -r ${cache_meta:-} ]] || { echo "cache rejected: metadata missing for $p" >&2; return 1; }
  key=$(meta_value cache_key "$cache_meta"); [[ -n $key ]] || { echo 'cache rejected: cache_key missing' >&2; return 1; }
  if [[ -n $expected_cache_key && $key != "$expected_cache_key" ]]; then echo "cache rejected: cache_key mismatch" >&2; return 1; fi
  for pair in "kmi|$expected_kmi" "page_size|$expected_page" "stock_uname|$expected_uname" "source_sha|$expected_source_sha" "toolchain|$expected_toolchain"; do
    name=${pair%%|*}; value=${pair#*|}
    [[ -z $value ]] && continue
    [[ $(meta_value "$name" "$cache_meta") == "$value" ]] || { echo "cache rejected: $name mismatch" >&2; return 1; }
  done
  actual=$(sha256sum "$p" | awk '{print $1}')
  [[ $(meta_value sha256 "$cache_meta") == "$actual" ]] || { echo 'cache rejected: sha256 mismatch' >&2; return 1; }
}
candidate= source= resolver_source=
if [[ -n $input ]] && p=$(resolve_path "$input"); then is_valid "$p" && { candidate=$p; source=path; resolver_source=path; }; fi
if [[ -z $candidate && -n $url ]]; then
  download="${BAKASU_WORK_ROOT:-.tmp}/stock-url-Module.symvers"; mkdir -p "$(dirname -- "$download")"
  command -v curl >/dev/null 2>&1 || { echo 'curl required for stock_module_symvers_url' >&2; exit 1; }
  curl -fsSL "$url" -o "$download"; is_valid "$download" || { echo 'downloaded Module.symvers is invalid' >&2; exit 1; }
  candidate=$download; source=url; resolver_source=url
fi
if [[ -z $candidate ]] && p=$(resolve_path "$cache"); then
  if cache_valid "$p"; then candidate=$p; source=cache; resolver_source=cache; fi
fi
if [[ -z $candidate ]] && p=$(resolve_path "$prebuilt"); then is_valid "$p" && { candidate=$p; source=prebuilt; resolver_source=prebuilt; }; fi
if [[ -z $candidate && -n $bootstrap ]]; then
  boot="${BAKASU_WORK_ROOT:-.tmp}/bootstrap-Module.symvers"; mkdir -p "$(dirname -- "$boot")"
  bash -c "$bootstrap" > "$boot" || { echo 'bootstrap_stock_symvers command failed' >&2; exit 1; }
  is_valid "$boot" || { echo 'bootstrap produced invalid Module.symvers' >&2; exit 1; }
  candidate=$boot; source=bootstrap; resolver_source=bootstrap
fi
[[ -n $candidate ]] || { echo 'stock Module.symvers not found: path/url/cache/prebuilt/bootstrap exhausted' >&2; exit 1; }
cp -- "$candidate" "$out"
sha=$(sha256sum "$out" | awk '{print $1}')
path=$(readlink -f "$out" 2>/dev/null || printf '%s' "$out")
printf 'resolver_source=%s\nsource=%s\npath=%s\nsha256=%s\n' "$resolver_source" "$source" "$path" "$sha"
