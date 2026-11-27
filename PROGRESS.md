# BakaSU GKI 2.0 / OGKI — execution record

Project root: `/home/yuukari_ne/My-Project/custom-phone/kernel-build`.
All commands and artifacts below are inside this root; Luna worktrees are under
`.tmp/worktrees/` only.

## Plan and bootstrap

- [x] Plan recorded before implementation; the bound target is this project root.
- [x] Blocking popup created first: `scripts/ask_user_popup.sh` is executable; `bash -n scripts/ask_user_popup.sh` exits 0 and smoke input returns `fixture` (exit 0).
- [x] `npx --yes autoskills -y` exited 0; `npx --yes skills find` exited 0. The npm package named `find-skills` returned 404 and is recorded as a non-blocking bootstrap note in the prior ledger.
- [x] Required local workflow references are in `SKILL.md`: `rtk`, `graphify`, `ponytail`, `context-mode`, `token-savior`, `caveman lite`, `systematic-debugging`, and `verification-before-completion`.
- [x] `.claudeignore` and `.codexignore` exclude `out/`, `.tmp/`, `kernel_src/`, `toolchains/`, `*.zip`, `*.img`, and `Image*`.
- [x] Skill and CLI links are present: `.agents/skills/bakasu-gki-kernel/SKILL.md`, `.codex/skills/bakasu-gki-kernel`, `.claude/skills/bakasu-gki-kernel`; `AGENTS.md` references the skill.

## Implemented architecture

- [x] Shared BakaSU/SUSFS v2.4.0 fragment is in `configs/bakasu_stealth.fragment`; protected debug/ABI flags remain enabled and log/debug/localversion leak flags are disabled.
- [x] GKI fragment locks `CONFIG_HZ_250=y`; OnePlus fragment contains no fabricated symbols. Conditional Kconfig is limited to `configs/features/oneplus-bore.fragment`; patch-only features are declared in `patches/sources/manifest.tsv` and applied separately by `scripts/apply_patch_sources.sh`.
- [x] OnePlus BORE order is enforced: merge `oneplus-bore.fragment` → apply BORE patch → `olddefconfig` → `verify_kconfig` → build → `verify_abi_crc.sh --bore` → package.
- [x] Workflows include OnePlus Ace 3V Android 16/OOS16/COS16 with KMI `android14-6.1` and both stock banners, plus GKI families `android13-5.15`, `android14-6.1`, `android15-6.6`, and `android16-6.12`; matrix patch selection enables BBG/Droidspaces/NTSync only on the first three families and disables all three on Android 16.
- [x] AnyKernel templates are POSIX `sh`, use `magiskboot unpack`/`KERNEL_FMT`, preserve stock `init_boot`, enforce exact `uname -r`, supported KMI generation, page-size rules, and no sublevel downgrade.

## Resolver and verification gates

- [x] `scripts/verify_kconfig.sh` parses generated assignments and unset lines, checks every required stealth flag, rejects `ENABLE_LOG`/debug/localversion leaks, and requires `DEBUG_FS`, `KPROBES`, `FTRACE`, `AUDIT`, and `PRINTK`.
- [x] `scripts/resolve_stock_symvers.sh` priority is `path → url → cache → prebuilt → bootstrap`; cache hits require valid format, matching key/KMI/page-size/stock `uname -r`/source SHA/toolchain, and SHA256 metadata. It prints exactly one `resolver_source=path|url|cache|prebuilt|bootstrap`.
- [x] `build-oneplus.yml` and `build-gki.yml` expose path/URL/prebuilt/bootstrap inputs, restore Actions cache before prebuilt, bootstrap a stock baseline when selected, write metadata, save the cache, run CRC gates, and package ZIP plus SHA256 checksum.
- [x] `scripts/verify_abi_crc.sh --bore` hard-fails any changed/missing/added symbol; package steps occur only after the gate.
- [x] `anykernel/*/anykernel.sh` resolver order is `AK3_SLOT_SUFFIX` → ak3-core slot → property/cmdline → slot-specific partition detection. It checks both `/dev/block/by-name` and `/dev/block/bootdevice/by-name`, distinguishes A/B from non-A/B, skips absent `init_boot` only under the approved conditions, and rejects opposite-slot `init_boot`.
- [x] Page-size resolver order is `AK3_PAGE_SIZE` → `getconf PAGESIZE` → filtered `KernelPageSize` values in `/proc/self/smaps`; hugepage VMAs are ignored, mixed/invalid base sizes fail, and output records `page_size_source=dry-run|getconf|smaps`.
- [x] `init_boot` ramdisk marker policy rejects the six exact root-relative paths `kernelsu.ko`, `ksuinit`, `magiskinit`, `.backup`, `.magisk`, `.backup/.magisk`; near names and nested look-alikes are allowed.
- [x] `artifacts/graphify.tsv` records source → patch → config → image provenance.

## Executed verification evidence

- [x] `./scripts/verify_skill.sh` → `skill verification: PASS` (exit 0).
- [x] `./tests/test_kconfig.sh` → `kconfig fixtures: PASS` (exit 0). Fixtures prove a clean config passes and `CONFIG_KSU_SUSFS_ENABLE_LOG=y` or `CONFIG_DEBUG_FS` disabled fails.
- [x] `./tests/test_abi_crc.sh` → `ABI CRC/resolver fixtures: PASS` (exit 0). Fixtures prove zero drift passes, one CRC mismatch fails, and resolver sources path/cache/prebuilt/bootstrap; invalid cache metadata falls back to prebuilt.
- [x] `./tests/test_anykernel.sh` → `AnyKernel fixtures: PASS` (exit 0). Fixtures cover empty slot property with slot partitions, active-slot `init_boot` absence skip, opposite-slot fail, both partition roots, all six exact markers, near-name allow-list, smaps hugepage filtering, Android 15 `-4k` suffix, and sublevel downgrade rejection.
- [x] `bash -n scripts/*.sh tests/*.sh` exited 0.
- [x] `sh -n anykernel/oneplus/anykernel.sh anykernel/gki/anykernel.sh` exited 0.
- [x] `shellcheck` was probed; it is not installed in this environment. CI conditionally runs `shellcheck -s bash` for scripts and `shellcheck -s sh` for `anykernel/*/*.sh` when available.
- [x] PyYAML parsed all workflows: `YAML OK: .github/workflows/ci-validate.yml`, `YAML OK: .github/workflows/build-oneplus.yml`, `YAML OK: .github/workflows/build-gki.yml` (exit 0). `actionlint` was probed and is not installed locally; CI runs it when available.
- [x] Package fixture: `scripts/package_anykernel.sh` created a ZIP and SHA256 sidecar; `unzip -l` showed `anykernel.sh` and `Image`, and `sha256sum -c` returned `OK` (exit 0). A cleanup/log ordering probe first returned exit 1 after deleting its log; the changed rerun above completed with `package fixture: PASS`.
- [x] `git diff --check` exited 0; temporary fixture/debug files were removed. Only declared project artifacts and `.tmp/worktrees/` remain.

## Transaction roles

- [x] Reopened absolute role paths: `artifacts/MODIFIED_FILE`, `artifacts/DIFF_FILE`, `artifacts/VERIFICATION.txt`, executable `artifacts/ROLLBACK.sh`.
- [x] Resolver transaction target is `scripts/resolve_stock_symvers.sh`; baseline, modified, and rollback commands all returned exit 0 with `resolver_source=path`, and rollback restored the exact original SHA. The complete command/input/stdout/stderr ledger is in `artifacts/VERIFICATION.txt`.

## Final review

- [x] YAGNI review: no KSUN/Non-GKI path, no custom SELinux/DeviceTree C patch, no fabricated Kconfig symbol for patch-only features, no BBRv3/ADIOS/`-O3`, no duplicate external-module responsibilities, and no generated heavy artifacts outside ignored `.tmp/`.
- [x] Final state is ready and live-verified on GitHub Actions with real source checkout, validated stock `Module.symvers`, zero CRC drift gate, exact KMI, and packaged checksum.

## Custom BakaSU driver display-name audit (2026-11-25)

- [x] Downloaded `kernel/Kbuild` and `kernel/Makefile` from the manifest source `https://github.com/Baka-SU/BakaSU.git#main` into `.tmp/bakasu-source-check/`; `Kbuild` defines `KSU_VERSION_FULL` on the first assignment (then performs placeholder substitutions), `KSU_VERSION` is a separate numeric expression, and `Makefile` has no driver-name assignment. Temporary source files were removed after inspection.
- [x] Added `scripts/set_bakasu_driver_name.sh`. Empty `CUSTOM_DRIVER_NAME` is a no-op; non-empty values are limited to 64 Unicode characters, reject controls/newlines and `"`, `\\`, backtick, `$`, whitespace, and unsupported punctuation, then atomically replace only the first `KSU_VERSION_FULL :=` line in the discovered BakaSU `Kbuild`. `KSU_VERSION`, `CONFIG_LOCALVERSION`, `uname -r`, and exported symbols are untouched.
- [x] Added `custom_driver_name` string inputs (default empty) to both build workflows. The value is passed only through `env:` and the helper runs after source integration and before `olddefconfig`.
- [x] Added `tests/test_driver_name.sh` and CI invocation. Fixture evidence: empty value preserves the file SHA; `v4.2.0-⚡Yuukari⚡@BakaSU` updates the exact display assignment while preserving `KSU_VERSION := 30701`; quote, dollar, newline, and 65-character values fail with `custom_driver_name: FAIL:`.
- [x] README usage documented. `bash -n`, YAML parse, driver-name fixtures, `git diff --check`, and the existing Kconfig/CRC/AnyKernel gates pass.

## Pre-push production audit (2026-11-25)

- [x] Placeholder/stub scan over `.github/`, `patches/`, `configs/`, `scripts/`, and `anykernel/`: no `TODO`, `FIXME`, `placeholder`, `example.com`, `CHANGE_ME`, `0000000`, or mock download/no-op command remained.
- [x] Remote refs checked with `git ls-remote --exit-code`: BakaSU `main` (`57b2db6076f439cfd489f14576444e8f0f2f0a25`), SUSFS GitLab `master` (`30e66dc3a5c65954de865afd8f44682866887544`), OnePlus-BakaSu_NMS `master` (`3710b8285978986af9fdf7ee43d3fd0853a0fe61`), WildKernels GKI `main` (`54d549fd398a2ccf2146785ab9b3e7b8a6808936`) and `droidspaces-resource-limits` (`fd815b66c5c1ab1b4068ad194601f73302e83652`), firelzrd BORE `main` (`575c13bd2d8a0d96a2d445a87d5a71d20890b631`), and AmneziaWG module `master` (`63ed35de3d3f135b17e8eae0b84949e7700303be`). Dead GitHub SUSFS and dead AmneziaWG kernel URLs were replaced; OnePlus default ref `android14-6.1.118` was replaced by live `master`.
- [x] `kernel/Kconfig` fetched from `https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/Kconfig` into `.tmp/audit/`; exact symbols confirmed: `CONFIG_KSU_SUSFS` is “SUSFS Inline Hook”, `CONFIG_KSU_TRACEPOINT_HOOK` and `CONFIG_KSU_MANUAL_HOOK` are the duplicate hook selectors, and `CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT` does not exist. The fragment/validator now remove the nonexistent symbol and reject both duplicate hooks; negative fixture covers tracepoint enablement.
- [x] `build-oneplus.yml` and `build-gki.yml` now free runner disk space (`/usr/share/dotnet`, `/opt/ghc`, `/usr/local/lib/android`, Docker prune) before clone/build. Stock bootstrap runs before patch-source application, so the optional baseline is genuinely unpatched; cache metadata and resolver source remain recorded.
- [x] BORE fallback downloads the pinned firelzrd 6.1 patch only when no local patch exists (`curl --retry`), merges `oneplus-bore.fragment`, applies the patch, then olddefconfig/verify/build/`verify_abi_crc.sh --bore`; the raw URL returned HTTP 200 during audit.
- [x] `patches/sources/manifest.tsv` now carries real URL/ref pairs. `scripts/apply_patch_sources.sh` verifies each selected ref and records its SHA; local patches are applied, while source-only integrations are explicitly logged as `source-verified-no-local-patch` instead of silently echoing a mock step. Full selected-feature fixture run passed and produced a provenance log.
- [x] AnyKernel slot detection corrected for POSIX operator precedence (both `boot_a`/`boot_b` and `init_boot_a`/`init_boot_b` now identify A/B correctly). Existing fixtures pass active-slot skip, opposite-slot failure, six exact ramdisk markers, near-name allow-list, page-size smaps fallback, KMI suffix, and sublevel gates.
- [x] Popup decision for tracked `artifacts/`: `scripts/ask_user_popup.sh` returned `no`; artifacts were retained and not untracked. `.tmp/audit/` and all audit fixtures are removed before commit; `.tmp/worktrees/` is the only retained temporary tree.
- [x] Final audit gates rerun after fixes: `bash -n scripts/*.sh tests/*.sh`, `sh -n anykernel/*/*.sh`, PyYAML workflow parse, `./scripts/verify_skill.sh`, `./tests/test_kconfig.sh`, `./tests/test_abi_crc.sh`, `./tests/test_anykernel.sh`, `git diff --check`; `shellcheck` and `actionlint` are not installed locally and remain conditional in CI.

## Live CI verification (2026-11-25)

- [x] `ci-validate.yml` passed on commit `e993e74`: run `https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45663129495`.
- [x] `build-oneplus.yml` passed on the requested single target `OnePlus Ace 3V / 6.1.118-android14-11-o-gac2e718ebee` with `custom_driver_name=""`; run `https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45663311213` (both matrix jobs completed successfully; the 6.1.141 sibling was also green).
- [x] Live gates: `custom_driver_name: empty, keeping BakaSU default`; `kconfig verification: PASS (oneplus-ogki)`; `CRC CHECK: PASS (15711 symbols, zero CRC drift; added=29 non-reference exports; bore=0)`.
- [x] Resolver evidence: `resolver_source=cache`, SHA256 `bf00d20b3871308202960d25d15a8d5cc09a084f8afea863f107039b3cfbc93c`.
- [x] Uploaded artifact: `oneplus-ace3v-6.1.118-android14-11-o-gac2e718ebee`; ZIP SHA256 `61326e2f3122443434dd7f37c7780a31f337de426494c81065e8dfcdb1ee1d19`; checksum sidecar included.
- [x] Artifact contents and checksum were downloaded and verified locally; no build-gki workflow was triggered in this turn.

## AnyKernel3 ZIP framework repair (2026-11-26)

- [x] Added pinned `osm0sis/AnyKernel3` manifest source `master` at commit `41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1`, confirmed with `git ls-remote`.
- [x] Reworked `scripts/package_anykernel.sh` to support `--ak3-template-dir`/`AK3_TEMPLATE_DIR` offline fixtures or shallow pinned upstream clone, preserve `META-INF/` and `tools/`, replace the device script and `Image`/`dtb`/`dtbo`, create a root-level ZIP and SHA256 sidecar, and hard-fail on missing required entries, `.git/`, or nested package roots.
- [x] Extended `tests/test_anykernel.sh` with complete PASS and missing-`update-binary`/missing-`ak3-core.sh` FAIL package fixtures. `./tests/test_anykernel.sh` returned `AnyKernel fixtures: PASS` (exit 0); fixture output and ZIP checksum matched.
- [x] Real upstream smoke package cloned `osm0sis/AnyKernel3` and passed the same root-entry gate; `sha256sum -c` returned `OK` (exit 0).
- [x] `bash -n scripts/*.sh tests/*.sh`, `sh -n anykernel/*/*.sh`, PyYAML workflow parsing, all four fixture suites, and `git diff --check` passed. `shellcheck`/`actionlint` are unavailable locally and remain conditional in CI.
- [x] `.tmp/` was emptied after verification; `git worktree list` contains only the project worktree. Artifacts remain ignored and untracked.
- [x] Transaction roles reopened: `/home/yuukari_ne/My-Project/custom-phone/kernel-build/artifacts/MODIFIED_FILE`, `DIFF_FILE`, `VERIFICATION.txt`, executable `ROLLBACK.sh`. Baseline SHA `4f081b47bd07cf668d90c71c30ec44915614df7f9fedb21f41d374010a2a212b`, modified SHA `b556af5e6d452ddf8c7f3f462b39d924b8857c4797e2bc8fdc79729f65999cc5`, rollback restored the baseline hash and baseline packaging exited 0.
- [x] Updated `scripts/apply_patch_sources.sh` to parse and enforce the manifest `commit_sha` column, preventing a stale AnyKernel3 pin from entering CI; syntax and AnyKernel fixtures were rerun after this change.

## Phase 1 — NoMount removal (2026-11-26)

- [x] Removed the NoMount manifest row, patch feature defaults, workflow clone/apply step, Kconfig symbols/validator checks, skill references, and README/runtime references.
- [x] `grep -rniE 'nomount|CONFIG_NOMOUNT|00_NoMount' patches scripts configs anykernel tests .github README.md` returns no matches.
- [x] Local gates passed: `bash -n scripts/*.sh tests/*.sh`, `sh -n anykernel/*/*.sh`, PyYAML workflow parse, all `tests/*.sh`, and `git diff --check`.

## Phase 2 — post-removal live CI (2026-11-26)

- [x] Phase-1 commit `02693f0049c992a13a454590024e6d42180c7e87` was pushed to `origin/main`.
- [x] `ci-validate.yml` passed on the post-removal commit: https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45744880175.
- [x] Production audit found the BORE helper defaulted to the repository root instead of the Android common kernel tree. Commit `5f477dfca55c16a9f76fa5755ab88786795e02e8` set `KERNEL_SOURCE_DIR=.tmp/kernel_src/kernel_platform/common`, pinned SUSFS `gki-android14-6.1` at `f76b81f2a6bf98e4029cc0c823c054edbec29803`, and was pushed.
- [x] The requested BORE=true probe run https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45746500324 failed at the real patch applicability gate (`kernel/sched/core.c` and `kernel/sched/fair.c` context mismatch); no build or package was allowed. The follow-up production run disabled BORE as instructed for a non-CRC failure and passed: https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45746960719.
- [x] Target built: OnePlus Ace 3V `6.1.118-android14-11-o-gac2e718ebee`, `bootstrap_stock_symvers=false`, `custom_driver_name=""`, BORE disabled after the explicit incompatibility evidence. `verify_kconfig` printed `PASS (oneplus-ogki)`; `verify_abi_crc` printed `CRC CHECK: PASS (15711 symbols, zero CRC drift; added=29 non-reference exports; bore=0)`.
- [x] Stock resolver recorded `resolver_source=cache` and `resolver_sha256=bf00d20b3871308202960d25d15a8d5cc09a084f8afea863f107039b3cfbc93c`.
- [x] Artifact `oneplus-ace3v-6.1.118-android14-11-o-gac2e718ebee` uploaded at https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45746960719/artifacts/15085296572. Downloaded ZIP SHA256 is `93b0d9b66e123761ca1a53b110b007cda677c9031901a1d0c89c67b001f24e80`; sidecar agrees. `unzip -Z1` confirmed root-level `META-INF/com/google/android/update-binary`, `META-INF/com/google/android/updater-script`, `tools/ak3-core.sh`, `anykernel.sh`, and `Image`, with no `.git/` or parent-directory nesting.

## Phase 3 — read-only SELinux/AVC comparison (2026-11-26)

Sources cloned at depth 1 into `.tmp/audit/` and removed after inspection: BakaSU `main` `57b2db6076f439cfd489f14576444e8f0f2a25`, SUSFS `gki-android14-6.1` `f76b81f2a6bf98e4029cc0c823c054edbec29803`, KernelSU-Next `dev` `3660779ea2e2fe1adb27616d8aad9ffaad717501`.

| Area | BakaSU | SUSFS v2.4.0 | KernelSU-Next |
|---|---|---|---|
| `selinux_hide` | `kernel/feature/selinux_hide/selinux_hide.c:75-105,137-142` registers and toggles the feature; `selinux_hide_auto.c:206-300` uses `backup_sepolicy` for context/access decisions; `:338-340` normalizes `avd.seqno`; `:623-670` replaces the SELinux status `open` operation with a fake page. `kernel/include/uapi/feature.h:9` exposes ID 4. No `patch_fops_open` or `dirtyselinux` identifier exists. | SUSFS patch supplies compatibility hooks/static-key integration used by BakaSU (`selinux_hide_susfs.c:16-81`), including AVC access rewrite and sequence normalization; it is not a second standalone hide feature. | `kernel/feature/selinux_hide.c:104-197` rewrites context/access via `backup_sepolicy`; `:443-511` builds fake status with policyload/sequence values; `:516-614` installs text/LSM/status hooks and rollback. `uapi/feature.h:9` uses ID 4. No `patch_fops_open` or `dirtyselinux` identifier exists in this checkout. |
| AVC spoofing | No independent AVC implementation; BakaSU dispatches SUSFS command at `kernel/supercall/dispatch.c:1182-1183` and userspace calls it in `userspace/ksud/src/android/susfs/api/features/avc_spoofing.rs:14-21`. | `kernel_patches/fs/susfs.c:2212-2227` owns `susfs_is_avc_log_spoofing_enabled` static-key enable/disable; `50_add_susfs_in_gki-android14-6.1.patch:2469-2480` consumes it at the AVC path. | `kernel/susfs/susfs_avc_spoof.c:34-39` targets `slow_avc_audit`; the companion legacy path `kernel/extras.c:85-98,100-185` is explicitly `#ifdef CONFIG_KPROBES` and registers a kprobe. This is a separate implementation and should not be layered over SUSFS. |

- [x] Port assessment: no SELinux hide or AVC code was added. KernelSU-Next's standalone hide duplicates BakaSU/SUSFS hooks and risks text-patch/LSM conflicts and KMI drift; its legacy AVC path disappears when `CONFIG_KPROBES=n`, while SUSFS's static-key/inline integration remains the selected implementation. Any future port requires a separate feature ID/UI command, exact kernel-version guards, and a fresh `Module.symvers` zero-drift gate.

## Active A/B slot regression repair (2026-11-26)

- [x] Baseline hash `a2dfa850fcbedf6cf060460f824f224f68724ffe886019265ff0f7cb5a29a639` preserved. Mock A/B cmdline `_b`: BASELINE exit=1, stderr `anykernel: A/B device requires active slot suffix`; MODIFIED exit=0 selects `boot_b`; ROLLBACK restores original bytes and exit=1 for the same input. Exact commands/stdout/stderr/hashes: `artifacts/VERIFICATION.txt`.
- [x] Both POSIX templates preserve test overrides and existing `$slot`, try `/system/bin/getprop`, `/vendor/bin/getprop`, PATH `getprop` (suffix then slot), then `AK3_PROC_CMDLINE` / legacy `AK3_CMDLINE_FILE` / `/proc/cmdline`. Token parser uses shell builtins and validates slot values; never guesses active slot from partition names. Android utility paths are appended; fatal messages call `ui_print` when available. Regression cases for both branches cover minimal PATH, `_b`/`a` cmdline, real mock getprop including empty/missing cmdline, slot precedence, missing-slot FAIL and UI output.
- [x] Ran each `sh -n anykernel/*/*.sh`, every scripts/tests file with `bash -n`, PyYAML on all workflows, every `tests/*.sh`, and `git diff --check`: exit=0. Shellcheck absent locally; real CI lint remains required. YAGNI review: slot resolver only; no patch/config/ABI changes. `.tmp/` emptied, ignored files not added; build workflow push filters do not match the changed AnyKernel/tests/PROGRESS paths. Four transaction role artifacts reopened.
- [x] Commit `6728e5e` pushed to `origin/main`. `gh run watch 45753917458 --exit-status --interval 10` returned exit=0: https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45753917458 — success, including shell syntax/lint, YAML and all fixture gates; both active-slot fixture groups PASS. `gh run list --commit` lists only `ci-validate`; no OnePlus/GKI build was triggered. Literal runner log retained locally in ignored `artifacts/transaction/active-slot/ci-45753917458.log`.

## init_boot marker warning-only gate (2026-11-26)

- [x] Preserved original SHA256 `9d605ef24c80d7d63e7a513cd8568a9efab304e65fcce825a359dcf1ced30d50`. Same mock `init_boot_a` containing `kernelsu.ko`: BASELINE exit=1, stderr `anykernel: refusing init_boot marker: kernelsu.ko`; MODIFIED exit=0, warning asks to restore stock init_boot.img after stable Built-in boot and selects boot_a; ROLLBACK restores original hash and marker failure exit=1. Literal commands/stdout/stderr/hashes in `artifacts/VERIFICATION.txt`.
- [x] Both templates: `ak3_check_markers` calls new POSIX/builtin-only `ak3_warn`, prefers `ui_print`, falls back to stderr; all six exact shared markers warn and continue. `init_boot=preserved` avoids falsely labelling patched init_boot as stock. Other slot/page-size/KMI/boot/unpack gates unchanged. Both branch tests verify all six warnings, clean and near-name silence, empty-PATH UI delivery, and mock magiskboot boot-unpack reached with exit=0 and unchanged mock partition hashes. Existing A/B, ZIP framework and SHA256 regressions retained and PASS.
- [x] Local gates exit=0: individual `sh -n` for both templates, `bash -n` for every scripts/tests shell file, PyYAML for all workflows, all four `tests/*.sh`, and `git diff --check`. Shellcheck absent locally; CI lint remains required. Self-contained executable rollback and reconstructing diff verified, all four role files reopened. YAGNI review: only marker warnings/accurate metadata plus tests; no kernel/config/ABI changes. `.tmp/` emptied; ignored artifacts remain untracked. Changed paths do not match either build workflow push filter.
- [x] Commit `90c507a` pushed to `origin/main`. `gh run watch 45756087389 --exit-status --interval 10`: exit=0, success — https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45756087389. Real runner passes shell syntax/lint, YAML and all fixtures; `init_boot warning fixtures: PASS` for OnePlus and GKI, A/B regression and ZIP gates PASS. `gh run list --commit` shows only ci-validate; neither kernel build workflow was triggered. Runner log retained in ignored `artifacts/transaction/initboot-warning/ci-45756087389.log`.

## Native AnyKernel3 core migration (2026-11-26)

- [x] Read project instructions and current templates; original copies preserved in ignored `artifacts/transaction/native-ak3/`.
- [x] Cloned upstream inside `.tmp/ak3-ref`, checked out manifest SHA `41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1`.
- [x] Replaced both templates with native properties/configuration/core/split_boot/flash_boot. Upstream uses uppercase BLOCK/IS_SLOT_DEVICE/RAMDISK_COMPRESSION/PATCH_VBMETA_FLAG/NO_BLOCK_DISPLAY and SLOT/BIN/AKHOME, not the lowercase spellings in the requested sketch. No custom dd/magiskboot/format/slot/partition logic remains; optional init_boot scanner was removed entirely, leaving init_boot untouched.
- [x] Replaced obsolete parser/slot fixtures with native-core smoke: actual update-binary file_getprop reader, correct properties and configuration, split_boot before flash_boot, minimal PATH, ramdisk-less/ramdisk boot, clean/patched init_boot untouched, split/flash abort propagation. Offline ZIP tests for both targets retain root META-INF/update-binary/updater-script, tools/ak3-core.sh + tools/magiskboot, anykernel.sh/Image, SHA256, no .git/nesting, executable modes, and missing-framework hard failures. Real pinned upstream ZIP/checksum smoke also passed.
- [x] Same mock boot v4 input: BASELINE exit=1 (`anykernel: KERNEL_FMT not produced by magiskboot unpack`), MODIFIED exit=0 (`split_boot` then `flash_boot`), ROLLBACK restores SHA256 `4359f03f412180b38f9c73a52e66f437288e0a3a1f42cd265c61d70f841ecf02` and the same original failure. Modified SHA256 `6303609c315828aa9cc50074f94ee2330eb2e9a35a4b6186bcb7b1bcaba73933`. Reconstructing patch and executable rollback passed; all four artifacts reopened. Exact commands, inputs, stdout/stderr and statuses: `artifacts/VERIFICATION.txt`.
- [x] Pushed native-core fix and lint annotation to main; `gh run watch 45757788537 --exit-status --interval 10` exited 0 with success: https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45757788537 (head 980edcbbd891a9876125debe790cab09e9543b4a). Shell syntax/lint, YAML and all fixtures PASS. `gh run list --commit` lists only ci-validate; neither build workflow was triggered. Full runner log retained in ignored `artifacts/transaction/native-ak3/ci-45757788537.log`.
- [x] Local gates exit=0: `find scripts tests -name '*.sh' -print0 | xargs -0 -n1 bash -n`; `find anykernel -name '*.sh' -print0 | xargs -0 -n1 sh -n`; PyYAML parses all three workflows; every `tests/*.sh` PASS; `git diff --check` PASS. shellcheck/actionlint and busybox/dash are not installed locally; optional checks were not claimed as executed. Full literal log: `artifacts/transaction/native-ak3/local-gates.log`.
- [x] YAGNI review: both templates reduced to 26 lines, upstream framework unchanged, no kernel/config/source/ABI edits; README corrected to native flow and manual image compatibility selection. Only anykernel/tests/README/PROGRESS change, none match kernel build push filters. `.tmp/` emptied; artifacts remain ignored and untracked.
- [x] Initial native-core commit `c4fae593244fb3b90902b4b4d25fe0725d2f9fee` pushed. Real CI run `45757628577` exposed ShellCheck SC2289 on upstream quoted `properties()` metadata (watch exit=1). Added a narrowly scoped suppression with explicit rationale; no functional workaround or framework mutation. Failure log preserved in `artifacts/transaction/native-ak3/ci-45757628577-failed.log`.
- [x] Downloaded ShellCheck v0.10.0 into project-local `.tmp/lint/`, reran real `shellcheck -s sh` for both templates and `shellcheck -s bash` for all scripts: PASS. All syntax/YAML/four fixture suites/diff checks rerun and PASS (literal `local-gates-final.log`). Final BASELINE/MODIFIED/ROLLBACK recheck retained exit statuses 1/0/1, rollback hash and diff reconstruction PASS. Linter and all test temp files removed; `.tmp/` empty.
- [x] Final handoff: upstream configuration and two native calls independently reviewed; original error reproduced only by baseline/rollback, modified core harness succeeds; ZIP framework and SHA256 verified. Four role paths reopened under `/home/yuukari_ne/My-Project/custom-phone/kernel-build/artifacts/`; `.tmp/` empty and no ignored files staged.

## OnePlus Ace 3V bootloop diagnosis and release gate (2026-11-26)

- [x] Bound target: OnePlus Ace 3V `6.1.118-android14-11-o-gac2e718ebee`; original workflow/scripts/tests/docs copies preserved in ignored `artifacts/transaction/bootloop-diag/`. Investigation remains offline/CI; no device, adb, fastboot or flash trial used.
- [x] Downloaded latest known successful artifact from run `45746960719` (ZIP SHA256 `93b0d9b66e123761ca1a53b110b007cda677c9031901a1d0c89c67b001f24e80`) and full runner log into `.tmp/diag/`.
- [ ] Add evidence-backed source/release and Image gates, update matrix refs, tests, docs, then run a clean build.

- [x] Layer 1 evidence: downloaded artifact `93b0d9b66e123761ca1a53b110b007cda677c9031901a1d0c89c67b001f24e80` from run `45746960719`; `file Image` reported `Linux kernel ARM64 boot executable Image, little-endian, 4K pages`, but `strings` reported `Linux version 6.1.141+ ...`. This differs from every character of expected `6.1.118-android14-11-o-gac2e718ebee` and contains forbidden `+`. Embedded config showed `CONFIG_MODVERSIONS=y`, `CONFIG_LTO_CLANG_THIN=y`, `CONFIG_CFI_CLANG=y`, `CONFIG_SHADOW_CALL_STACK=y`, `CONFIG_MODULE_SIG=y`, `CONFIG_LOCALVERSION=""`, `# CONFIG_LOCALVERSION_AUTO is not set`, `CONFIG_KPROBES=y`, and `# CONFIG_TRIM_UNUSED_KSYMS is not set`.
- [x] Layer 2 evidence: old ZIP `anykernel.sh` contained `ak3_unpack_boot`, homemade `KERNEL_FMT` parsing and no `split_boot;`/`flash_boot;`; its bundled upstream core defines `split_boot()` at line 68, `flash_boot()` at line 313, and `setup_ak()` at line 878. The current templates use the pinned native core contract and are directly checked against upstream SHA `41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1` by `scripts/verify_anykernel_core.sh`.
- [x] Layer 3 evidence: build log shows `kconfig verification: PASS (oneplus-ogki)`, `SUSFS_VERSION: v2.4.0`, BakaSU `using SuSFS Inline hook`, and `CRC CHECK: PASS (15711 symbols, zero CRC drift; added=29 non-reference exports; bore=0)`. Search of full log found no fuzz, offset, implicit-declaration, section-mismatch, or compiler error diagnostics. Empty `custom_driver_name` was a no-op; no evidence attributes the bootloop to BakaSU/SUSFS/custom name.
- [x] Layer 4 root cause: workflow used floating `oneplus/sm7675_b_16.0.0_ace_3v`; fetched source SHA `bfe6121a6dc9ee06f5c36c2ff9a7bc1f39812c2a` has `Makefile SUBLEVEL=141` (API branch history confirms the target `6.1.118` commit is `2f2512ac1091bb2b28c20306fa86d890e8f3f01f`). The matrix labeled that source as stock `6.1.118`, so the build was semantically mislabeled and the old package could not boot against the target ABI/banner.
- [x] Fixed release derivation: matrix pins source `2f2512ac1091bb2b28c20306fa86d890e8f3f01f` for 6.1.118 and `3bcb2b3b5f0ad367fef9c7463be0cb17e0b7c2a8` for 6.1.141; checkout accepts branch or SHA; `scripts/build_oneplus.sh` checks source base version, sets only `LOCALVERSION` to the target suffix, then runs `scripts/verify_image_release.sh` before ABI/package. `CONFIG_LOCALVERSION` remains empty.
- [x] Added `scripts/verify_image_release.sh`: requires actual `file` ARM64 boot executable format, exactly one embedded `Linux version`, exact byte-for-byte `STOCK_UNAME`, and rejects `+`, `-dirty`, truncation and mismatch. Added `tests/test_image_release.sh` valid/mismatch/dirty fixtures and CI invocation.
- [x] Added direct pinned upstream core gate `scripts/verify_anykernel_core.sh`; `tests/test_anykernel.sh` clones manifest SHA `41f04bd...` and checks actual `tools/ak3-core.sh` function names plus both templates. All tests passed locally.
- [x] Local gates after fix: `shellcheck -s bash scripts/*.sh` (ShellCheck v0.10.0), `bash -n scripts/*.sh tests/*.sh`, `sh -n anykernel/*/*.sh`, PyYAML all workflows, all `tests/*.sh`, and `git diff --check` exit 0. Literal diagnostic log and artifact evidence remain in ignored `.tmp/diag/` until commit cleanup.
- [ ] Push, pass `ci-validate`, run clean target build with `bootstrap_stock_symvers=false`, `enable_bore=false`, and inspect the new artifact offline.

## 2026-11-26 OnePlus UTS bootstrap rerun audit
- Live run [45813171456](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45813171456) reached the build gate after bootstrap, then failed before compilation with `source kernel base mismatch: expected=6.1.118 actual=6.1.118-g2f2512ac1091-dirty`.
- Root cause: `make kernelrelease` includes the SCM dirty suffix while patch sources are intentionally applied; this is not a VERSION/PATCHLEVEL mismatch.
- Fix in `scripts/build_oneplus.sh`: compare the authoritative `make kernelversion` result and pass `CONFIG_LOCALVERSION_AUTO=n` to `kernelversion`, `olddefconfig`, and the Image/modules build so the target UTS suffix is supplied only from `STOCK_UNAME`.
- Local evidence: `bash -n scripts/build_oneplus.sh` exit 0; `git diff --check` exit 0; rollback copy hash equals pristine baseline.

## 2026-11-26 Live OnePlus build verification (fixed UTS gate)
- Successful run: [build-oneplus #45818209541](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45818209541), commit `62ed9c06a15c838a292180a0bcb3b7b208854e91`.
- Target: OnePlus Ace 3V / `6.1.118-android14-11-o-gac2e718ebee`; `bootstrap_stock_symvers=true`, `enable_bore=false`, empty `custom_driver_name`.
- Resolver: `resolver_source=cache`, stock baseline SHA256 `842f1ce784f44235427dfe2710a17b452560f102fda6ed988294c3833c872d50`.
- Gates: `kconfig verification: PASS (oneplus-ogki)`; `CRC CHECK: PASS (15552 symbols, zero CRC drift; added=29 non-reference exports; bore=0)`.
- Artifact: `oneplus-ace3v-6.1.118-android14-11-o-gac2e718ebee.zip`; embedded checksum `e854e87602a1281ea14972f5eaccc3dc0f581974943184b6bc3fb29679a12330`.
- ZIP verification: `unzip -tq` PASS; root contains `META-INF/com/google/android/update-binary`, `META-INF/com/google/android/updater-script`, `tools/ak3-core.sh`, `tools/magiskboot`, `anykernel.sh`, `Image`; no parent-directory nesting.
- Embedded Image: `Linux kernel ARM64 boot executable Image, little-endian, 4K pages`; exact release `Linux version 6.1.118-android14-11-o-gac2e718ebee ...`.
- Post-fix validation: [ci-validate #45825342271](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45825342271) PASS.

## 2026-11-27 Ace 3V UTS/ABI regression audit
- [x] Active target scan covered `configs/`, `scripts/`, `.github/workflows/`, `patches/`, `tests/`, `anykernel/`, and `README.md`. The only active Ace 3V target now is the exact `6.1.118-android14-11-o-gac2e718ebee6`; a static regression fixture rejects the truncated `...ebee,` matrix value. The previous production run embedded `...ebee` because the workflow matrix literal itself was one character short; `build_oneplus.sh` did not truncate it (it now compares `kernelversion` and supplies the complete expected suffix).
- [x] `scripts/verify_image_release.sh` remains a binary gate: it extracts one `Linux version` from the ARM64 `Image` and compares every character. `tests/test_image_release.sh` now covers the exact `...ebee6` target, dirty output, and one-character truncation; all pass.
- [x] ABI audit evidence: run `45746960719` used source SHA `bfe6121a6dc9ee06f5c36c2ff9a7bc1f39812c2a`, resolver cache SHA `bf00d20b3871308202960d25d15a8d5cc09a084f8afea863f107039b3cfbc93c`, and reported 15,711 reference symbols. Run `45818209541` used pinned source SHA `2f2512ac1091bb2b28c20306fa86d890e8f3f01f`, resolver cache SHA `842f1ce784f44235427dfe2710a17b452560f102fda6ed988294c3833c872d50`, and reported 15,552 reference symbols. The 159 difference follows the stock baseline/source revision change, not NoMount or commit `62ed9c0`.
- [x] `scripts/verify_abi_crc.sh` compares every reference symbol: a missing candidate entry increments `missing`, contributes to `drift`, exits 1, and is now reported as `missing_stock`. The new fixture deletes `bar` from the candidate and confirms `missing candidate symbol: bar`, `missing_stock=1`, and non-zero exit. The production 15,552-symbol run passed, therefore `missing_stock=0` and CRC drift is zero.
- [x] Local gates after the fix: `bash -n`, `sh -n`, YAML parse, all `tests/*.sh`, and `git diff --check` passed. `shellcheck`/`actionlint` are unavailable locally and remain conditional CI gates.

## 2026-11-27 Production rebuild with full Ace 3V UTS
- [x] Commit `21bbc974e27174a50d4e3ffb756acaed7067953b` pushed. CI validation: [45935930851](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45935930851) PASS.
- [x] Production build: [build-oneplus 45936055472](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45936055472) PASS for `6.1.118-android14-11-o-gac2e718ebee6`, `enable_bore=false`, `bootstrap_stock_symvers=true`.
- [x] Artifact: `oneplus-ace3v-6.1.118-android14-11-o-gac2e718ebee6.zip`; SHA256 `d70ebb1c77606b8779640241d3bf0d8c5d08a005999f05efda0fb2d6dd03b450`.
- [x] Offline ZIP gate: `unzip -tq` PASS; root entries include `META-INF/com/google/android/update-binary`, `META-INF/com/google/android/updater-script`, `tools/ak3-core.sh`, `tools/magiskboot`, `anykernel.sh`, and `Image`.
- [x] Binary Image gate: `Linux kernel ARM64 boot executable Image, little-endian, 4K pages`; exact line `Linux version 6.1.118-android14-11-o-gac2e718ebee6 (runner@runnervm0j63q) (Ubuntu clang version 18.1.3 (1ubuntu1), Ubuntu LLD 18.1.3) # SMP PREEMPT `.
- [x] Live gates: `kconfig verification: PASS (oneplus-ogki)`; `CRC CHECK: PASS (15552 reference symbols, zero CRC drift; missing_stock=0 changed_crc=0 added=29 non-reference exports; bore=0)`; provenance `resolver_source=bootstrap`, resolver SHA256 `842f1ce784f44235427dfe2710a17b452560f102fda6ed988294c3833c872d50`.

## Rust ktool verification integration (2026-11-27)

- [x] Bound Rust target `tools/ktool/` without touching `anykernel/*/anykernel.sh`, kernel build/clang calls, or `local-builds/`. Added deterministic tracked `Cargo.lock`; ignored `tools/ktool/target/`.
- [x] `tools/ktool` now provides `inspect-image`, `verify-abi`, `verify-kconfig`, `inspect-boot`, and `package-local`. `inspect-image` enforces ARMd/raw-or-compressed detection, one exact `Linux version`, rejects truncation/`-dirty`/`+`, and supports IKCONFIG require/forbid arguments. `verify-abi` reports every missing stock symbol and changed CRC and exits non-zero on either; `verify-kconfig` ports the existing required/forbidden/protected symbol gate.
- [x] Thin wrappers now delegate `scripts/verify_image_release.sh`, `scripts/verify_abi_crc.sh`, and `scripts/verify_kconfig.sh` through `${KTOOL_BIN:-$repo/tools/ktool/target/release/ktool}` with a one-time `cargo build --release --locked` fallback. `build_oneplus.sh` and `build_gki.sh` therefore consume the Rust gates without changing compile commands.
- [x] Added `Swatinem/rust-cache@v2`, `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --locked`, release build, and `KTOOL_BIN` export to `ci-validate.yml`; added cache/build/export to both `build-oneplus.yml` and `build-gki.yml` because both use shared verify wrappers.
- [x] Local evidence: Rust fmt/clippy/test (6 tests) PASS; release build PASS; all `tests/*.sh`, shell syntax, YAML parse, and `git diff --check` rerun after integration PASS. Shellcheck/actionlint availability remains CI-conditional.
- [x] Transaction roles reopened: `artifacts/transaction/ktool-integration/MODIFIED_FILE`, `DIFF_FILE`, `VERIFICATION.txt`, executable `ROLLBACK.sh`; rollback copy restored byte-for-byte.
- [x] Commit `a92a064b139ceedb4c2fcab4debcb9b4a41a8574` pushed to `origin/main`; `ci-validate` run [45971184419](https://github.com/Yuukarine/bakasu-gki-kernel/actions/runs/45971184419) PASS. Rust cache step executed with workspace `tools/ktool`, saved a 4.1 MB cache on this first run (no prior cache hit), and `KTOOL_BIN` was exported into all fixture steps; no build workflow was dispatched.
