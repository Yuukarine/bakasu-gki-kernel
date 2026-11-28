#!/usr/bin/env bash
# Pinned commits stay valid when a remote branch advances; missing pins fail.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d "$root/.tmp/patch-source-fixtures.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/source"
git init --quiet --initial-branch=main "$tmp/remote"
git -C "$tmp/remote" config user.name Fixture
git -C "$tmp/remote" config user.email fixture@invalid
printf 'pinned\n' > "$tmp/remote/source.txt"
git -C "$tmp/remote" add source.txt
git -C "$tmp/remote" commit --quiet -m pinned
pin=$(git -C "$tmp/remote" rev-parse HEAD)
printf 'advanced\n' >> "$tmp/remote/source.txt"
git -C "$tmp/remote" commit --quiet -am advanced
head=$(git -C "$tmp/remote" rev-parse HEAD)
printf 'bakasu\tupstream-tree\t%s\tmain\t-\t%s\n' "$tmp/remote" "$pin" > "$tmp/manifest"
run_gate() {
  KERNEL_SOURCE_DIR="$tmp/source" PATCH_MANIFEST="$tmp/manifest" PATCH_LOG="$tmp/result" PATCH_FEATURES=bakasu bash "$root/scripts/apply_patch_sources.sh"
}
run_gate
grep -Fq "sha=$pin " "$tmp/result"
# Unpinned refs still resolve to the real current branch HEAD.
printf 'bakasu\tupstream-tree\t%s\tmain\t-\n' "$tmp/remote" > "$tmp/manifest"
run_gate
grep -Fq "sha=$head " "$tmp/result"
printf 'bakasu\tupstream-tree\t%s\tmain\t-\t%s\n' "$tmp/remote" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > "$tmp/manifest"
if run_gate > "$tmp/error" 2>&1; then echo 'nonexistent pinned commit unexpectedly accepted' >&2; exit 1; fi
grep -Eq 'not our ref|couldn.t find remote ref|not a valid|unadvertised object' "$tmp/error"
printf 'patch source pin fixtures: PASS\n'
