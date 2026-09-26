#!/usr/bin/env bash
#
# setup-factory-machine.sh
# Wires a Mac so /factory runs on Claude Code, Codex, and Cursor. Safe to re-run.
#
#   1. Checks the CLIs and gh auth.
#   2. Clones or fast-forwards ~/Developer/dev-workflow and ~/Developer/software-factory.
#   3. Runs deploy-skills.sh (factory, packets, caspian -> all three harnesses).
#   4. Claude Code: Compound Engineering + Linear plugins.
#   5. Codex: Compound Engineering plugin and Linear MCP.
#   6. Cursor: checks the CE + Linear plugins (installed from the Cursor app, not here).
#   Ends with a checklist of what still needs a person (sign-ins, unattended-mode settings).
#
# Non-destructive: installs and copies only. Never deletes, never overwrites a dirty repo.
#
# Usage:
#   bash setup-factory-machine.sh --dry-run   # report only, change nothing
#   bash setup-factory-machine.sh             # apply

set -uo pipefail

DEV="$HOME/Developer"
REPOS=( dev-workflow software-factory )
GH_OWNER="zmcray"
CE_REPO="EveryInc/compound-engineering-plugin"
CURSOR_PLUGINS="$HOME/.cursor/plugins/cache/cursor-public"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

TODO=()
ok()   { echo "  ok    $*"; }
fix()  { echo "  FIX   $*"; TODO+=("$*"); }
act()  { if [[ $DRY_RUN -eq 1 ]]; then echo "  would $*"; else echo "  doing $*"; fi; }
run()  { [[ $DRY_RUN -eq 1 ]] || "$@"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "== Tools"
for bin in git gh claude codex; do
  if have "$bin"; then ok "$bin"; else fix "Install $bin"; fi
done
[[ -d /Applications/Cursor.app ]] && ok "Cursor.app" || fix "Install Cursor (cursor.com)"
if have gh && gh auth status >/dev/null 2>&1; then ok "gh signed in"; else fix "Run: gh auth login"; fi

echo "== Repos"
mkdir -p "$DEV"
for r in "${REPOS[@]}"; do
  p="$DEV/$r"
  if [[ ! -d "$p/.git" ]]; then
    act "clone $GH_OWNER/$r"
    run gh repo clone "$GH_OWNER/$r" "$p" -- -q || fix "Clone $GH_OWNER/$r failed"
  elif [[ -n "$(git -C "$p" status --porcelain)" ]]; then
    fix "$r has local changes; commit or stash, then re-run (not pulled)"
  else
    act "pull $r"
    run git -C "$p" pull -q --ff-only || fix "$r pull failed (diverged?)"
  fi
done

echo "== Skills (factory, packets, caspian)"
if [[ -f "$DEV/dev-workflow/deploy-skills.sh" ]]; then
  mkdir -p "$HOME/.claude/commands"
  if [[ $DRY_RUN -eq 1 ]]; then bash "$DEV/dev-workflow/deploy-skills.sh" --dry-run
  else bash "$DEV/dev-workflow/deploy-skills.sh"; fi
else
  fix "dev-workflow missing; skills not deployed"
fi

echo "== Claude Code"
if have claude; then
  installed="$(claude plugin list 2>/dev/null)"
  if ! grep -q "compound-engineering" <<<"$installed"; then
    act "install Compound Engineering plugin"
    run claude plugin marketplace add "$CE_REPO" >/dev/null 2>&1
    run claude plugin install compound-engineering@compound-engineering-plugin || fix "Claude: install compound-engineering plugin"
  else ok "Compound Engineering plugin"; fi
  if ! grep -qi "linear" <<<"$installed"; then
    act "install Linear plugin"
    run claude plugin install linear@claude-plugins-official || fix "Claude: install linear plugin"
  else ok "Linear plugin"; fi
fi

echo "== Codex"
if have codex; then
  # Capture first: `cmd | grep -q` trips pipefail when grep exits early.
  cx_plugins="$(codex plugin list 2>/dev/null)"; cx_mcp="$(codex mcp list 2>/dev/null)"
  if ! grep -q "compound-engineering@" <<<"$cx_plugins"; then
    act "install Compound Engineering plugin"
    run codex plugin marketplace add "https://github.com/$CE_REPO.git" >/dev/null 2>&1
    run codex plugin add compound-engineering@compound-engineering-plugin || fix "Codex: install compound-engineering plugin"
  else ok "Compound Engineering plugin"; fi
  if ! grep -qi "linear" <<<"$cx_mcp"; then
    act "add Linear MCP"
    run codex mcp add linear --url https://mcp.linear.app/mcp || fix "Codex: add Linear MCP"
  else ok "Linear MCP"; fi
  [[ -f "$HOME/.codex/AGENTS.md" ]] && grep -q "COMPOUND CODEX TOOL MAP" "$HOME/.codex/AGENTS.md" \
    && ok "CE tool map in ~/.codex/AGENTS.md" \
    || fix "Codex: CE tool map missing from ~/.codex/AGENTS.md (open Codex once after the plugin installs)"
fi

echo "== Cursor"
[[ -f "$HOME/.cursor/skills/factory/SKILL.md" || $DRY_RUN -eq 1 ]] && ok "factory skill" || fix "Cursor: factory skill missing"
for p in compound-engineering linear; do
  [[ -d "$CURSOR_PLUGINS/$p" ]] && ok "$p plugin" || fix "Cursor: install the $p plugin from Cursor > Plugins"
done

echo
echo "== Always by hand (sign-ins and unattended settings are not scripted)"
echo "  - Claude Code: run /mcp once and sign in to Linear; use auto mode for the night."
echo "  - Codex: run 'codex mcp login linear' once; set unattended mode per the factory skill's"
echo "    'Running on each harness' table."
echo "  - Cursor: sign in to Linear in the plugin; turn auto-run on for each repo."
echo "  - Every repo you run the factory in: clone it under ~/Developer and open it once in each app to trust it."

if [[ ${#TODO[@]} -gt 0 ]]; then
  echo; echo "== Still to fix (${#TODO[@]})"
  printf '  - %s\n' "${TODO[@]}"
fi
echo; echo "done.$([[ $DRY_RUN -eq 1 ]] && echo ' Dry run only. Re-run without --dry-run to apply.')"
