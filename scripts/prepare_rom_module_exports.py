#!/usr/bin/env python3
"""Allow only verified ROM rfkill and TIPC exports under the custom kernel's fresh key.

Do not disable MODULE_SIG_PROTECT, alter CRCs, or relax protected kernel imports.
"""
import argparse
import pathlib


TIPC_EXPORTS = {
    'tipc_dump_done': '0xdc43d984',
    'tipc_dump_start': '0x60da1d20',
    'tipc_nl_sk_walk': '0xf6b650cc',
    'tipc_sk_fill_sock_diag': '0x2a0945d7',
}


def prepare(source, exports, check_only=False):
    target = source / 'android/abi_gki_protected_exports_aarch64'
    names = {r.split()[1] for r in exports.read_text().splitlines()
             if r.strip() and not r.startswith('#') and r.split()[0] == 'rfkill.ko'}
    if not names or any(not n.startswith('rfkill_') for n in names):
        raise ValueError('expected independently verified rfkill exports only')
    tipc = {r.split()[1]: r.split()[2] for r in exports.read_text().splitlines()
            if r.strip() and not r.startswith('#') and r.split()[0] == 'tipc.ko'}
    if tipc != TIPC_EXPORTS:
        raise ValueError('expected exactly four verified ROM TIPC exports with original CRCs')
    allowed = names | set(tipc)
    text = target.read_text()
    protected = set(text.split())
    removed = names & protected
    tipc_removed = set(tipc) & protected
    if check_only:
        blocked = allowed & protected
        if blocked:
            raise ValueError('ROM load policy FAIL: protected provider exports: ' + ','.join(sorted(blocked)))
        print(f'ROM LOAD POLICY: PASS (rfkill={len(names)} TIPC={len(tipc)} verified export allowlist; no blocked provider exports; signature protection unchanged)')
        return
    # Preserve all other symbol rows byte-for-byte; idempotent for resumed runs.
    result = ''.join(line for line in text.splitlines(keepends=True) if line.strip() not in allowed)
    if set(result.split()) != protected - allowed:
        raise ValueError('unrelated protected symbols would change')
    target.write_text(result)
    print(f'ROM EXPORT POLICY: PASS (rfkill_protected_removed={len(removed)} tipc_protected_removed={len(tipc_removed)} remaining_protected={len(protected - allowed)} CONFIG_MODULE_SIG_PROTECT unchanged; CRCs unchanged)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--exports', type=pathlib.Path, required=True)
    parser.add_argument('--check-only', action='store_true', help='Read-only gate: fail if required ROM provider exports remain blocked')
    args = parser.parse_args()
    prepare(args.source, args.exports, args.check_only)


if __name__ == '__main__':
    main()
