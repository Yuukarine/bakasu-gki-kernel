# PJF110_16.0.3.500(CN01): observed ROM WLAN requirements

**Coverage incomplete; this profile intentionally blocks production packaging.**
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

The build workflow also runs a coverage preflight against known test-01 exports
before fetching/building. 181 unresolved imports across supplied consumers remain
blocked. Full missing vendor providers/exports (for example qcom_ipc_logging,
qmi_helpers, ipam) and initial module-loader errors are still needed to prove a
Wi-Fi fix. A modules.dep path or another consumer's CRC cannot substitute for them.

Working log loads qca_cld3_qca6750 + icnss2, not kiwi + cnss2. Both kernel configs
have CFG80211=n and RFKILL=m. No blind Kconfig/UTS change is justified by these data.
