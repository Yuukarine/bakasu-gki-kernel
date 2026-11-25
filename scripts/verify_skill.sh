#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
test -s .agents/skills/bakasu-gki-kernel/SKILL.md
test -L .codex/skills/bakasu-gki-kernel
test -L .claude/skills/bakasu-gki-kernel
test -s AGENTS.md
test -s .claudeignore
test -s .codexignore
bash -n scripts/ask_user_popup.sh
bash -n scripts/verify_skill.sh
./scripts/ask_user_popup.sh "popup smoke test" "fixture" | grep -Fx fixture >/dev/null
for p in out .tmp kernel_src toolchains; do grep -Fxq "$p/" .claudeignore; grep -Fxq "$p/" .codexignore; done
for p in '*.zip' '*.img' 'Image*'; do grep -Fxq "$p" .claudeignore; grep -Fxq "$p" .codexignore; done
printf 'skill verification: PASS\n'
