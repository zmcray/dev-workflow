---
name: wizard
description: Generate an interactive bash wizard that walks a human through steps only they can perform. Use when provisioning infrastructure, setting up credentials or CI secrets, walking an unfamiliar third-party dashboard, or running a one-off migration or cutover. Don't invoke this for steps the agent can perform itself.
---

# Wizard

A **wizard** is a bash script that walks a human, step by step, through a manual procedure that's tedious to do by hand and tedious to re-explain to an AI every time. It opens each URL, says exactly what to click and copy, captures the values, writes them where they belong (`.env`, GitHub secrets), confirms at every stage, and shows how many stages are left. It might configure third-party services, run a one-off migration, or move the project from one state to another.

The delightful UX is already solved by [template.sh](template.sh): stage-by-stage progress, confirmation gates, cross-platform URL opening (including WSL), hidden secret entry, idempotent `.env` upserts, `gh secret`/`gh variable` writes, and a closing summary. **Your job is only to scope the procedure and author its stages.** The library above the `STAGES` marker is identical in every wizard; that consistency is the point: never hand-edit it.

A wizard is ephemeral by default: built for one run, saved to a scratch or `scripts/` path, deleted when the job's done. Commit it only when the user wants a repeatable setup path that should live in the repo.

## Only the steps that need hands

A wizard holds only what needs the person's own hands: a click on a page no tool reaches, a sign-in, a value only a vendor dashboard shows. Everything an agent can do or check with a tool it has (a CLI or API, SQL, a connector such as Linear, Supabase or the routines API) is the agent's, before or after the wizard, never a stage:

- **No confirm-a-fact prompts.** Never ask the person whether an issue is Done, a PR merged, a setting is on or a row exists. The agent reads it. A precondition the agent finds unmet stops the handoff before the wizard runs.
- **No queries to paste.** Never hand the person SQL, a curl or a command to run and read back. The agent runs reads itself.
- **No record-what-you-chose prompts.** The agent reads the result from the system afterwards.
- **Settings an API can set, the agent sets** (a routine's schedule or connectors, a repo setting, an env var through a CLI), with the person's yes in chat, instead of walking them through the screen.
- **Each stage is the click and where it happens.** The last stage says to come back to chat, where the agent verifies everything and reports.

If nothing is left after the cut, there is no wizard: do the work in chat. Example of the cut: a routine-setup wizard asked the person to confirm an issue was Done, paste SQL to check a stamp row, say which connectors were attached, and record which paste format they used. Every one of those was an agent read. What belonged in the wizard: create the routine on its page and paste the launcher.

## Process

### 1. Scope the procedure

Work out every manual step the human must take and every value that gets captured along the way. Read the repo first, don't ask cold:

- For setup: `.env`, `.env.example`, `.env.*`, `README`, `docker-compose*`, framework config, and `.github/workflows/*` (every `secrets.*` / `vars.*` reference is a value the wizard must produce).
- For a migration or transition: the current state, the target state, and the irreversible actions between them.

Then cut every step an agent can do or check (**Only the steps that need hands**, above) and move it to the agent's own pre-check or verify list. Show the user the ordered list of what is left and the values each produces, and confirm: they may add, drop, or reorder.

**Done when:** every stage is named in order, and for each captured value you know (a) where the human gets it, (b) where it's written (`.env`, a GitHub secret, both, or nowhere; some stages are pure actions), and (c) whether it's secret (hidden entry) or public.

### 2. Map each stage's journey

For each stage, write the precise path a human follows: which URL to open, what to do there, where a value is shown, which variable it fills: e.g. "Dashboard → Developers → API keys → Reveal test key → copy". Where you don't actually know the current UI or the exact command, say so and ask the user or check the docs: never invent steps that may not exist.

**Done when:** every stage traces to concrete instructions a stranger could follow.

### 3. Author the wizard

Copy `template.sh` to the target path. Replace the example stage with one `stage` per step, in dependency order. Use the library helpers: `stage`, `say`/`step`, `open_url`, `ask`/`ask_secret`, `write_env`, `set_secret`/`set_var`, `pause`/`confirm`. Set `TOTAL_STAGES` to the number of stages you wrote.

Hold the bar the template sets: open the URL before asking for its value, use `ask_secret` for anything secret, `write_env` every persisted value, `set_secret` only the values CI actually needs, and `confirm` before any irreversible action. Each `stage` clears the screen so only the current step is visible: keep a stage to one focused task so nothing the human needs scrolls away. Don't touch the library above the marker.

### 4. Verify and hand off

- `bash -n <script>`; run `shellcheck` if available.
- `chmod +x <script>`.
- Don't run it end-to-end yourself: it opens browsers and blocks on human input. Trace it statically instead: every value from step 1 is captured and lands where step 1 said, and every `set_secret` name exactly matches a `secrets.*` reference in CI.
- Tell the user how to run it. If it's a repeatable setup path, commit it and link it from the README so the next person runs the script instead of asking an AI.
- Write down the agent's verify list (each check and the tool that runs it) where the next agent finds it: the issue comment for a committed wizard, the chat otherwise. When the person comes back, run every check yourself and report pass or fail. Never ask them to check.
