# Architecture

How the Two-Shift Factory works end to end. Read `README.md` first for the model; read `DECISIONS.md` for why each piece is shaped this way.

## The pipeline

```
DAY SHIFT (human in the loop)                    NIGHT SHIFT (unattended)
─────────────────────────────                    ────────────────────────
01 Think    product council → PRD                04 Execute  event-driven dispatch,
02 Design   mockup flows on agent-legible                    one agent / issue / VM,
            canvas; approve every state                      verification ladder,
03 Decompose atomic issues w/ build packets,                 draft PR or auto-merge
            file-scope partitioned              05 Review   morning triage brief
                                                06 Learn    failures fix the template
```

### 01 Think — the product council

Deep product thinking as a structured adversarial session (Caspian on Claude Code): opinionated perspectives argue the framing, the human makes the calls, output is a PRD in the repo under `docs/strategy/`. The PRD's most important section is **what we are deliberately not building** — it is the fence the kick-back rule enforces at night. AI drafts; the human owns product judgment.

### 02 Design — approve pixels before code

Highest-leverage stage: every hour here removes review hours downstream.

- Mockups live on an **agent-legible substrate** — real HTML/CSS or real components (Claude Design canvas; Figma Make + Figma MCP/Code Connect if the design system lives in Figma; v0 when the mockup should *be* the production component).
- Design the **flow**, not screens: one canvas per feature, artboards for every state (empty, loading, error, success).
- Human sign-off on the canvas is a phase gate. The approved artboard link goes in the build packet; night agents screenshot their output and diff against it.
- iOS: no Figma-quality bridge for SwiftUI exists. Approve flows in HTML mockups, then agents build SwiftUI and verify via Xcode RenderPreview / simulator screenshots.

### 03 Decompose — the tracker is the dispatch layer

PRD + approved canvas → atomic, dependency-linked Linear issues, each carrying a **build packet** (`templates/build-packet.md`):

- **Packets come out of a grilling session** (`skills/grilling` + `skills/domain-modeling`): the agent interviews the human a round at a time, recommended answer attached to each question, until no branch of the design is silently assumed. Terms crystallise into `CONCEPTS.md`; hard-to-reverse choices become ADRs.
- Atomic and independently shippable; diffs reviewable in minutes.
- **File scope declared and partitioned**: two issues touching the same files get a dependency edge and run sequentially. Scope overlap is the #1 cause of overnight merge pileups.
- **Acceptance criteria are executable**: each maps to a test or screenshot check the agent runs itself and CI re-runs.
- `night-eligible` label applied by a human once the packet is complete. Never by the building agent.

### 04 Execute — the night shift

**Dispatch (event-driven, cloud-default):** an issue reaching `night-eligible` is the dispatch event. Web: one cloud session per issue (Claude Routines / webhook / GH Actions cron → headless session; or a Cursor cloud agent subscribed to the label). iOS: headless Claude Code in local git worktrees on a Mac (sandbox wave is Linux-first; simulators want real macOS). Practical local ceiling: ~6–10 concurrent worktrees — hitting it means PRs aren't merging fast enough, which is the real problem.

**Verification ladder (every PR, before any human sees it):**
1. Build + unit/integration tests green.
2. Agent self-checks the diff against acceptance criteria and the approved artboard (Playwright screenshot loop on web; simulator screenshots + accessibility tree on iOS), then runs `skills/code-review`: Standards and Spec axes as parallel subagents, the Spec axis reading the packet and flagging any file-scope fence violation as a hard finding.
3. **Independent cross-model review** (Codex reviews Claude/Cursor output and vice versa), prompted adversarially. Findings fixed or filed as residual Linear issues.
4. CI re-runs the full gate independently. Green + clean review → auto-merge for graduated classes; everything else waits as a draft PR.

**Guardrails:** pre-flight mergeability check + rebase before opening a PR; strictly sequential merges per repo; flake quarantine list; hard cap of 3 CI-fix attempts, then leave the draft + a Linear comment; never touch files outside declared scope (the kick-back rule's overnight form).

**Best-of-N (class:hard only):** one attempt per harness (Claude, Codex, Cursor) in forked environments; a verifier agent ranks diffs against the acceptance criteria; only the winner opens a PR; losers' insights become one summary comment. Cap at 3.

### 05 Morning review — triage, not code-reading

A routine assembles the brief before wake: merged PRs (one-liners), draft PRs ranked by risk (auth/data/payments first), CI failures with the failing line pre-extracted, residuals filed overnight. The human makes merge calls on drafts, spot-checks one merged PR at random for calibration, and traces every failure upstream: ambiguous spec? oversized issue? scope overlap? Target: under 30 minutes.

### 06 Learn — the compounding loop

Every failure fixes the **template**, not just the code: packet-template and AGENTS.md amendments, appended as what-worked / what-the-plan-missed notes. Instruction quality is the proven lever (D-016). Weekly: dispatch-routing review vs token-plan headroom. Monthly: platform-primitive audit — delete homegrown orchestration a vendor now covers (D-015).

## Labels (Linear, Mcraygroup workspace)

| Label | Meaning |
|---|---|
| `night-eligible` | Packet complete; may be dispatched unattended. Human-applied only. |
| `lane:claude` / `lane:cursor` / `lane:codex` | Dispatch-time harness routing. Never in the packet. |
| `class:safe` | Copy/config/contained fix. Auto-merges on green + clean review once graduated (Phase 3). |
| `class:feature` | Draft PR for morning review. Never auto-merges. |
| `class:hard` | Best-of-3 cross-harness tournament with verifier. |

These compose with the existing `flow:*` (rigor) and `prd-source` (strategy provenance) labels — flow governs day-shift phases; class governs night-shift merge trust.

## The iOS line (special tooling)

1. **pbxproj is agent-forbidden.** Tuist or XcodeGen manifests are source of truth (`.xcodeproj` gitignored); minimum viable is Xcode 16+ buildable folders. A PreToolUse hook blocks any agent write to `*.pbxproj` regardless.
2. **SPM-first**: feature code in local packages (`Package.swift` is plain Swift, agent-safe); thin app shell owns the project file.
3. **XcodeBuildMCP** (Sentry-maintained) + Apple `xcrun mcpbridge` (docs search, ExecuteSnippet, RenderPreview) is the headless build/test/simulator loop.
4. **Verification ladder, iOS edition:** `build_sim`/`test_sim` → XCUITest for critical flows → `swift-snapshot-testing` in CI → simulator screenshot loop vs approved artboards.
5. **CI ladder:** Xcode Cloud free tier (25 hrs/mo) for the smoke check → Cirrus ($150/mo flat) or Depot when outgrown → self-hosted Mac mini at volume. GitHub macOS runners are ~10x Linux price; smoke checks only.
6. **Distribution:** fastlane `match` + `pilot` on an App Store Connect API key. Signing set up by a human once; agents only trigger the lane.

## Rollout state

| Piece | Status (2026-09-02) |
|---|---|
| Build-packet contract | Piloted in argus AGENTS.md (PR #44); grilling gate + durability rules added 2026-09-09 |
| Forked skills (grilling, domain-modeling, code-review, wizard) | In `skills/`; deployed to `~/.claude/skills` and `~/.codex/skills` (2026-09-09); glossary standardized on `CONCEPTS.md` (2026-09-21); not yet exercised on a real packet |
| Linear labels | Live (workspace-wide) |
| Event-driven dispatcher | Not built (Phase 2, MCR-1412) |
| Verification ladder + cross-model review | Not built (Phase 2) |
| Morning brief routine | Not built (Phase 2) |
| Auto-merge graduation | Not started (Phase 3, MCR-1413) |
| iOS conversion (Tuist/hook/MCP/snapshots) | Not started (Phase 4, MCR-1414) |
| Best-of-N lane | Not started (Phase 5, MCR-1415) |

Update this table as phases land.
