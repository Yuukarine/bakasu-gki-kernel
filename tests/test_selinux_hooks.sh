#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/selinux-hook-fixtures.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp" <<'PY'
import difflib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
source = root / "source/security/selinux"
(source / "ss").mkdir(parents=True)
(source / "hooks.c").write_text("""ksu_selinux_hide_running
susfs_selinux_setprocattr
LSM_HOOK_INIT(setprocattr, handle_selinux_setprocattr)
""")
(source / "ss/services.c").write_text("""susfs_security_context_to_sid
susfs_security_context_str_to_sid
susfs_security_compute_av_user
susfs_spoof_avd_allowed_rcu
""")
(source / "status.c").write_text("susfs_is_current_ksu_domain()\nstatus->policyload = seqno\n")
base = [f"unchanged line {n}\n" for n in range(100)]
additions = {
    10: "extern bool ksu_selinux_hide_running;\n",
    30: "filp->private_data = data; initialize_fake_status();\n",
    50: "[SEL_CONTEXT] = handle_sel_write_context,\n",
    70: "[SEL_ACCESS] = handle_sel_write_access,\n",
    90: "susfs_security_compute_av_user();\n",
}
modified = [entry for n, line in enumerate(base) for entry in ([line] + ([additions[n]] if n in additions else []))]
(source / "selinuxfs.c").write_text("".join(modified))
header = "diff --git a/security/selinux/selinuxfs.c b/security/selinux/selinuxfs.c\n"
patch = header + "".join(difflib.unified_diff(base, modified, fromfile="a/security/selinux/selinuxfs.c", tofile="b/security/selinux/selinuxfs.c"))
(root / "original.patch").write_text(patch)
for n, addition in additions.items():
    (root / f"missing-{n}.c").write_text("".join(modified).replace(addition, ""))
PY
check=("$root/scripts/verify_selinux_hooks.sh" --source "$tmp/source" --patch "$tmp/original.patch")
"${check[@]}"
cp "$tmp/source/security/selinux/selinuxfs.c" "$tmp/good.c"
for hunk in 10 30 50 70 90; do
  cp "$tmp/missing-$hunk.c" "$tmp/source/security/selinux/selinuxfs.c"
  if "${check[@]}" > "$tmp/failure.log" 2>&1; then
    echo "dropped SELinux hunk $hunk unexpectedly passed" >&2; exit 1
  fi
  grep -Fq 'selinux_hide manual hook found but upstream selinuxfs 5/5 hunks are incomplete' "$tmp/failure.log"
done
cp "$tmp/good.c" "$tmp/source/security/selinux/selinuxfs.c"
printf 'selinux_hide manual hook found\nsecurity/selinux/selinuxfs.c -> all 5 hunk(s) dropped\n' > "$tmp/build.log"
if "${check[@]}" --log "$tmp/build.log" > "$tmp/failure.log" 2>&1; then
  echo 'dropped-hunk build log unexpectedly passed' >&2; exit 1
fi
grep -Fq 'incomplete selinuxfs integration in build log' "$tmp/failure.log"
printf 'mode=susfs-manual selinuxfs_hunks=5/5\n' > "$tmp/build.log"
"${check[@]}" --log "$tmp/build.log"
sed -i '/LSM_HOOK_INIT/d' "$tmp/source/security/selinux/hooks.c"
if "${check[@]}" > "$tmp/failure.log" 2>&1; then
  echo 'missing attr/current hook unexpectedly passed' >&2; exit 1
fi
grep -Fq 'manual surface missing' "$tmp/failure.log"
printf 'selinux hook fixtures: PASS (complete manual, each of 5 dropped hunks rejected, dropped log rejected, attr/current required)\n'
