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

- [x] Shared BakaSU/SUSFS v2.4.0/NoMount fragment is in `configs/bakasu_stealth.fragment`; protected debug/ABI flags remain enabled and log/debug/localversion leak flags are disabled.
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
- [x] Final state is ready for a real source/toolchain run; build completion remains gated on a real source checkout, stock `Module.symvers`, zero CRC drift, exact KMI, and package checksum.

## Custom BakaSU driver display-name audit (2026-11-25)

- [x] Downloaded `kernel/Kbuild` and `kernel/Makefile` from the manifest source `https://github.com/Baka-SU/BakaSU.git#main` into `.tmp/bakasu-source-check/`; `Kbuild` defines `KSU_VERSION_FULL` on the first assignment (then performs placeholder substitutions), `KSU_VERSION` is a separate numeric expression, and `Makefile` has no driver-name assignment. Temporary source files were removed after inspection.
- [x] Added `scripts/set_bakasu_driver_name.sh`. Empty `CUSTOM_DRIVER_NAME` is a no-op; non-empty values are limited to 64 Unicode characters, reject controls/newlines and `"`, `\\`, backtick, `$`, whitespace, and unsupported punctuation, then atomically replace only the first `KSU_VERSION_FULL :=` line in the discovered BakaSU `Kbuild`. `KSU_VERSION`, `CONFIG_LOCALVERSION`, `uname -r`, and exported symbols are untouched.
- [x] Added `custom_driver_name` string inputs (default empty) to both build workflows. The value is passed only through `env:` and the helper runs after source integration and before `olddefconfig`.
- [x] Added `tests/test_driver_name.sh` and CI invocation. Fixture evidence: empty value preserves the file SHA; `v4.2.0-⚡Yuukari⚡@BakaSU` updates the exact display assignment while preserving `KSU_VERSION := 30701`; quote, dollar, newline, and 65-character values fail with `custom_driver_name: FAIL:`.
- [x] README usage documented. `bash -n`, YAML parse, driver-name fixtures, `git diff --check`, and the existing Kconfig/CRC/AnyKernel gates pass.

## Pre-push production audit (2026-11-25)

- [x] Placeholder/stub scan over `.github/`, `patches/`, `configs/`, `scripts/`, and `anykernel/`: no `TODO`, `FIXME`, `placeholder`, `example.com`, `CHANGE_ME`, `0000000`, or mock download/no-op command remained.
- [x] Remote refs checked with `git ls-remote --exit-code`: BakaSU `main` (`57b2db6076f439cfd489f14576444e8f0f2f0a25`), SUSFS GitLab `master` (`30e66dc3a5c65954de865afd8f44682866887544`), NoMount-Suite `main` (`295035bc03771fddf8eccf8a55f4462e4e706935`), OnePlus-BakaSu_NMS `master` (`3710b8285978986af9fdf7ee43d3fd0853a0fe61`), WildKernels GKI `main` (`54d549fd398a2ccf2146785ab9b3e7b8a6808936`) and `droidspaces-resource-limits` (`fd815b66c5c1ab1b4068ad194601f73302e83652`), firelzrd BORE `main` (`575c13bd2d8a0d96a2d445a87d5a71d20890b631`), and AmneziaWG module `master` (`63ed35de3d3f135b17e8eae0b84949e7700303be`). Dead GitHub SUSFS and dead AmneziaWG kernel URLs were replaced; OnePlus default ref `android14-6.1.118` was replaced by live `master`.
- [x] `kernel/Kconfig` fetched from `https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/Kconfig` into `.tmp/audit/`; exact symbols confirmed: `CONFIG_KSU_SUSFS` is “SUSFS Inline Hook”, `CONFIG_KSU_TRACEPOINT_HOOK` and `CONFIG_KSU_MANUAL_HOOK` are the duplicate hook selectors, and `CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT` does not exist. The fragment/validator now remove the nonexistent symbol and reject both duplicate hooks; negative fixture covers tracepoint enablement.
- [x] `build-oneplus.yml` and `build-gki.yml` now free runner disk space (`/usr/share/dotnet`, `/opt/ghc`, `/usr/local/lib/android`, Docker prune) before clone/build. Stock bootstrap runs before patch-source application, so the optional baseline is genuinely unpatched; cache metadata and resolver source remain recorded.
- [x] BORE fallback downloads the pinned firelzrd 6.1 patch only when no local patch exists (`curl --retry`), merges `oneplus-bore.fragment`, applies the patch, then olddefconfig/verify/build/`verify_abi_crc.sh --bore`; the raw URL returned HTTP 200 during audit.
- [x] `patches/sources/manifest.tsv` now carries real URL/ref pairs. `scripts/apply_patch_sources.sh` verifies each selected ref and records its SHA; local patches are applied, while source-only integrations are explicitly logged as `source-verified-no-local-patch` instead of silently echoing a mock step. Full selected-feature fixture run passed and produced a provenance log.
- [x] AnyKernel slot detection corrected for POSIX operator precedence (both `boot_a`/`boot_b` and `init_boot_a`/`init_boot_b` now identify A/B correctly). Existing fixtures pass active-slot skip, opposite-slot failure, six exact ramdisk markers, near-name allow-list, page-size smaps fallback, KMI suffix, and sublevel gates.
- [x] Popup decision for tracked `artifacts/`: `scripts/ask_user_popup.sh` returned `no`; artifacts were retained and not untracked. `.tmp/audit/` and all audit fixtures are removed before commit; `.tmp/worktrees/` is the only retained temporary tree.
- [x] Final audit gates rerun after fixes: `bash -n scripts/*.sh tests/*.sh`, `sh -n anykernel/*/*.sh`, PyYAML workflow parse, `./scripts/verify_skill.sh`, `./tests/test_kconfig.sh`, `./tests/test_abi_crc.sh`, `./tests/test_anykernel.sh`, `git diff --check`; `shellcheck` and `actionlint` are not installed locally and remain conditional in CI.
