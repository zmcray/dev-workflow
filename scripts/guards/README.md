# Guards

Shared ratchet checks for every repo. Each one fails only on what a pull request adds, and its error names the fix.

| Guard | Fails when a PR | Proof it catches real mistakes |
|---|---|---|
| `date-last-names.mjs` | adds or renames a file whose name starts with a date (migrations exempt) | fails on 18e8ae9 and 280a994 in this repo |
| `swift-swallowed-errors.mjs` | adds a `try?` or an empty or log-only `catch` to non-test Swift | flags motus 98c0fe4 and saidso e5b1d07, 880a8ca, each later fixed |

## Use it in a repo

Add a job to the repo's PR workflow and make the repo's gate job need it:

```yaml
  guards:
    uses: zmcray/dev-workflow/.github/workflows/guards.yml@main
    with:
      swift: true   # iOS repos only
      runs_on: '["self-hosted","macOS","imac"]'   # optional; default is "ubuntu-latest"
```

`runs_on` is JSON for the runner. It defaults to `"ubuntu-latest"` (note the quotes: it is a JSON string). Self-hosted repos pass a JSON array.

## Prove every repo calls it

`config/guards-repos.json` lists the repos that must call the guards, the gate job in each that must list the guards job in its `needs`, and whether the call must pass `swift: true`. The audit reads each repo's workflows on its default branch and prints one line per repo, `wired` or `MISSING: <what>`. It exits 1 if any repo is missing something. Anything it cannot parse counts as missing.

```bash
node ~/Developer/dev-workflow/scripts/guards-audit.mjs
```

`--dir <path>` reads `<path>/<repo>/.github/workflows/` from disk instead of GitHub (the test uses it).

## Run it locally

```bash
node ~/Developer/dev-workflow/scripts/guards/date-last-names.mjs --base origin/main
```

```bash
node ~/Developer/dev-workflow/scripts/guards/swift-swallowed-errors.mjs --base origin/main
```

To keep an intended `try?`, end the line with `// ratchet:allow R1 <why>`.
