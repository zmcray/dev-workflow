# Hooks

Claude Code hooks, installed once per Mac into `~/.claude/settings.json`. Both run from this checkout (`~/Developer/dev-workflow`), so a `git pull` updates them everywhere.

| Hook | Event | What it does |
|---|---|---|
| `stop-fast-check.sh` | `Stop` | When an agent tries to end its turn, runs the repo's fast check from `config/fast-checks.json`. Exit 2 blocks the turn end and hands the failure back to the agent. |
| `pretooluse-date-last.sh` | `PreToolUse`, matcher `Write\|Edit\|MultiEdit` | Blocks a Write that creates a new date-first file, and a Write or Edit to a `*.pbxproj` in a repo whose root has `project.yml` (XcodeGen generates it: edit `project.yml` and regenerate). |

## The Stop hook

- No changed or untracked files: exit 0.
- Not in a git repo, no `origin`, origin's owner is not the table's `owner`, the repo is not in the table, or the payload is not a JSON object: exit 0, silently. It never blocks work in other folders.
- A table repo: runs its checks in order under one shared deadline (`budget_seconds`, 90). The first failure or a timeout prints the check and the tail of its output, and exits 2. A timeout kills the check's whole process group.
- Fails closed for a table repo: a malformed entry, a program that is not found, or a missing `cwd` exits 2 with the fix. A table that cannot be read or parsed, or has no `repos` or `owner`, blocks only in dev-workflow itself (where it gets fixed); every other repo exits 0.
- A timeout settles even when a detached process still holds the check's output pipe, and the hook always exits explicitly.
- Loop guard: when the payload has `stop_hook_active: true` it still runs and reports, but exits 0, so a broken check costs at most one extra turn.

## The table: `config/fast-checks.json`

Keyed by GitHub repo name, matched case-insensitively against the last path segment of `git remote get-url origin`, so worktrees match. The segment before it must equal the table's `owner` (case-insensitive, https or `git@` form), so someone else's clone of a same-named repo is left alone.

```json
{
  "owner": "zmcray",
  "budget_seconds": 90,
  "repos": {
    "motus": [
      { "run": ["node", "{dev_workflow}/scripts/guards/date-last-names.mjs", "--paths"], "files": "new" },
      { "run": ["swift", "test"], "cwd": "MotusKit", "when": ["MotusKit/"] }
    ]
  }
}
```

Each check:

- `run`: the argv. `{dev_workflow}` becomes this checkout's path; `node` becomes the Node running the hook.
- `cwd` (optional): a folder relative to the repo root. Default: the root.
- `when` (optional): run only if a changed file starts with one of these prefixes.
- `files`: `true` appends the changed files (tracked and untracked) under `cwd` as `./path` relative to `cwd`; `"new"` appends only new files (untracked, or staged as added or renamed); `false` or absent appends none.

Every repo runs the date-last guard first. It takes milliseconds.

## Install

```bash
bash ~/Developer/dev-workflow/scripts/setup-factory-machine.sh            # the whole machine setup, hooks included
node ~/Developer/dev-workflow/scripts/install-claude-hooks.mjs --dry-run   # just the hooks, report only
```

The merge is idempotent, leaves every other setting alone, and writes `settings.backup-<time>-<date>.json` next to the file before any change. `--settings <path>` points it at another file. After the machine-wide install, remove any per-repo `Stop` entry for this hook (telos has one in `.claude/settings.json`), or the check runs twice.

## Audit

```bash
bash ~/Developer/dev-workflow/scripts/hooks-audit.sh            # every repo in the table
bash ~/Developer/dev-workflow/scripts/hooks-audit.sh motus trim # just these
```

For each repo it adds a temp worktree at origin's default branch (no fetch, no install: the checkout's `node_modules` is symlinked in), then checks that an innocuous new file passes and a deliberate break blocks for that break. It always removes the worktree. One line per repo: `blocks red, passes green`, `FAILED: <what>` or `SKIPPED: <why>`. Exit 1 on any `FAILED`.

## Tests

`hooks/stop-fast-check.test.sh`, `scripts/guards/date-last-names.test.sh` (the PreToolUse hook) and `scripts/install-claude-hooks.test.sh` run in the `tests` job of `.github/workflows/ci.yml`.
