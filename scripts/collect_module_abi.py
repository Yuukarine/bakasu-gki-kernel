#!/usr/bin/env python3
"""Snapshot real host-kmod module CRC evidence; never infer provider CRCs."""
import argparse
import hashlib
import pathlib
import subprocess


def kmod(option, module, allow_empty=False):
    result = subprocess.run(['modprobe', option, str(module)], capture_output=True, text=True, check=False)
    if result.returncode and not (allow_empty and 'No data available' in result.stderr):
        raise RuntimeError(f'{module}: {result.stderr.strip()}')
    rows = {}
    for line in result.stdout.replace('\\t', '\t').splitlines():
        crc, symbol = line.split()
        if symbol in rows:
            raise ValueError(f'duplicate symbol {symbol}: {module}')
        rows[symbol] = f'0x{int(crc, 16):08x}'
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ko-dir', type=pathlib.Path, required=True)
    parser.add_argument('--kernel', type=pathlib.Path, required=True, help='Independently verified kernel Module.symvers')
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    modules = sorted(args.ko_dir.glob('*.ko'))
    if not modules:
        raise ValueError('no modules')
    kernel = {line.split()[1] for line in args.kernel.read_text().splitlines() if line.strip() and not line.startswith('#') and line.split()[2] == 'vmlinux'}
    exports = {p.name: kmod('--show-exports', p, allow_empty=True) for p in modules}
    providers = {}
    for name, symbols in exports.items():
        for symbol in symbols:
            if symbol in providers or symbol in kernel:
                raise ValueError(f'ambiguous provider: {symbol}')
            providers[symbol] = name
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'modules.txt').write_text(''.join(f'{p.name}\n' for p in modules))
    (args.output/'exports.tsv').write_text('# provider symbol crc (actual module export table)\n' + ''.join(f'{name}\t{s}\t{c}\n' for name, symbols in exports.items() for s, c in sorted(symbols.items())))
    rows = []; info = []; unresolved = 0
    for module in modules:
        for symbol, crc in sorted(kmod('--dump-modversions', module).items()):
            provider = providers.get(symbol, 'vmlinux' if symbol in kernel else 'unresolved')
            unresolved += provider == 'unresolved'
            rows.append(f'{module.name}\t{symbol}\t{crc}\t{provider}\n')
        vermagic = subprocess.check_output(['modinfo', '-F', 'vermagic', str(module)], text=True).strip()
        info.append(f'{module.name}\t{hashlib.sha256(module.read_bytes()).hexdigest()}\t{vermagic}\n')
    (args.output/'imports.tsv').write_text('# consumer symbol crc provider (unresolved is a hard blocker)\n' + ''.join(rows))
    (args.output/'modules-provenance.tsv').write_text('# module sha256 vermagic\n' + ''.join(info))
    print(f'modules={len(modules)} imports={len(rows)} unresolved_imports={unresolved}')


if __name__ == '__main__':
    main()
