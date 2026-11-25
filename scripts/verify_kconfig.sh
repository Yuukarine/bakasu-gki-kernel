#!/usr/bin/env bash
set -Eeuo pipefail
usage(){ cat <<'USAGE'
Usage: verify_kconfig.sh --config FILE [--branch aosp-gki|oneplus-ogki] [--fragments DIR]
USAGE
}
die(){ printf 'kconfig verification: FAIL: %s\n' "$*" >&2; exit 1; }
config=.config; branch=${BAKASU_BRANCH:-aosp-gki}; dir=configs
while (($#)); do case "$1" in
  -h|--help) usage; exit 0;; -c|--config) [[ $# -gt 1 ]] || die 'missing config path'; config=$2; shift 2;;
  -b|--branch) [[ $# -gt 1 ]] || die 'missing branch'; branch=$2; shift 2;;
  -f|--fragments) [[ $# -gt 1 ]] || die 'missing fragment dir'; dir=$2; shift 2;;
  *) die "unknown option: $1";; esac; done
[[ -r $config ]] || die "config not readable: $config"
case "$branch" in aosp-gki|oneplus-ogki) ;; *) die "unsupported branch: $branch";; esac
shared=$dir/bakasu_stealth.fragment; [[ -r $shared ]] || die "missing fragment: $shared"
if [[ $branch == aosp-gki ]]; then branch_file=$dir/gki_extras.fragment; else branch_file=$dir/oneplus_extras.fragment; fi
[[ -r $branch_file ]] || die "missing fragment: $branch_file"
declare -A cfg frag
# Use direct associative assignment without eval for generated config and fragments.
assignment_re='^CONFIG_[A-Za-z0-9_]+=(y|m|n|".*")$'
unset_re='^# (CONFIG_[A-Za-z0-9_]+) is not set$'
parse_file(){ local file=$1 kind=$2 line sym val; while IFS= read -r line || [[ -n $line ]]; do
  [[ -z $line ]] && continue
  if [[ $line =~ $assignment_re ]]; then sym=${line%%=*}; val=${line#*=};
  elif [[ $line =~ $unset_re ]]; then sym=${BASH_REMATCH[1]}; val=n; else continue; fi
  if [[ $kind == frag ]]; then [[ -v "frag[$sym]" ]] && die "duplicate fragment assignment: $sym"; frag[$sym]=$val; else [[ -v "cfg[$sym]" ]] && die "duplicate generated assignment: $sym"; cfg[$sym]=$val; fi
done < "$file"; }
parse_file "$shared" frag; parse_file "$branch_file" frag; parse_file "$config" cfg
required=(CONFIG_KSU=y CONFIG_KSU_SUSFS=y CONFIG_KSU_SUSFS_SUS_PATH=y CONFIG_KSU_SUSFS_SUS_MOUNT=y CONFIG_KSU_SUSFS_SUS_KSTAT=y CONFIG_KSU_SUSFS_SPOOF_UNAME=y CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y CONFIG_KSU_SUSFS_OPEN_REDIRECT=y CONFIG_KSU_SUSFS_SUS_MAP=y CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y CONFIG_NOMOUNT=y CONFIG_TMPFS_XATTR=y CONFIG_SECURITY_DMESG_RESTRICT=y 'CONFIG_LOCALVERSION=""' CONFIG_LTO_CLANG_THIN=y CONFIG_TCP_CONG_BBR=y CONFIG_DEFAULT_BBR=y CONFIG_NET_SCH_FQ_CODEL=y CONFIG_NET_SCH_CAKE=y CONFIG_NET_SCH_PIE=y CONFIG_IP_SET=y CONFIG_IP_NF_TARGET_TTL=y CONFIG_IP6_NF_NAT=y)
[[ $branch == aosp-gki ]] && required+=(CONFIG_HZ_250=y)
for e in "${required[@]}"; do s=${e%%=*}; v=${e#*=}; [[ ${cfg[$s]+x} ]] || die "missing $e"; [[ ${cfg[$s]} == "$v" ]] || die "wrong $s=${cfg[$s]}, expected $v"; [[ ${frag[$s]+x} ]] || die "required symbol not declared by fragment: $s"; done
for s in CONFIG_KSU_DEBUG CONFIG_KSU_SUSFS_ENABLE_LOG CONFIG_NOMOUNT_DEBUG CONFIG_LOCALVERSION_AUTO CONFIG_KPROBES_SANITY_TEST CONFIG_KSU_TRACEPOINT_HOOK CONFIG_KSU_MANUAL_HOOK; do [[ ${cfg[$s]:-n} == n ]] || die "forbidden/duplicate hook enabled: $s=${cfg[$s]}"; done
for s in CONFIG_DEBUG_FS CONFIG_KPROBES CONFIG_FTRACE CONFIG_AUDIT CONFIG_PRINTK; do [[ ${cfg[$s]:-} == y ]] || die "protected flag disabled/missing: $s"; done
printf 'kconfig verification: PASS (%s)\n' "$branch"
