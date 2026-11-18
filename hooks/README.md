# Hooks

Claude Code hooks, installed once per Mac into `~/.claude/settings.json`. Both run from this checkout (`~/Developer/dev-workflow`), so a `git pull` updates them everywhere.

| Hook | Event | What it does |
|---|---|---|
| `stop-fast-check.sh` | `Stop` | When an agent tries to end its turn, runs the repo's fast check from `config/fast-checks.json`. Exit 2 blocks the turn end and hands the failure back to the agent. |
| `pretooluse-date-last.sh` | `PreToolUse`, matcher `Write\|Edit\|MultiEdit` | Blocks a Write that creates a new date-first file, and a Write or Edit to a `*.pbxproj` in a repo whose root has `project.yml` (XcodeGen generates it: edit `project.yml` and regenerate). |

## The Stop hook

- Changed files = the branch's commits since its merge-base with origin's default branch (`origin/HEAD`, else `origin/main`, else `origin/master`), plus uncommitted and untracked files, deduplicated. Agents commit before they stop, so committed work counts. Deleted files are included, as uncommitted deletions always were. No origin ref resolves: uncommitted and untracked only, silently.
- More than 150 files on the branch: only the HEAD commit's files plus uncommitted and untracked are checked, with one stderr note (the note alone never blocks).
- No changed files (for example on the default branch, nothing unpushed, clean tree): exit 0.
- Not in a git repo, no `origin`, origin's owner is not the table's `owner`, the repo is not in the table, or the payload is not a JSON object: exit 0, silently. It never blocks work in other folders.
- A table repo: runs its checks in order under one shared deadline (`budget_seconds`, 90). The first failure or a timeout prints the check and the tail of its output, and exits 2. A timeout kills the check's whole process group.
- A timeout is not a failure. It blocks with a message that the check timed out (likely a cold build), that the work it did is cached, and that the next stop runs it again; and it writes `stop-fast-check.timeout` (the check's name) in the worktree's own git dir (`git rev-parse --git-dir`), so each worktree has its own.
- The next run with that marker deletes it first, then runs the checks for real even when `stop_hook_active` is true: a real failure blocks, a pass exits 0, and a second timeout exits 0 with a note that the check could not finish in two tries. If the marker cannot be written (a read-only git dir), a timeout behaves like any other block.
- Fails closed for a table repo: a malformed entry, a program that is not found, or a missing `cwd` exits 2 with the fix. A table that cannot be read or parsed, or has no `repos` or `owner`, blocks only in dev-workflow itself (where it gets fixed); every other repo exits 0.
- A timeout settles even when a detached process still holds the check's output pipe, and the hook always exits explicitly.
- Loop guard: without a marker, when the payload has `stop_hook_active: true` it still runs and reports, but exits 0.
- **Bound: at most two blocked stops in a row, ever.** Only a stop with `stop_hook_active: false` can write a marker; the retry it earns can block once more and never writes one, so the stop after that (still `stop_hook_active: true`, no marker) exits 0. `hooks/stop-fast-check.test.sh` drives timeout → real failure → `stop_hook_active` → exit 0.
- Hook timeout: the installer sets `timeout` on the Stop entry to the budget + 30 s (120 s). Per the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks), `timeout` is in seconds, a `command` hook's default is 600, and a hook killed at its timeout has its output discarded and renders no decision, so the stop goes through. `onFailure: "block"` has no effect on Stop hooks.

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
- `when` (optional): run only if a changed file (committed on the branch, uncommitted or untracked) starts with one of these prefixes.
- `files`: `true` appends the changed files under `cwd` as `./path` relative to `cwd`; `"new"` appends only new files (untracked, added or renamed on the branch or in the tree); `false` or absent appends none.

Every repo runs the date-last guard first. It takes milliseconds.

## Install

```bash
bash ~/Developer/dev-workflow/scripts/setup-factory-machine.sh            # the whole machine setup, hooks included
node ~/Developer/dev-workflow/scripts/install-claude-hooks.mjs --dry-run   # just the hooks, report only
```

The merge is idempotent, sets `timeout` (budget + 30 s) on the Stop entry and adds it to an existing entry that lacks it (a larger one set by hand is kept), leaves every other setting alone, and writes `settings.backup-<time>-<date>.json` next to the file before any change. `--settings <path>` points it at another file. After the machine-wide install, remove any per-repo `Stop` entry for this hook (telos has one in `.claude/settings.json`), or the check runs twice.

## Audit

```bash
bash ~/Developer/dev-workflow/scripts/hooks-audit.sh            # every repo in the table
bash ~/Developer/dev-workflow/scripts/hooks-audit.sh motus trim # just these
```

For each repo it adds a temp worktree at origin's default branch (no fetch, no install: the checkout's `node_modules` is symlinked in), then checks that an innocuous new file passes, a deliberate break blocks for that break, and the same break committed on a clean tree blocks too. For motus it also adds a second fresh worktree with no warm-up and a committed broken MotusKit test: the first stop must block (timeout or failure), and after a timeout the retry under `stop_hook_active: true` must block on the real failure; it prints which path it took and each run's seconds. It always removes the worktrees. One line per repo naming the cases proven, e.g. `motus: blocks uncommitted red, blocks committed red, blocks cold red (timeout then failure), passes green`, or `FAILED: <what>` or `SKIPPED: <why>`. Exit 1 on any `FAILED`.

## Tests

`hooks/stop-fast-check.test.sh`, `scripts/guards/date-last-names.test.sh` (the PreToolUse hook) and `scripts/install-claude-hooks.test.sh` run in the `tests` job of `.github/workflows/ci.yml`.
