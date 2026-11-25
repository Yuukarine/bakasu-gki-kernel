#!/usr/bin/env bash
# Compare exported symbol CRCs; --bore makes the post-build hard gate explicit.
set -Eeuo pipefail
usage(){ cat <<'USAGE'
Usage: verify_abi_crc.sh [--bore] [--reference FILE --candidate FILE] REFERENCE CANDIDATE
USAGE
}
ref='' cand='' bore=0
while (($#)); do case "$1" in
  -h|--help) usage; exit 0;; --bore) bore=1; shift;; --reference) ref=$2; shift 2;; --candidate) cand=$2; shift 2;;
  --) shift; break;; -*) echo "unknown option: $1" >&2; exit 2;;
  *) if [[ -z $ref ]]; then ref=$1; elif [[ -z $cand ]]; then cand=$1; else echo "unexpected argument: $1" >&2; exit 2; fi; shift;;
esac; done
[[ -n $ref && -n $cand ]] || { usage >&2; exit 2; }
[[ -r $ref ]] || { echo "reference Module.symvers not readable: $ref" >&2; exit 2; }
[[ -r $cand ]] || { echo "candidate Module.symvers not readable: $cand" >&2; exit 2; }
tmp="${BAKASU_WORK_ROOT:-.tmp}/abi-crc.$$"; mkdir -p "$tmp"; trap 'rm -rf "$tmp"' EXIT
parse(){ local in=$1 out=$2; awk 'BEGIN{FS="[[:space:]]+"} /^[[:space:]]*#/||NF==0{next} NF<2{bad=1; print "malformed line " NR > "/dev/stderr"; next} { c=tolower($1); s=$2; if (s in seen && seen[s]!=c){bad=1; print "duplicate CRC: " s > "/dev/stderr"} seen[s]=c } END{for(s in seen) print s "\t" seen[s]; if(bad) exit 3}' "$in" | LC_ALL=C sort -k1,1 > "$out"; }
parse "$ref" "$tmp/ref" || exit 2; parse "$cand" "$tmp/cand" || exit 2
awk -F '\t' 'NR==FNR{a[$1]=$2;next}{b[$1]=$2} END{for(s in a){if(!(s in b)){print "missing candidate symbol: " s; missing++}else if(a[s]!=b[s]){print "CRC mismatch: " s " reference=" a[s] " candidate=" b[s]; changed++}}for(s in b)if(!(s in a)){print "added candidate symbol: " s; added++} drift=changed+missing; print "__SUMMARY__\t" length(a) "\t" (drift+0) "\t" (changed+0) "\t" (missing+0) "\t" (added+0); if(drift)exit 1}' "$tmp/ref" "$tmp/cand" > "$tmp/report" || status=$?
status=${status:-0}; sed '/^__SUMMARY__/d' "$tmp/report"; summary=$(grep '^__SUMMARY__' "$tmp/report" || true); [[ -n $summary ]] || { cat "$tmp/report" >&2; exit 2; }
IFS=$'\t' read -r _ total drift changed missing added <<< "$summary"
if (( status != 0 || drift != 0 )); then echo "CRC CHECK: FAIL ($drift drift; changed=$changed missing=$missing added=$added; reference_symbols=$total; bore=$bore)" >&2; exit 1; fi
echo "CRC CHECK: PASS ($total symbols, zero CRC drift; added=$added non-reference exports; bore=$bore)"
