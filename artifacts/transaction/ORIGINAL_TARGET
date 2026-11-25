#!/usr/bin/env bash
# Resolve stock Module.symvers in deterministic priority order.
set -euo pipefail
usage() { cat <<'USAGE'
Usage: resolve_stock_symvers.sh [--output FILE] [--input FILE] [--cache FILE]
       [--prebuilt FILE] [--bootstrap COMMAND]
Priority: explicit input, Actions cache, GKI prebuilt, bootstrap_stock_symvers.
USAGE
}
out= input=${STOCK_MODULE_SYMVERS_INPUT:-} cache=${STOCK_MODULE_SYMVERS_CACHE:-} prebuilt=${GKI_PREBUILT_MODULE_SYMVERS:-} bootstrap=${BOOTSTRAP_STOCK_SYMVERS:-}
while (($#)); do case $1 in
  --help|-h) usage; exit 0;;
  --output) out=$2; shift 2;; --input) input=$2; shift 2;; --cache) cache=$2; shift 2;;
  --prebuilt) prebuilt=$2; shift 2;; --bootstrap) bootstrap=$2; shift 2;;
  -*) echo "unknown option: $1" >&2; usage >&2; exit 2;;
  *) if [[ -z $input ]]; then input=$1; elif [[ $out == ${RUNNER_TEMP:-${TMPDIR:-/tmp}}/stock-Module.symvers ]]; then out=$1; else echo "unexpected argument: $1" >&2; exit 2; fi; shift;;
esac; done
[[ -n $out ]] || out=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/stock-Module.symvers
is_valid() { [[ -f $1 && -s $1 ]] && grep -qEv '^[[:space:]]*(#|$)' "$1"; }
source= candidate=
for pair in "explicit:${input}" "cache:${cache}" "gki-prebuilt:${prebuilt}"; do
  name=${pair%%:*}; path=${pair#*:}
  if [[ -n $path ]] && is_valid "$path"; then source=$name; candidate=$path; break; fi
done
if [[ -z $candidate && -n $bootstrap ]]; then
  tmp=$(mktemp "${TMPDIR:-/tmp}/bootstrap-symvers.XXXXXX"); trap 'rm -f "$tmp"' EXIT
  if bash -c "$bootstrap" > "$tmp" 2>"$tmp.err" && is_valid "$tmp"; then source=bootstrap_stock_symvers; candidate=$tmp; else cat "$tmp.err" >&2 || true; fi
fi
if [[ -z $candidate ]] && command -v bootstrap_stock_symvers >/dev/null 2>&1; then
  tmp=$(mktemp "${TMPDIR:-/tmp}/bootstrap-symvers.XXXXXX"); trap 'rm -f "$tmp"' EXIT
  if bootstrap_stock_symvers > "$tmp" && is_valid "$tmp"; then source=bootstrap_stock_symvers; candidate=$tmp; fi
fi
[[ -n $candidate ]] || { echo "stock Module.symvers not found (set explicit input, cache, prebuilt, or bootstrap_stock_symvers)" >&2; exit 1; }
mkdir -p "$(dirname "$out")"; cp -- "$candidate" "$out"
sha=$(sha256sum "$out" | awk '{print $1}')
printf 'source=%s\npath=%s\nsha256=%s\n' "$source" "$(readlink -f "$out")" "$sha"
