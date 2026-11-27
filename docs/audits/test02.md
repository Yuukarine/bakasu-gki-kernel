# Ace 3V CN01 16.0.3.500 — test-02 investigation

## Verdict: NO-GO pending complete ROM provider evidence

No production/test-02 ZIP is certified by this audit. No device commands were run.
No change to UTS_RELEASE, CONFIG_MODULE_FORCE_LOAD, or radio-related Kconfig is
justified by the available evidence. The expected release remains
`6.1.118-android14-11-o-gac2e718ebee6`.

## Wi-Fi: proved binary/config facts

- test-01 run45962274577: 15,615 reference symbols, 0 missing/changed against the
  *bootstrap* baseline. That gate covered neither ROM module dependencies nor
  Android protected exports.
- ROM system_dlkm directory/rfkill vermagic: `...g7c70fb1cc0b8`.
  Vendor cfg80211/cnss2/kiwi vermagic: `...geb5e030f21ba` (a THIRD suffix).
  Working uname: `6.1.118-android14-OP-BAKASU-huangdihd`.
  `kernel/module/version.c:80–87` at source65c3035422d899d95bfde4e30dc426712ffe52f2
  skips the release token when module CRCs exist (`same_magic`, `has_crcs`).
  All supplied vermagic tails match `SMP preempt mod_unload modversions aarch64`.
  Release suffix mismatch alone is NOT proof of rejection; no renaming workaround.
- Working lsmod and dmesg show **qca_cld3_qca6750 + icnss2**, not kiwi+cnss2.
  Test-01 lsmod has icnss2 but neither cfg80211 nor rfkill nor qca driver loaded.
- Both embedded configs: CFG80211=n, RFKILL=m, MODVERSIONS=y,
  TRIM_UNUSED_KSYMS=n, MODULE_FORCE_LOAD=n, ThinLTO/CFI/KPROBES=y.
  Working compiler Android clang17.0.2 versus test-01 Ubuntu clang18.1.3;
  no imported kernel CRC mismatch was found, so compiler/config changes are not
  asserted to be the cause.
- Recovered all15,285 contiguous Image vmlinux ksymtab/CRC entries using relative
  name references and adjacent CRC table; module_layout CRC `0xea759d7f` matches
  ROM. Every one of730 unique referenced kernel exports matches all supplied
  consumers. ROM import/export extraction used host kmod on actual ELF tables.

### Deterministic protected-export blocker

Image SHA256 `a5c759017eccf47eb7eae651161d95fb75f7d26f540f91003b7b30338a5a6344`
contains the entire349-entry source protected-export table at byte20958432,
including15 rfkill exports. The embedded generated X509 certificate at34733824
has serial `630A085A222B74A765E50DCFB7F2018AB07A3228`; ROM rfkill PKCS7 signer
identifier is `1921C1793467BA60164A1DCC62D79C2464532391`. The build log explicitly
records `GENKEY certs/signing_key.pem`. The image certificate key ID also differs.
No additional trusted key is configured (`CONFIG_SYSTEM_TRUSTED_KEYS=""`).

Pinned kernel `kernel/module/main.c:1281–1286` returns `-EACCES` for an untrusted
module exporting a protected symbol. This is an independent deterministic blocker
for the supplied stock rfkill under test-01's new signing key, despite matching
CRC. Its downstream cfg80211 consumers cannot resolve rfkill until it is loaded.
The late supplied dmesg omits the *initial* rfkill/cfg80211 rejection, so this does
not establish that every original Wi-Fi failure had this sole cause.

The working reference huangdihd action (4cdf2311bc02555da0898a7de187cd63e239ff12,
`.github/actions/build-kernel/action.yml:912–920`) removes ALL protected exports.
This change is narrower: remove only15 independently observed rfkill export names
from the source list, retain334 other entries, SIG_PROTECT and all import/signature
checks, CRC/KMI data and kernel structures. No force-load. Actual source-list
experiment: `rfkill_protected_removed=15 remaining_protected=334`. New-build
runtime success is not yet claimed.

### ROM ABI evidence (counts are imports, not number of absent .ko files)

| Consumer | Imports | Kernel imports matching test-01 | Known module imports matching | Unverified provider imports | Known missing symbols / changed CRC | Vermagic tail mismatch |
|---|---:|---:|---:|---:|---:|---:|
| rfkill |58|58|0|0|0 / 0|0|
| cfg80211 |194|187|7|0|0 / 0|0|
| cnss2 |370|223|79|68|0 / 0|0|
| qca_cld3_kiwi_v2 |554|416|109|29|0 / 0|0|
| icnss2 |280|174|78|28|0 / 0|0|
| qca_cld3_qca6750 |488|400|84|4|0 / 0|0|

All16 consumers:3,081 imports;181 unresolved import rows (122 distinct symbols),
0 missing symbols and0 changed CRC **among providers actually observed**.
`missing_provider=181` means missing provider *evidence*, not proof that181 modules
are absent on the phone. Examples: ipc_log_string/context, qmi helpers, mhi, ipam,
qcom_va_md, OPlus project-info. Actual export tables for those providers have not
been supplied. modules.dep paths alone cannot prove their CRCs.

The new Rust gate fails closed on this profile. An import CRC is never used as
fabricated export evidence. The workflow preflight blocks expensive production
build/package until coverage is complete, and repeats the gate on the real built
Module.symvers before any eventual package. The separate stock baseline CRC gate
is unchanged.

## SELinux: complete upstream SUSFS manual, no mixed backend

Previously hooks.c selected Baka manual while helper dropped all5 selinuxfs hunks.
Pinned helper `ed778e9e89ffbd6cca1bb83de8a686bb10b01dc6` now retains the original5
hunks; no custom SELinux C code. Baka pinned cac1e79355ef451539f5c5ba9dc2bda1c64069de;
SUSFS pinned f76b81f2a6bf98e4029cc0c823c054edbec29803.

Full helper integration against28 original source files passed exit0, with seven
in-function guards and no selinuxfs drop. Gate result:

```
SELINUX HOOK CHECK: PASS (mode=susfs-manual selinuxfs_hunks=5/5 surfaces=attr/current,context,access,status)
```

Gate reverse-checks all5 ORIGINAL upstream hunks with zero fuzz, validates the four
surfaces/providers, rejects dropped-hunk build logs. Regression tests delete each
hunk separately and prove failure. Integration log SHA256:
`c8bf07210d7a7c094c1f9e26b5ed75d1e7e56a0686169abca95182021aa7e46a`.
Original SUSFS patch SHA256:
`adaed18bfa298d83c2d768f0433b7c87f418d157e88df0006d2d962dfb8f3144`.
This is source-integration evidence, not a completed kernel compilation/runtime.

## Validation and remaining acceptance

Rust fmt/clippy(-D warnings)/10 unit tests, shell syntax, ShellCheck0.11.0,
actionlint1.7.12, YAML and all8 shell fixture suites PASS locally. Production
workflows are dispatch-only to avoid unsolicited matrix builds on every fix push.
CI fixtures run `tests/*.sh`, including both new regression gates.

Still required before test-02 production publication: actual missing provider ELF
export tables (or independently verified ROM full Module.symvers); initial loader
error if the protected-export fix does not explain it; green final stock+ROM ABI
and Image/IKCONFIG gates; a successful full build and verified AK3 ZIP. The supplied
late dmesg alone is insufficient to claim Wi-Fi loads100%. No unverified ZIP is
placed into local-builds/test-02.

## Live execution

Implementation commit: `49b455d458bda1433c1ad9bc7cdfb34d9c608cbf`.
- ci-validate run **46035224939**: **success**, including new Rust and SELinux fixtures.
- build-oneplus run **46035380039**: **failure** in ROM evidence preflight,
  exit2, `missing_provider=181 missing_symbol=0 changed_crc=0`.
  BORE=false; selected only6.1.118. The6.1.141 matrix job skipped all target steps.
  Compilation/packaging did NOT run; no claim of a new kernel CRC/build PASS.
- No test-02 ZIP or SHA256 exists. Do not re-label test-01 as test-02.

Temporary input ELFs/logs were preserved under ignored local
`artifacts/test02-diagnostic-inputs/` (INPUTS.sha256), and exact-source experiments
under `artifacts/test02-source-evidence/`, before emptying `.tmp/`. No .ko/ZIP
was added to Git; local-builds/test-01 checksum still passes.

## ROM provider collection follow-up (489 modules)

**NO-GO: explicit stop-before-build condition remains active.** Actual ELF exports
resolved 133/181 rows, not all 181. New preflight (exit 2):

```
MODULE ABI CHECK: FAIL (imports=3081 modules=16 missing_provider=48 missing_symbol=0 changed_crc=0)
ktool: ROM module ABI requirements not satisfied
```

4,403 exports were extracted with host `modprobe --show-exports` from 489 unique
ELFs; SHA256/path/vermagic are recorded in the ABI profile. No export CRC was
inferred from an import. No original import requirement was changed. No ambiguous
provider and no newly resolved CRC mismatch occurred. All 25 remaining symbols
are absent from both this collection and the full recovered test-01 Image export
set; this is missing evidence, not a claim that the ROM cannot supply them.
Working lsmod contains qcom_ipc_logging, qcom_aoss, cmd_db and
oplus_bsp_boot_projectinfo, not present as providers in this collection. The storage
location of these missing providers is not yet proven.

| Symbol | Consumer module(s) |
|---|---|
| `cmd_db_read_addr` | `cnss2.ko` |
| `cmd_db_ready` | `cnss2.ko` |
| `get_Modem_Version` | `cnss2.ko`, `icnss2.ko` |
| `get_Operator_Version` | `cnss2.ko`, `icnss2.ko` |
| `get_boot_mode` | `cnss2.ko`, `icnss2.ko` |
| `get_eng_version` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko`, `qca_cld3_qca6750.ko` |
| `get_project` | `cnss2.ko`, `icnss2.ko` |
| `ipc_log_context_create` | `cnss2.ko`, `cnss_plat_ipc_qmi_svc.ko`, `icnss2.ko` |
| `ipc_log_context_destroy` | `cnss2.ko`, `cnss_plat_ipc_qmi_svc.ko`, `icnss2.ko` |
| `ipc_log_string` | `cnss2.ko`, `cnss_plat_ipc_qmi_svc.ko`, `icnss2.ko` |
| `msm_dump_data_register_nominidump` | `cnss2.ko` |
| `msm_gpio_mpm_wake_set` | `cnss2.ko` |
| `msm_minidump_add_region` | `cnss2.ko` |
| `msm_minidump_remove_region` | `cnss2.ko` |
| `qcom_iommu_get_mappings_configuration` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko` |
| `qcom_iommu_set_fault_handler_irq` | `cnss2.ko` |
| `qcom_smem_get` | `cnss2.ko` |
| `qcom_va_md_add_region` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko`, `qca_cld3_qca6750.ko` |
| `qcom_va_md_register` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko`, `qca_cld3_qca6750.ko` |
| `qcom_va_md_unregister` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko`, `qca_cld3_qca6750.ko` |
| `qmp_get` | `cnss2.ko`, `icnss2.ko` |
| `qmp_put` | `cnss2.ko`, `icnss2.ko` |
| `qmp_send` | `cnss2.ko`, `icnss2.ko` |
| `socinfo_get_serial_number` | `icnss2.ko` |
| `walt_get_cpus_taken` | `qca_cld3_kiwi_v2.ko`, `qca_cld3_peach.ko` |

No new production dispatch or test-02 package was made. SELinux5/5 and rfkill15
results above remain source-integration evidence, not a new successful build log.
Remaining acceptance: real missing provider ELFs or an authoritative ROM export
symvers, then strict zero-unverified preflight, full stock+ROM CRC build gates,
and only then publication. Input binaries are preserved locally under ignored
artifacts/test02-rom-provider-inputs/; none belong in Git.
