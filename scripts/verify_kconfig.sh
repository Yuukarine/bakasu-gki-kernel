#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: verify_kconfig.sh [OPTIONS]

Validate a generated kernel .config against the BakaSU/SUSFS fragments.
  -c, --config PATH       generated .config (default: .config)
  -b, --branch NAME       aosp-gki or oneplus-ogki (default: BAKASU_BRANCH or aosp-gki)
  -f, --fragments DIR     fragment directory (default: configs)
  -h, --help              show this help
USAGE
}

die() { printf 'kconfig verification: FAIL: %s\n' "$*" >&2; exit 1; }

config_file=.config
branch=${BAKASU_BRANCH:-aosp-gki}
fragment_dir=configs
while (($#)); do
  case $1 in
    -c|--config) (($# >= 2)) || die "$1 requires a path"; config_file=$2; shift 2 ;;
    -b|--branch) (($# >= 2)) || die "$1 requires a branch"; branch=$2; shift 2 ;;
    -f|--fragments) (($# >= 2)) || die "$1 requires a directory"; fragment_dir=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (use --help)" ;;
  esac
done

case $branch in
  aosp-gki|oneplus-ogki) ;;
  *) die "unsupported branch '$branch' (expected aosp-gki or oneplus-ogki)" ;;
esac
[[ -f $config_file ]] || die "config not found: $config_file"
[[ -d $fragment_dir ]] || die "fragment directory not found: $fragment_dir"

shared=$fragment_dir/shared.config
branch_fragment=$fragment_dir/$branch.config
[[ -f $shared ]] || die "missing shared fragment: $shared"
[[ -f $branch_fragment ]] || die "missing branch fragment: $branch_fragment"

assignment_re='^CONFIG_[A-Za-z0-9_]+=(y|m|n|"[^" ]*")$'
# Keep the expression in a variable so [[ =~ ]] does not parse its quotes.
declare -A fragment_values=()
for fragment in "$shared" "$branch_fragment"; do
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || $line == \#* ]] && continue
    [[ $line =~ $assignment_re ]] || die "malformed assignment in $fragment: $line"
    symbol=${line%%=*}
    if [[ ${fragment_values[$symbol]+yes} ]]; then
      die "duplicate fragment assignment for $symbol"
    fi
    fragment_values[$symbol]=${line#*=}
  done < "$fragment"
done

declare -A config_values=()
while IFS= read -r line || [[ -n $line ]]; do
  [[ -z $line || $line == \#* ]] && continue
  [[ $line =~ $assignment_re ]] || continue
  symbol=${line%%=*}
  [[ ${config_values[$symbol]+yes} ]] && die "duplicate generated assignment for $symbol"
  config_values[$symbol]=${line#*=}
done < "$config_file"

required=(
  CONFIG_NOMOUNT=y
  CONFIG_SECURITY_DMESG_RESTRICT=y
  CONFIG_KSU_SUSFS_SUS_PATH=y
  CONFIG_KSU_SUSFS_SUS_MOUNT=y
  CONFIG_KSU_SUSFS_SUS_KSTAT=y
  CONFIG_KSU_SUSFS_SPOOF_UNAME=y
  CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
  CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
  CONFIG_KSU_SUSFS_SUS_MAP=y
  CONFIG_KSU_SUSFS_ENABLE_LOG=n
  'CONFIG_LOCALVERSION=""'
)
if [[ $branch == aosp-gki ]]; then
  required+=(CONFIG_HZ_250=y)
fi

for expected in "${required[@]}"; do
  symbol=${expected%%=*}
  value=${expected#*=}
  [[ ${config_values[$symbol]+yes} ]] || die "missing $expected in $config_file"
  [[ ${config_values[$symbol]} == "$value" ]] || die "wrong value for $symbol: expected $value, got ${config_values[$symbol]}"
  [[ ${fragment_values[$symbol]+yes} ]] || die "required symbol $symbol is not declared by a fragment"
  [[ ${fragment_values[$symbol]} == "$value" ]] || die "wrong fragment value for $symbol: expected $value, got ${fragment_values[$symbol]}"
done

for symbol in CONFIG_DEBUG_FS CONFIG_KPROBES CONFIG_FTRACE CONFIG_AUDIT CONFIG_PRINTK; do
  [[ ${config_values[$symbol]+yes} ]] || die "missing protected feature $symbol"
  [[ ${config_values[$symbol]} == y ]] || die "protected feature disabled: $symbol=${config_values[$symbol]}"
done

printf 'kconfig verification: PASS (%s, %s)\n' "$branch" "$config_file"
