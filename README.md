# BakaSU GKI 2.0 / OGKI

A two-branch build skeleton with one shared BakaSU stealth core:

```text
configs/                 shared and conditional Kconfig fragments
patches/sources/         patch manifests and optional local C patch files (no custom SELinux/DeviceTree C patches)
scripts/                 patch application, Kconfig, CRC, packaging and fixture gates
anykernel/{oneplus,gki}  POSIX sh packaging templates
.github/workflows/        OnePlus, GKI matrix and validation CI
```

## Build

Use **Actions → build-oneplus** for OnePlusOSS/OGKI. The Ace 3V preset is Android 16 (OOS16/COS16), KMI `android14-6.1`, with stock banners `6.1.118-android14-11-o-gac2e718ebee6` and `6.1.141-android14-11-o-gffc54a6d2287`. HMBIRD is only selected for SM8735/SM8750/MT6991. BORE is applied before build and is accepted only when the post-build CRC gate reports zero drift.

Use **build-gki** for the shared RedMagic/Xiaomi matrix: `android13-5.15`, `android14-6.1`, `android15-6.6`, and `android16-6.12`. The last family disables BBG, Droidspaces and NTSync. Stock `Module.symvers` resolves from explicit input, Actions cache, GKI prebuilt, then optional `bootstrap_stock_symvers`.

Every workflow records source SHA, KMI generation, page size, stock `uname -r`, resolver source and SHA256 artifacts. Cache metadata is checked against KMI/page size/stock banner/source/toolchain before reuse; a cache miss can bootstrap an unpatched stock baseline. CI never flashes a device.

## Flash rules

- **OnePlus:** use the matching exact `uname -r`/KMI banner; do not flash across sublevels. Test with `fastboot boot` first where supported.
- **RedMagic/Xiaomi:** keep stock `init_boot`; use the GKI AnyKernel template's `magiskboot unpack`/`KERNEL_FMT` handling and matching `4k`/`16k` page size. A/B slot resolution is explicit; missing `init_boot` on a valid A/B device is skipped only when both slot partitions are absent.

## Runtime roles

The kernel owns BakaSU + SUSFS v2.4.0 + dormant NoMount + TMPFS XATTR. Choose **one** metamodule, NoMount Suite or Mountify; never configure duplicate `open_redirect` rules. HMA handles app hiding, TrickyStore handles key/TEE state, and ZN-AuditPatch/Zygisk/LSPosed handle userspace policy. Keep BakaSU Manager SELinux-hide and AVC-spoof options disabled (zero-trust).

## Local gates

```sh
bash scripts/verify_kconfig.sh --help
bash scripts/verify_abi_crc.sh --help
./scripts/verify_skill.sh
```

Run the fixture suite through `ci-validate.yml`; all temporary fixtures live under `.tmp/` and are removed after the run.

`scripts/apply_patch_sources.sh` keeps patch-only sources (Unicode Bypass, Faster SDP,
Ptrace Leak, BakaSU/SUSFS/NoMount and AmneziaWG) separate from Kconfig fragments.
`scripts/package_anykernel.sh` emits the AnyKernel ZIP and a SHA256 sidecar only after
the configuration and CRC gates pass.
