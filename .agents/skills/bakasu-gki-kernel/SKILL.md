---
name: bakasu-gki-kernel
description: Build and verify BakaSU GKI 2.0 and OnePlus OGKI kernels with one stealth patch stack, strict KMI/CRC discipline, and reproducible gates. Trigger for kernel config, patch, build, packaging, or verification work in this project.
---

# BakaSU GKI 2.0 / OGKI

## Contract
Use **BakaSU only**: never KSUN or Non-GKI. Keep one shared stealth patch set and two source branches. Prefer the smallest change (YAGNI) and prove each gate with a real command.

## Source branches
- **OnePlus (`OnePlusOSS` / OGKI):** retain OPlus vendor hooks; enable Faster SDP 900mA; enable HMBIRD SCX only on SM8735, SM8750, or MT6991. Use BORE only when HMBIRD is absent and CRC drift is exactly zero. `anykernel.sh` must compare `uname -r` for an exact match (no prefix/glob).
- **RedMagic + Xiaomi (AOSP GKI 2.0):** enforce zero CRC drift; retain `CONFIG_HZ_250=y`; detect `boot.img` compression with `magiskboot`; keep stock `init_boot`.

## Golden Stack (native kernel responsibilities)
1. **BakaSU:** SUSFS inline hook; disable duplicate kprobe/tracepoint/manual hooks.
2. **SUSFS v2.4.0:** set `CONFIG_KSU_SUSFS_SUS_PATH=y`, `CONFIG_KSU_SUSFS_SUS_MOUNT=y`, `CONFIG_KSU_SUSFS_SUS_KSTAT=y`, `CONFIG_KSU_SUSFS_SPOOF_UNAME=y`, `CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y`, `CONFIG_KSU_SUSFS_OPEN_REDIRECT=y`, and `CONFIG_KSU_SUSFS_SUS_MAP=y`; include Unicode Bypass Fix; set `CONFIG_KSU_SUSFS_ENABLE_LOG=n`.
3. **NoMount fallback:** `CONFIG_NOMOUNT=y` dormant; retain TMPFS XATTR fallback.
4. Set `CONFIG_SECURITY_DMESG_RESTRICT=y` and `CONFIG_LOCALVERSION=""`.
5. Do not add custom C patches for SELinux/DeviceTree. Zero-trust BakaSU Manager hide-SELinux/spoof-AVC behavior. Leave HMA, TrickyStore, ZN-AuditPatch, and Zygisk/LSPosed to external modules.
6. Never add ABI-fragile BBRv3, forced `CONFIG_HZ`, ADIOS I/O, or `-O3`. Never disable `CONFIG_DEBUG_FS`, `CONFIG_KPROBES`, `CONFIG_FTRACE`, `CONFIG_AUDIT`, or `CONFIG_PRINTK`.

## Workflow and required integrations
`rtk` keeps command output compact; `graphify` maps source→patch→config→image provenance; `context-mode` loads only the active branch and gate inputs; `token-savior` summarizes large logs; `caveman lite` prefers simple shell checks; `systematic-debugging` records hypothesis→experiment→result; `verification-before-completion` blocks completion until every gate is observed; `ponytail` runs a final YAGNI review. If a tool is unavailable, keep the same contract with local shell equivalents and record the result.

1. Bind branch, device, toolchain, source revision, and expected `uname -r`; preserve stock `init_boot`.
2. Apply only the shared patch set plus branch-specific items. Run `make olddefconfig`.
3. **Config gate:** grep every Golden Stack flag and every forbidden flag; fail on missing, wrong, or duplicate settings.
4. Build with the project toolchain. **CRC gate:** on GKI 2.0 branches compare exported symbols in `Module.symvers`; any changed CRC fails. OnePlus may use BORE only after this gate is zero.
5. Package with `magiskboot` compression autodetection. Check exact `uname -r` equality in `anykernel.sh`; never replace stock `init_boot`.
6. Run `ponytail` YAGNI review and `verification-before-completion`; publish hashes, commands, stdout/stderr, and exit codes.

## Gate snippets
```bash
# config: run at the kernel source root after olddefconfig
required=(CONFIG_NOMOUNT=y CONFIG_SECURITY_DMESG_RESTRICT=y CONFIG_KSU_SUSFS_SUS_PATH=y CONFIG_KSU_SUSFS_SUS_MOUNT=y CONFIG_KSU_SUSFS_SUS_KSTAT=y CONFIG_KSU_SUSFS_SPOOF_UNAME=y CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y CONFIG_KSU_SUSFS_OPEN_REDIRECT=y CONFIG_KSU_SUSFS_SUS_MAP=y)
[[ "${BAKASU_BRANCH:-aosp-gki}" == oneplus-ogki ]] || required+=(CONFIG_HZ_250=y)
for x in "${required[@]}"; do grep -Fxq "$x" .config || { echo "missing $x" >&2; exit 1; }; done
for x in CONFIG_KSU_SUSFS_ENABLE_LOG CONFIG_LOCALVERSION; do grep -Eq "^${x}=(n|\"\")$" .config || { echo "bad $x" >&2; exit 1; }; done
for x in CONFIG_DEBUG_FS CONFIG_KPROBES CONFIG_FTRACE CONFIG_AUDIT CONFIG_PRINTK; do grep -Eq "^${x}=y$" .config || { echo "disabled $x" >&2; exit 1; }; done
```
For SUSFS names, accept the exact project symbol spelling only; fail closed if a symbol is absent. Compare `Module.symvers` by symbol name and CRC (sorted, branch-to-branch); report the first mismatch and total drift. Record `sha256sum` for source, `.config`, `Module.symvers`, `Image`, boot image, and zip.

## Deliverables
A successful run leaves: branch manifest, gate logs, hashes, packaged image, and a rollback point. Do not call a build complete when any gate is skipped, a CRC differs, `uname -r` is not exact, or `init_boot` is not stock.
