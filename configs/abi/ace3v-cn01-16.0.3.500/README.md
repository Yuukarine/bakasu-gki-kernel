# PJF110_16.0.3.500(CN01): observed ROM WLAN requirements

**Provider coverage complete for the original 16 WLAN-related consumers (3,081 imports).**
This is offline export/CRC evidence, not a device-runtime Wi-Fi test.
16 supplied ELF modules yield 3,081 versioned imports. Imports are requirements,
not export evidence. `unresolved` means the provider export table was NOT supplied;
never replace it with vmlinux or a guessed CRC merely to make the gate green.

- `imports.tsv`: consumer, symbol, required CRC, independently observed provider.
- `exports.tsv`: actual `modprobe --show-exports` from each supplied ELF module.
- `modules.txt`: actual supplied inventory, not every path listed by modules.dep.
- `modules-provenance.tsv`: ELF SHA256 and original complete vermagic.
- `*modules.dep`: ROM metadata, not proof that a module is loaded or CRC-compatible.
- `test01-kernel-imports.symvers`: 730 referenced vmlinux exports recovered from
  **test-01 Image** (SHA256 a5c759017eccf47eb7eae651161d95fb75f7d26f540f91003b7b30338a5a6344).
  This is an audit/coverage input only, NEVER a new-build stock baseline.

Extraction: `scripts/collect_module_abi.py --ko-dir DIR --kernel VERIFIED_SYMVERS
--output DIR`. Host kmod parses ELF `__versions`, `.modinfo`, and export CRC tables;
no ARM binary, module loading, force-load, or device communication is used.

Production gate: `scripts/verify_wifi_abi.sh --kernel Module.symvers`. It requires
all required kernel imports, supplied-module providers and CRCs independently of the
unpatched stock CRC gate. Added imports must get actual provider/export evidence.
Update inventory + exports + imports together only after checking the new ELFs.

The build workflow runs a coverage preflight against known test-01 exports before
fetching/building and repeats the check on the actual built Module.symvers.
489 dlkm modules originally supplied4,403 exports, resolving133/181 missing rows.
The ROM vendor_boot image (VNDRBOOT v4;4KiB pages;one LZ4 ramdisk) supplies480
modules:337 identical overlaps and143 new providers with1,039 new exports.
The combined inventory is632 modules /5,442 exports. All48 remaining import rows
(25 symbols) resolve uniquely with their independently extracted export CRCs.
Preflight now exits0: missing_provider=0 missing_symbol=0 changed_crc=0.
All original3,081 consumer/symbol/required-CRC tuples remain unchanged.

- `provider-inputs.tsv`: source relative path + SHA256 for each supplied ELF;
  vendor_boot paths refer to the extracted cpio, not a filesystem mount.
- `resolved-provider-imports.tsv`: all181 previously unresolved rows, actual provider CRCs.
- `unverified-imports.tsv`: no unresolved rows.
- `vendor-boot-inputs.tsv`: source-image SHA256,ramdisk index,exact cpio path and ELF SHA256.
- `vendor-boot-resolved-imports.tsv`:48 newly resolved consumer/symbol/CRC/provider rows.

Source image SHA256:1610159958b47833d9fbf79b92d21cba9239a604bd08eecd09d54ca0120a8929.
Host extraction bounds-checks VNDRBOOT v4 offsets/table, decompresses LZ4 and parses
newc cpio without executing ARM binaries or following archive symlinks. Import
CRCs were never substituted for export evidence. The stock baseline CRC check
remains independent. Provider transitive imports outside the original16 consumers
are not claimed as exhaustively checked by this profile.

Working log loads qca_cld3_qca6750 + icnss2, not kiwi + cnss2. Both kernel configs
have CFG80211=n and RFKILL=m. No blind Kconfig/UTS change is justified by these data.

## test-04: independent cellular coverage

`radio-imports.tsv` adds 2,309 actual ELF `__versions` requirements from 43
ipam/rmnet/qmi/qrtr/OPlus networking modules, without replacing the 3,081 WLAN
requirements. `radio-inputs.tsv` records each supplied ELF's SHA256, full vermagic
and local evidence path. Providers are resolved only against the existing actual
632-module inventory/export tables or recovered test-03 Image exports; there
were no ambiguous or unresolved assignments. `radio-kernel-evidence.symvers`
is a recovered **test-03 Image** subset for preflight coverage ONLY, not a stock
baseline and never a replacement for the post-build gate on Module.symvers.

`scripts/verify_radio_abi.sh --kernel Module.symvers` runs the same strict Rust
gate. test-03 already passes all 2,309 cellular imports (0 missing/changed CRC).
Thus these data do not establish a cellular symbol/CRC defect in test-03, and
CRC equality does not prove radio userspace handshakes or all struct layouts.
The new build runs WLAN and cellular gates independently before packaging.
