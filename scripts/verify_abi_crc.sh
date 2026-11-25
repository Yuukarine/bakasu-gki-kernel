#!/usr/bin/env bash
# Compare exported kernel symbol CRCs from two Module.symvers files.
set -euo pipefail
usage() {
  cat <<'USAGE'
Usage: verify_abi_crc.sh [OPTIONS] REFERENCE CANDIDATE
       verify_abi_crc.sh --reference FILE --candidate FILE

Fail when an exported symbol is missing, added, or has a different CRC.
Options: --reference FILE, --candidate FILE, --help
USAGE
}
ref= cand=
while (($#)); do
  case $1 in
    --help|-h) usage; exit 0;;
    --reference) [[ $# -ge 2 ]] || { echo "--reference requires a file" >&2; exit 2; }; ref=$2; shift 2;;
    --candidate) [[ $# -ge 2 ]] || { echo "--candidate requires a file" >&2; exit 2; }; cand=$2; shift 2;;
    --) shift; break;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2;;
    *) if [[ -z $ref ]]; then ref=$1; elif [[ -z $cand ]]; then cand=$1; else echo "unexpected argument: $1" >&2; exit 2; fi; shift;;
  esac
done
while (($#)); do
  if [[ -z $ref ]]; then ref=$1; elif [[ -z $cand ]]; then cand=$1; else echo "unexpected argument: $1" >&2; exit 2; fi
  shift
done
[[ -n $ref && -n $cand ]] || { usage >&2; exit 2; }
[[ -r $ref ]] || { echo "reference Module.symvers not readable: $ref" >&2; exit 2; }
[[ -r $cand ]] || { echo "candidate Module.symvers not readable: $cand" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/abi-crc.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
parse() {
  local input=$1 output=$2
  awk 'BEGIN { FS="[[:space:]]+" }
    /^[[:space:]]*#/ || NF == 0 { next }
    NF < 2 { printf "malformed Module.symvers line %d in %s\n", NR, FILENAME > "/dev/stderr"; bad=1; next }
    { crc=tolower($1); sym=$2; if (!(sym in seen)) { print sym "\t" crc; seen[sym]=1 } else if (seen[sym] != crc) { printf "duplicate symbol with conflicting CRC: %s in %s\n", sym, FILENAME > "/dev/stderr"; bad=1 } }
    END { if (bad) exit 3 }' "$input" | LC_ALL=C sort -k1,1 > "$output"
}
parse "$ref" "$tmp/ref" || exit 2
parse "$cand" "$tmp/cand" || exit 2
# Join by symbol and classify missing, added, and changed CRCs.
awk -F '\t' '
  NR==FNR { a[$1]=$2; next }
  { b[$1]=$2 }
  END {
    for (s in a) { if (!(s in b)) { printf "missing candidate symbol: %s (reference %s)\n",s,a[s]; missing++; } else if (a[s] != b[s]) { printf "CRC mismatch: %s reference=%s candidate=%s\n",s,a[s],b[s]; changed++; } }
    for (s in b) if (!(s in a)) { printf "added candidate symbol: %s (candidate %s)\n",s,b[s]; added++; }
    printf "__SUMMARY__\t%d\t%d\t%d\t%d\n", length(a), changed+missing+added, changed, missing+added
    if (changed || missing || added) exit 1
  }' "$tmp/ref" "$tmp/cand" > "$tmp/report" || status=$?
status=${status:-0}
summary=$(grep '^__SUMMARY__' "$tmp/report" || true)
if [[ -z $summary ]]; then echo "CRC comparison failed without summary" >&2; cat "$tmp/report"; exit 2; fi
sed '/^__SUMMARY__/d' "$tmp/report"
IFS=$'\t' read -r _ total drift changed missing <<< "$summary"
if (( status != 0 || drift != 0 )); then
  echo "CRC CHECK: FAIL ($drift drift; changed=$changed missing_or_added=$missing; reference_symbols=$total)" >&2
  exit 1
fi
echo "CRC CHECK: PASS ($total symbols, zero drift)"
