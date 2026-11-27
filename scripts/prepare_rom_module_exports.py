#!/usr/bin/env python3
"""Allow only verified ROM rfkill exports under the custom kernel's fresh key.

Do not disable MODULE_SIG_PROTECT, alter CRCs, or relax protected kernel imports.
"""
import argparse
import pathlib


def prepare(source, exports):
    target = source / 'android/abi_gki_protected_exports_aarch64'
    names = {r.split()[1] for r in exports.read_text().splitlines()
             if r.strip() and not r.startswith('#') and r.split()[0] == 'rfkill.ko'}
    if not names or any(not n.startswith('rfkill_') for n in names):
        raise ValueError('expected independently verified rfkill exports only')
    text = target.read_text()
    protected = set(text.split())
    removed = names & protected
    # Preserve all other symbol rows byte-for-byte; idempotent for resumed runs.
    result = ''.join(line for line in text.splitlines(keepends=True) if line.strip() not in names)
    if set(result.split()) != protected - names:
        raise ValueError('unrelated protected symbols would change')
    target.write_text(result)
    print(f'ROM EXPORT POLICY: PASS (rfkill_protected_removed={len(removed)} remaining_protected={len(protected - names)} CONFIG_MODULE_SIG_PROTECT unchanged; CRCs unchanged)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--exports', type=pathlib.Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.exports)


if __name__ == '__main__':
    main()
