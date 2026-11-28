# Ace3V test-05: restore the NICM TIPC prerequisite, not unrelated Kconfig

## Evidence and limits

Audited against repository HEAD `3d487a804d8621bfaafdbef3e1572ead64644a5e`.
The connected test-04 `/proc/version` matches the downloaded Image's actual
`6.1.118-android14-11-o-gac2e718ebee6`, Android Clang 17.0.2/r487747c,
`build-user@build-host`, timestamp `Fri Mar 27 03:01:48 UTC 2026`.
`uname` instead reports `g7c70fb1cc0b8`: `/data/adb/ksu/.susfs.json` explicitly
sets that release/version. Do not mistake this userspace spoof for the Image.
Live `/proc/config.gz` byte-equals the independently extracted test-04 IKCONFIG.

Read-only evidence: `nicmd`, both `qcrilNrd` processes and `imsdaemon` running;
NICM's UID is 1001. `rmnet_ipa0` is up but `rmnet_data0..2` are down, zero bytes.
`dumpsys telephony.registry` retained the literal failure:
`fail cause: OEM_DCFAILCAUSE_4(0x1004)`.
The remaining radio/logcat ring no longer contains the original DSI initialization
attempt; do not fabricate its timestamp or the original module-loader errno.
No device writes, service restarts, module insertion/removal, flashing or reboot
were performed. Static/offline PASS does not prove a successful on-device call.

## Most strongly supported cause: TIPC provider denied by export policy

1. Supplied working `lsmod.txt`: `tipc 376832 9 diag`, `diag 20480 0`.
   Live test-04 has neither; `/sys/module/tipc` and `/proc/net/tipc/socket` absent.
   Both kernels actually configure `CONFIG_TIPC=m`, media UDP and crypto enabled.
2. Actual `/vendor/lib64/libnicm_utils.so`, disassembled on the host:
   `Nicm::EventTIPCMessenger::openSocket` at **0x28ba8** sets `w0=30` (AF_TIPC),
   **0x28bb8** calls `socket`; negative result takes its error branch.
   `RequestTIPCMessenger` also uses AF_TIPC at **0x30004..0x30010**.
   Thus a running NICM process/Unix listener does not prove its TIPC transport works.
3. The real ROM `tipc.ko` exports exactly:

   | Export | CRC |
   |---|---|
   | tipc_dump_done | 0xdc43d984 |
   | tipc_dump_start | 0x60da1d20 |
   | tipc_nl_sk_walk | 0xf6b650cc |
   | tipc_sk_fill_sock_diag | 0x2a0945d7 |

   All four remain in the stock protected-export list after test-04's rfkill-only
   exception. In pinned `kernel/module/main.c:1281-1285`, an untrusted-signature
   module exporting one of these returns **-EACCES before init** regardless of
   correct CRCs. ROM modules use the ROM signing key, not the custom build key;
   live stock `gzvm` has taint `E`. Signature-force remains disabled as stock.
4. Re-read real ROM TIPC/diag/gzvm modules, hashes exactly match the already
   committed `provider-inputs.tsv`. All **333 imports** already match test-04;
   no missing export/CRC mismatch explains this policy denial.
5. Actual `/vendor/bin/system_dlkm_modprobe.sh` uses `*/modules.load`, **not**
   `uname -r`; gzvm is already loaded. Thus the release directory mismatch alone
   does not explain TIPC being absent. Do not rename the target or patch the loader.

Controlled replay of the exact pinned protected list with the same verified ROM
exports: test-04 policy leaves four TIPC exports blocked (exit1); test-05 policy
leaves zero blocked (exit0). The runtime chain is the strongest root-cause
hypothesis; a post-flash data/call trial is still needed to confirm full recovery.

## Three real reference repositories

| Item | huangdihd | Bouteillepleine | WildKernels | test-04 -> test-05 |
|---|---|---|---|---|
| Repo commit | 4cdf2311bc02 | b33a6ce4b0ed | 34eae4408799 | source pins unchanged |
| Ace3V common/modules | 65c3035422d8 / ce7f91fa81af | same | same | same |
| Android Clang/pahole | r487747c / 1.23 | same | same | already matching |
| Protected exports | deletes entire list, action.yml:912-920 | deletes entire list, action.yml:977-985 | deletes entire list, action.yml:902-910 | rfkill15 only -> rfkill15 + verified TIPC4; retain other330 |
| Priority UID filter | enabled | disabled (overlaps its mount feature) | enabled | unchanged; empty configured filter and radio UID1001 bypass app-range hook |
| SysV IPC/namespaces | Droidspaces + KABI patches | optional Droidspaces | Droidspaces + KABI patches | unchanged: no observed SysV syscall dependency in DSI/NICM libraries |
| BPF stream parser | enabled | explicitly disabled | enabled | n retained: prior actual build measured42 stock CRC drifts when enabled |
| SELinux integration | reference helper/patch variants | helper variants | helper variants | existing complete manual5/5 untouched |
| Module overlay/blacklist | additional intercept/overlays | similar optional features | similar features | not copied; many claimed blacklist names differ from actual loaded module names |
| AK3 | their GKI fork | fork | Wild fork | native pinned osm0sis core/scripts unchanged |

These are build-orchestration sources, not a complete immutable source manifest
of the supplied working binary. Its exact historical patchset cannot be recovered
from eight config/log files. Known reference workflow differences do not establish
that every optional feature was in that binary.

## Every observed Kconfig difference

See **test05-config-differences.tsv**: exact normalized assignments, including
ABSENT versus explicit n. No configuration assignment is changed by this fix.
Key requested checks:
- Existing netfilter restoration already matches working: NF_LOG_SYSLOG,
  NF_LOG_IPV6, XT_SET, TARGET_LOG, MATCH_RECENT, IP_SET_MAX=65534.
- Advanced TCP/default BBR, CAKE/PIE versus working default CUBIC remain different;
  both implement CUBIC. No evidence they prevent an AF_TIPC socket from opening.
- IP6_NF_NAT=y remains truthful. Reference IPv6_NAT_FIX alters embedded config
  display; copying the apparent n would not be a reliable runtime comparison.
- SYSVIPC/POSIX_MQUEUE/namespaces/DEVTMPFS/MACVLAN, QMP PHY, NTSYNC, BBG/LSM,
  SECURITY_DMESG_RESTRICT, logging and FRAME_WARN differences remain documented,
  not blindly enabled. No NICM/DSI dependency library imported semget/shmget/msgget.
- Both **working and test-04 have CONFIG_KPROBES=y**, not n. Project skill and
  verifier also protect y. The requested n conflicts with actual baseline; no
  silent claim of n or disabled ABI protection is made.
- Source evidence for SUSFS priority hooks checks caller UID>=10000; NICM/radio
  UID1001 is not in that class. No netlink/ioctl/binder/cred hook was modified.

## Narrow fix and regression gates

`scripts/prepare_rom_module_exports.py` keeps the existing rfkill exception and
additionally allows **only those four exact TIPC exports/CRCs**. Does not disable
MODULE_SIG_PROTECT, change signatures, alter imports/CRCs or clear the whole list.
The new read-only `--check-only` gate rejects remaining blocked required providers.
Workflow executes prepare + check before building. Remaining protected rows must
be byte-identical; replay verifies the expected330. RFKill removal remains15.

Extend cellular consumer profile from2309/43 to **2642 imports/46 consumers** with
actual ROM TIPC250, diag11, gzvm72 imports; preserve WLAN3081/16 and stock15615.
The preflight kernel evidence is independently recovered from the actual test-04
Image, never fabricated from required CRCs. Baseline and built Module.symvers are
still checked independently on the runner; static provider existence is explicitly
not proof that Android has loaded it.

Regression fixtures cover protected-provider failure, exact four allowlisted
exports, idempotency, retained unrelated rows, missing/wrong/extra TIPC evidence,
missing kernel symbol and changed CRC. All existing AK3/SELinux/toolchain gates
remain. Runtime validation of test-05 must separately confirm loaded TIPC, NICM
DSI completion, rmnet address assignment and a successful call.
