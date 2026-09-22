# Archived commands

Retired 2026-09-21 after a 30-day usage audit: each ran 0-2 times while Compound Engineering's `/ce-plan`, `/ce-work`, `/lfg`, and `/ce-code-review` ran 40-65 times each. Nothing here is deployed. Restore one by moving it back to `commands/` and copying it to `~/.claude/commands/`.

| Command | Replaced by |
|---|---|
| zmcray-plan | `/ce-plan` then `/packets` |
| zmcray-execute | `/goal` |
| zmcray-status | the Linear board; `/landing-report` |
| zmcray-checkpoint | `/context-save`, `/context-restore` |
| zmcray-retro | `/ce-compound`, `/retro` |
| zmcray-build | `/lfg` per issue; merge-on-green, Linear sync, and session close come from the AGENTS.md rules |
| zmcray-wrap | the AGENTS.md Session close rule + `/ce-compound` |
| goal (custom) | Claude Code's **built-in** `/goal`. This file had the same name and, as a personal command, took precedence over the built-in... so typing `/goal` silently ran the zmcray build loop. Archived 2026-09-21 so the built-in takes over; its useful rules (chunk sweep, pull order, budget stop) moved into AGENTS.md > Autonomous runs. |
| caspian (v2 wrapper) | `commands/caspian.md` v3 (2026-09-21 rebuild): five lenses + cross-model Red Team instead of five named personas, two gates, batched questions with recommended answers, output contract with executable acceptance criteria and Later Shelf, PACKET mode, load-by-phase. The v2 brain (28k words) stays untouched in `~/Documents/Work/40_OS/05_Skills/caspian/` for reference; v3 reads only its learnings store. |
