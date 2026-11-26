#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d "$root/.tmp/image-release.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
printf 'fixture bytes\n' > "$tmp/Image"
cat > "$tmp/file" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux kernel ARM64 boot executable Image, little-endian, 4K pages'
EOF
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.118-android14-11-o-gac2e718ebee (builder)'
EOF
chmod +x "$tmp/file" "$tmp/strings"
PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.141+ (builder)'
EOF
if PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee >"$tmp/mismatch.out" 2>&1; then echo 'mismatched release unexpectedly passed' >&2; exit 1; fi
grep -Fq 'expected=6.1.118-android14-11-o-gac2e718ebee actual=6.1.141+' "$tmp/mismatch.out"
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.118-android14-11-o-gac2e718ebee-dirty (builder)'
EOF
if PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee >"$tmp/dirty.out" 2>&1; then echo 'dirty release unexpectedly passed' >&2; exit 1; fi
grep -Fq 'actual=6.1.118-android14-11-o-gac2e718ebee-dirty' "$tmp/dirty.out"
printf 'image release fixtures: PASS\n'
