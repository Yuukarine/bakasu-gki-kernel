#!/usr/bin/env bash
# A manual SUSFS selector must own all four SELinux surfaces, never a mixed stack.
set -Eeuo pipefail
source_dir='' patch_file='' build_log=''
while (($#)); do
  case "$1" in
    --source) source_dir=${2:?}; shift 2 ;;
    --patch) patch_file=${2:?}; shift 2 ;;
    --log) build_log=${2:?}; shift 2 ;;
    *) printf 'usage: %s --source KERNEL --patch ORIGINAL_SUSFS_PATCH [--log BUILD_LOG]\n' "$0" >&2; exit 1 ;;
  esac
done
[[ -d $source_dir && -f $patch_file ]] || { echo 'SELINUX HOOK CHECK: FAIL (source/patch missing)' >&2; exit 1; }
python3 - "$source_dir" "$patch_file" "$build_log" <<'PY'
import pathlib
import re
import subprocess
import sys

source, upstream = map(pathlib.Path, sys.argv[1:3])

def fail(message):
    print(f"SELINUX HOOK CHECK: FAIL ({message})", file=sys.stderr)
    sys.exit(1)

try:
    hooks = (source / "security/selinux/hooks.c").read_text()
    if "ksu_selinux_hide_running" not in hooks:
        fail("expected complete SUSFS manual mode; selector absent")
    # Check the original patch, not the helper's reconciled copy: otherwise
    # deleting a hunk from that copy would make a partial stack look complete.
    sections = re.findall(r"(?ms)^diff --git .*?(?=^diff --git |\Z)", upstream.read_text())
    wanted = "diff --git a/security/selinux/selinuxfs.c b/security/selinux/selinuxfs.c\n"
    matches = [section for section in sections if section.startswith(wanted)]
    if len(matches) != 1 or len(re.findall(r"(?m)^@@ ", matches[0])) != 5:
        fail("original SUSFS selinuxfs patch must contain exactly 5 hunks")
    complete = subprocess.run(
        ["patch", "--batch", "--force", "--dry-run", "--reverse", "--fuzz=0", "-p1"],
        input=matches[0], cwd=source, text=True, capture_output=True, check=False,
    )
    if complete.returncode:
        fail("selinux_hide manual hook found but upstream selinuxfs 5/5 hunks are incomplete: "
             + complete.stdout.strip() + " " + complete.stderr.strip())
    required = {
        "security/selinux/hooks.c": [
            "LSM_HOOK_INIT(setprocattr, handle_selinux_setprocattr)",
            "susfs_selinux_setprocattr", "ksu_selinux_hide_running",
        ],
        "security/selinux/selinuxfs.c": [
            "[SEL_CONTEXT] = handle_sel_write_context",
            "[SEL_ACCESS] = handle_sel_write_access", "filp->private_data = data",
            "initialize_fake_status()", "susfs_security_compute_av_user",
        ],
        "security/selinux/ss/services.c": [
            "susfs_security_context_to_sid", "susfs_security_context_str_to_sid",
            "susfs_security_compute_av_user", "susfs_spoof_avd_allowed_rcu",
        ],
        "security/selinux/status.c": [
            "susfs_is_current_ksu_domain()", "status->policyload = seqno",
        ],
    }
    for filename, tokens in required.items():
        body = (source / filename).read_text()
        for token in tokens:
            if token not in body:
                fail(f"manual surface missing: {filename}: {token}")
    if sys.argv[3]:
        log = pathlib.Path(sys.argv[3]).read_text(errors="replace")
        # A final integration/build log must never report dropped SELinux hunks.
        for line in log.splitlines():
            if "selinuxfs.c" in line and re.search(r"dropped|FAILED|reject", line, re.I):
                fail(f"incomplete selinuxfs integration in build log: {line}")
except (OSError, UnicodeError) as error:
    fail(str(error))
print("SELINUX HOOK CHECK: PASS (mode=susfs-manual selinuxfs_hunks=5/5 surfaces=attr/current,context,access,status)")
PY
