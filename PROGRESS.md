# BakaSU GKI 2.0 / OGKI Agent Skill — Progress

- [x] Plan recorded in this file before implementation; `$PROJECT_ROOT` bound to `/home/yuukari_ne/My-Project/custom-phone/kernel-build`.
- [x] Blocking popup created first at `scripts/ask_user_popup.sh`, executable, syntax-checked, and smoke-tested.
- [x] Bootstrap completed in-jail: `npx --yes autoskills -y` exit 0 (installed `bash-defensive-patterns` and wrote `skills-lock.json`); `npx --yes skills find` exit 0. The registry package named `find-skills` returned npm 404 and is recorded in `.tmp/bootstrap/find-skills.log`.
- [x] Compact skill written with frontmatter, BakaSU-only two-branch architecture, Golden Stack, forbidden changes, workflow integrations, and verification gates.
- [x] Root `AGENTS.md`, `.claudeignore`, `.codexignore`, and CLI symlinks under `.codex/skills/` and `.claude/skills/` created.
- [x] Verification helper and transaction roles created; all checks, reference audit, diff reconstruction, and rollback evidence pass.

## Evidence ledger

- Popup syntax: `bash -n scripts/ask_user_popup.sh` → exit 0.
- Popup smoke: `./scripts/ask_user_popup.sh "popup smoke test" "fixture"` → `fixture`, exit 0.
- Skill/config verification: `./scripts/verify_skill.sh` → `skill verification: PASS`, exit 0.
- Skill size: `wc -c .agents/skills/bakasu-gki-kernel/SKILL.md` → `4686` bytes.
- Transaction target: `scripts/ask_user_popup.sh`; changed field is the `default_value` fallback branch accepting `BAKASU_POPUP_DEFAULT`.
- Baseline: explicit `fixture` input → stdout `fixture`, stderr empty, exit 0; SHA256 `b5caea4f74056880a976ec3762009cf0c980f9569e271ff5a24c349aa602ba51`.
- Modified: same input → stdout `fixture`, stderr empty, exit 0; environment fallback → `env-fixture`, exit 0.
- Rollback: `artifacts/ROLLBACK.sh artifacts/transaction/rollback-copy` then same input → `fixture`, exit 0; restored SHA equals baseline.
- Content/reference audit and diff reconstruction → `PASS` (all required symbols, links, and paths resolve).
- Four reopened role paths: `artifacts/MODIFIED_FILE`, `artifacts/DIFF_FILE`, `artifacts/VERIFICATION.txt`, executable `artifacts/ROLLBACK.sh`.
