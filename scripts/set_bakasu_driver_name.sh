#!/usr/bin/env bash
# Safely override BakaSU's display string without touching its numeric version.
set -Eeuo pipefail

usage() { printf '%s\n' 'Usage: set_bakasu_driver_name.sh [--source-dir DIR] [--file KBUILD]'; }
source_dir=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}
target_file=${BAKASU_KBUILD_FILE:-}
while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0;;
    --source-dir) [[ $# -gt 1 ]] || { echo 'missing source directory' >&2; exit 2; }; source_dir=$2; shift 2;;
    --file) [[ $# -gt 1 ]] || { echo 'missing Kbuild file' >&2; exit 2; }; target_file=$2; shift 2;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done

name=${CUSTOM_DRIVER_NAME:-}
if [[ -z $name ]]; then
  printf '%s\n' 'custom_driver_name: empty, keeping BakaSU default'
  exit 0
fi

python3 - "$source_dir" "$target_file" <<'PY'
import os
import pathlib
import re
import sys
import tempfile
import unicodedata

source_dir = pathlib.Path(sys.argv[1])
explicit = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
name = os.environ.get("CUSTOM_DRIVER_NAME", "")

if len(name) > 64:
    raise SystemExit("custom_driver_name: FAIL: length exceeds 64 characters")
for char in name:
    category = unicodedata.category(char)
    if ord(char) < 32 or ord(char) == 127 or char in {'"', '\\', '`', '$'}:
        raise SystemExit("custom_driver_name: FAIL: control or syntax-breaking character")
    if char.isspace() or not (char.isalnum() or char in '-_.@' or category[0] in {'L', 'M', 'N', 'S'}):
        raise SystemExit(f"custom_driver_name: FAIL: unsupported character U+{ord(char):04X}")

pattern = re.compile(r'^(?P<indent>[ \t]*)KSU_VERSION_FULL[ \t]*:=.*$', re.MULTILINE)
if explicit:
    candidates = [explicit]
else:
    candidates = sorted(source_dir.rglob('Kbuild')) if source_dir.exists() else []
candidates = [path for path in candidates if path.is_file() and pattern.search(path.read_text(encoding='utf-8'))]
if len(candidates) != 1:
    raise SystemExit(f"custom_driver_name: FAIL: expected one BakaSU Kbuild, found {len(candidates)}")
target = candidates[0]
text = target.read_text(encoding='utf-8')
match = pattern.search(text)
if not match:
    raise SystemExit(f"custom_driver_name: FAIL: KSU_VERSION_FULL line not found in {target}")
replacement = f"{match.group('indent')}KSU_VERSION_FULL := {name}"
updated = text[:match.start()] + replacement + text[match.end():]
if updated == text:
    raise SystemExit("custom_driver_name: FAIL: no change made")
with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=target.parent, delete=False) as handle:
    handle.write(updated)
    temporary = pathlib.Path(handle.name)
temporary.chmod(target.stat().st_mode & 0o7777)
temporary.replace(target)
print(f"custom_driver_name: PASS: updated {target}")
PY
