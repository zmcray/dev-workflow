# Decision Log

Every load-bearing choice in the factory, with rationale and basis. Format: **Decision / Why / Based on**. Newest decisions append at the bottom. A reversed decision gets a strikethrough and a pointer to its replacement, never a silent delete.

All "Based on" citations trace to `docs/research/2026-08-state-of-practice.md` unless noted. Research date: August 2026. Re-validate anything infrastructure-priced or vendor-shaped before acting on it after ~Q1 2027.

---

## D-001: Two-shift operating model (day = judgment, night = throughput)

**Why:** Human review capacity, not agent throughput, is the industry-wide ceiling. Concentrating human attention at phase boundaries (spec, mockup, decomposition, morning triage) and letting agents run unattended between them is the pattern successful teams converged on. Continuous mid-implementation supervision is the documented anti-pattern.
**Based on:** Convergent findings across all research passes; O'Reilly agentic code review; Codacy PR-bottleneck analysis; Simon Willison's parallel-agent workflow writing.

## D-002: The build packet gates the night queue

**Why:** Carefully specified tasks need dramatically less review than open-ended ones (~28% of small well-defined agent PRs merge almost instantly; big ambiguous ones stall). The packet (spec + EARS acceptance criteria + artboard + file scope + out-of-scope) makes every night issue self-verifiable and scope-fenced.
**Based on:** Spec-driven-development convergence (GitHub Spec Kit, Amazon Kiro, OpenSpec all use Specify→Plan→Tasks→Implement with human gates); Augment pre-merge verification guide.

## D-003: Mockups on agent-legible substrates, approved before code

**Why:** An approved mockup in real HTML/CSS or real components (Claude Design, Figma Make code layer, v0) is implementation input, not a picture of one. Agents that screenshot their own output and diff against the approved artboard converge far faster than agents working from prose. Every hour of design approval removes review hours downstream.
**Based on:** Design-tooling research pass; Figma MCP + Code Connect pattern; the Figma/Claude/Playwright triad write-ups.

## D-004: Linear is the dispatch layer; the board is the audit trail

**Why:** The industry converged on the issue tracker as the agent dispatch surface (assign an issue to an agent like a teammate). We already run this way; the factory extends it with `night-eligible`, `lane:*`, and `class:*` labels. Every agent judgment call gets logged as an issue comment so a reviewer can follow a build without a terminal.
**Based on:** Linear for Agents; Copilot cloud-agent Linear GA (Jul 2026); existing McRay Group AGENTS.md conventions.

## D-005: One agent, one issue, one isolated environment, tiny diff

**Why:** Universal baseline for parallel agent work. Small single-purpose diffs merge fast and review fast; file-scope partitioning at decomposition time is the #1 prevention for overnight merge-conflict pileups.
**Based on:** Worktree-per-agent consensus; merge-queue bottleneck analysis (tianpan.co); the 59-PRs-in-one-night postmortem.

## D-006: Cloud VMs are the default night substrate; local worktrees are the fallback (and the iOS answer)

**Why:** The unit of parallelism shifted in 2026 from local git worktrees to forked cloud microVM snapshots (Morph Infinibranch <250ms forks; Cursor Builds default; Blaxel 25ms resume). Fork one warm environment N times instead of booting N. Strongest proof: 40%+ of Cursor's own monorepo PRs come from cloud agents. Exception: the sandbox wave is Linux-first, so the iOS lane stays on local macOS (or Mac CI).
**Based on:** Cloud/VM zeitgeist research pass (late Aug 2026); Cursor cloud-agent lessons post.

## D-007: Event-driven dispatch, not hand-launched batches

**Why:** The mid-2026 vendor convergence: agents subscribe to the queue (issue reaches night-eligible = dispatch event; that label is retired by D-029, and `spec-ready` with no `gate:human` or `ops` is the event now) via Routines, webhooks, or a GitHub Actions cron. Removes the human as nightly launch operator.
**Based on:** Cursor event-driven cloud agents (Aug 19, 2026); Codex event integrations; Claude Code Routines/Dispatch.

## D-008: Verification ladder with an independent, cross-model reviewer

**Why:** The gate must be independent of the producing agent. Cross-model independence (Codex reviews Claude's work and vice versa) is strictly stronger than cross-session independence: different models have different blind spots. Ladder: build/tests → self-check vs acceptance criteria + artboard (screenshot loop) → adversarial cross-model review → CI re-runs everything as the hard gate.
**Based on:** Augment dual-verifier CI pattern; Tenki review-gate; the three-harness setup (D-014).

## D-009: Auto-merge is earned per task class, starting with class:safe

**Superseded by D-027 (2026-10-09).**

**Why:** Trust is graduated, not granted. Draft-PR + morning review first; copy/config/contained fixes graduate to merge-on-green after a clean supervised week; features stay morning-reviewed until random spot-checks stop finding anything. A calibration miss demotes the class.
**Based on:** Auto-merge-as-earned-privilege consensus; Autonoma quality-gate writing; AI-co-authored PRs carry ~1.7x latent issues (merge-queue research).

## D-010: Flake quarantine + 3-attempt CI cap + strictly sequential merges

**Why:** The two documented overnight killers are flaky tests (agents burn all night pushing speculative fixes at flakes) and merge-queue pileups (agents aggressively re-queue = self-DoS). Pre-flight mergeability checks and rebase-before-PR are mandatory.
**Based on:** paddo.dev auto-fix lifecycle; tianpan.co merge-queue analysis; overnight-run postmortems.

## D-011: iOS line — generated projects, pbxproj write-block, XcodeBuildMCP, snapshot ladder

**Why:** Agents cannot reliably edit `.pbxproj` (UUID-cross-referenced format; small edits corrupt it) and parallel branches conflict on it constantly. Fix: Tuist/XcodeGen manifests as source of truth (`.xcodeproj` gitignored), SPM-first structure, and a PreToolUse hook blocking pbxproj writes outright. XcodeBuildMCP (Sentry-maintained, JSON errors by file:line) makes the headless build-test-simulator loop work. Verification: XCUITest for flows, swift-snapshot-testing in CI, simulator screenshot loops vs artboards. Signing stays human-owned; agents only trigger the fastlane lane.
**Based on:** iOS pipeline research pass; blakecrosley.com practitioner's guide; Tuist conflict analysis.

## D-012: iOS CI ladder — Xcode Cloud free tier → Cirrus/Depot → Mac mini

**Why:** GitHub-hosted macOS runners are ~10x Linux pricing; fine for a required smoke check, wrong for the heavy suite. Xcode Cloud's 25 free hrs/mo covers the start; Cirrus ($150/mo flat, unlimited) or Depot when outgrown; a self-hosted Mac mini ($700–1,200 amortizing to $20–35/mo) is the best cost lever at real volume.
**Based on:** iOS CI cost research (cicdcalculator, Bitrise 2026 runner roundup, self-hosted-minis writeups).

## D-013: Best-of-N reserved for class:hard, capped at 3, cross-harness

**Why:** Parallel attempts with a verifier are validated (1−(1−p)ⁿ lift) but verifier-bound: the 100-attempt tournaments are demos, not practice. One attempt each from Claude, Codex, and Cursor buys more diversity than N same-model attempts. The verifier ranks diffs against the packet's executable acceptance criteria; only the winner opens a PR.
**Based on:** Best-of-N / LLM-as-verifier research; cross-model diversity reasoning (D-008).

## D-014: Three harnesses with fixed lanes; AGENTS.md is the single contract

**Why:** Zack deliberately runs Claude Code, Codex, and Cursor to spread tokens and learning. Lanes match current strengths: Claude Code = judgment + iOS; Cursor = web cloud fleet (most industrialized cloud-agent infra); Codex = independent review + overflow. AGENTS.md keeps workflow rules in one place so the Learn phase compounds once, not three ways. Token-plan headroom is a legitimate dispatch-time routing input; it never enters the packet.
**Based on:** User decision (2026-08); harness-capability research; the cross-model review argument (D-008).

## D-015: Build on platform primitives, not orchestration wrappers

**Why:** The pure orchestration-startup layer is consolidating (Terragon shut down; Conductor survives as a local tool) while platform vendors absorbed the fleet layer (Claude cloud sessions/Routines/Managed Agents, Codex cloud tasks, Cursor cloud agents) and sandbox infra commoditized. Monthly audit: delete any homegrown orchestration a vendor primitive now covers.
**Based on:** Fleet-orchestration research pass; market-consolidation signals.

## D-016: Instruction quality is the compounding asset

**Why:** The strongest finding from teams running production agent fleets: effectiveness scales with the quality of the repo's agent documentation, not project size or model choice. Every failure traces upstream to a packet-template or AGENTS.md fix, not just a code fix. The factory's real asset is the accumulated instruction set.
**Based on:** iOS practitioner's guide (8 production apps); the Learn-phase convention already in McRay Group AGENTS.md.

## D-017: This repo replaces dev-workflow

**Superseded by D-026 (2026-10-09):** it went the other way.

**Why:** The factory needs a versioned, harness-readable home for strategy, decisions, and templates ("specs live in the repo" applies to the factory itself). `software-factory` is that home; `dev-workflow` will be deprecated once templates and docs migrate and every wired repo points here.
**Based on:** User decision (2026-09-02).

## D-018: Home-grown OS objectives + roadmap remain the strategy layer above Linear

**Why:** Linear tracks execution (issues, phases); the Supabase OS (`os.objectives`, `os.roadmap_items`) tracks objectives and weekly commitment. The factory registered as objective `os-two-shift-factory` under the `os` workstream so strategy sessions and weekly reviews surface it.
**Based on:** Existing McRay Group OS conventions (roadmap contract v1, 2026-07-21).

## D-019: Fork a small set of mattpocock/skills; do not subscribe to the plugin

**Why:** Four of Matt Pocock's skills fill the factory's thinnest spot, the day-shift front end: `grilling` (frontier-of-questions interview, recommended answer per question) gates the packet; `domain-modeling` keeps a `CONCEPTS.md` glossary and ADRs so every agent speaks the same terms (the direct lever on D-016); `code-review` splits Standards from Spec in parallel subagents and enforces the file-scope fence at review time; `wizard` scripts the steps only a human can do (secrets, dashboards, signing). Forked rather than installed as the read-only plugin because each is rewritten on day one to Linear, the build packet, and our labels, and because the Learn phase must be able to amend them. The other 33 skills duplicate Caspian, zmcray-plan, lfg, and CE. Upstream hash recorded in `skills/UPSTREAM.md`; back-port check folded into the monthly D-015 audit.
**Based on:** Review of https://www.aihero.dev/skills and the mattpocock/skills repo (2026-09-09); user decision (2026-09-09).

**Amended 2026-09-21:** the glossary file is `CONCEPTS.md`, not `CONTEXT.md` as first written. compound-engineering already maintains `CONCEPTS.md` in the Learn phase (live in telos, argus, motus, saidso); a second file would have split the vocabulary between a read path and a write path. The forked `domain-modeling` skill now writes to `CONCEPTS.md` in CE's format. Lesson for the Learn loop: before introducing a repo-level convention, grep the wired repos for an existing one.

## D-020: A daily hour replaces the Thursday factory day; tank first

**Why:** Bet → shape → design → commit → spec does not fit in one day alongside everything else. The line is unchanged; it is spread across the week as one calendar hour per day plus a 20–30 minute morning verify. Two hours a week are mapping days (ideas, shaping, design, council); the rest are spec days. Every hour opens with a tank check, and a low `spec-ready` queue turns any day into a spec day, because an empty tank wastes a whole night while a late idea costs nothing. Nights are expected to end early on queue-empty or budget stop; both are normal.
**Based on:** User decision (2026-09-21). Supersedes the "Factory day (Thursday)" rhythm in the original manual.

## D-021: Small parallel-safe chunks, with complexity on the chunk and the model chosen at dispatch

**Why:** Small single-purpose diffs are the proven unit (D-005): they review in minutes, fail cheaply, and let several agents work at once. Chunks declare file scope; disjoint scope with no dependency forms a wave that may build concurrently, while merges stay strictly sequential (D-010). Each chunk carries one `tier:*` label (mechanical / moderate / judgment) describing how hard it is to get right. Model names never enter an issue or packet, consistent with D-014 (routing stays out of the packet) and the canonical rule against hard-coding tier names; `DISPATCH.md` is the single tier-to-model map. A plan that is mostly mechanical and moderate also stretches a limited credit budget furthest. `/zmcray-plan` enforces the size bar, file scope, waves, and tier label as of 2026-09-21; tier-aware dispatch and parallel waves land with Phase 2.
**Based on:** User decision (2026-09-21); D-005, D-010, D-014; AGENTS.md Delegation and Effort sections.

## D-022: Compound Engineering is the engine; the house layer stays thin

**Why:** A 30-day usage audit (2026-09-21) showed `/ce-work` 65 runs, `/ce-code-review` 64, `/ce-plan` 61, `/lfg` 39, against `zmcray-plan` 1 and `zmcray-execute`, `-status`, `-checkpoint`, `-retro` at 0-2. CE won planning and building; the house layer survives only where CE has nothing: the council (`/caspian`), the night loop (`/goal`, `/zmcray-build`, `/zmcray-wrap`), and repo wiring (`/zmcray-kickoff`). CE skills are never forked or patched (plugin updates would overwrite them); house rules reach CE through the canonical AGENTS.md block, which every session loads. One new command, `/packets`, bridges a finished `/ce-plan` to Linear chunks, which is the piece CE lacks: CE parallelizes units inside one session and one PR, while the factory needs separate chunks that different agents can pick up. Five unused commands archived, not deleted. The chunk rules first written into `zmcray-plan` earlier the same day were in the wrong place and moved here.
**Based on:** Session-transcript usage counts, 2026-08-22 to 2026-09-21; user decision (2026-09-21). Open follow-up: one `STRATEGY.md` per full-line product (`/ce-strategy`), starting with telos, as the yardstick for the Bet stage.

**D-022 amended 2026-09-21 (same day):** the first cut kept `/goal`, `/zmcray-build`, and `/zmcray-wrap` because their run counts were high. That misread the evidence. `~/.claude/commands/goal.md` was a personal command with the same name as Claude Code's built-in `/goal`; personal commands take precedence, so every typed `/goal` silently ran the zmcray build loop, which is where the high counts came from. The owner's intent was the built-in. All three are now archived; the built-in `/goal` plus `/lfg` is the night loop, and the behaviors `/lfg` lacks (Linear pickup and sync, merge on green, session close, chunk sweep, pull order, budget stop) live in AGENTS.md > Autonomous runs. House layer: `/caspian`, `/packets`, and `/zmcray-kickoff` (kept only because `/caspian` calls it). Lesson: a usage count says a command ran, not that the user chose it.

## D-023: Caspian v3 ... lenses and a cross-model Red Team, not personas; an output contract the factory can consume

**Why:** Three research passes (2026-09-21: a cold design audit, a 30-session usage study, and a benchmark against CE, gstack, mattpocock, Ryan Singer's shaping skills, SVPG, and the multi-agent-debate literature) agreed on the diagnosis. Caspian's thinking held up; its output did not: 40% of issues it wrote were ever built, 0 of 6 PRDs carried the mandated Later Shelf / appetite / skeleton, and every issue left without acceptance criteria, so nothing was `spec-ready`. Six lock gates were answered "lock" without adjudication; a stored learning was recorded and then ignored three weeks later; the Linear back-write failed silently on the happy path. On mechanism, the literature is clear: identity-label personas on one model do not improve reasoning (Zheng et al. 2024) and can degrade it (Gupta et al. 2024); what works is heterogeneous models with structurally opposed stances (Heter-MAD 2025; Liang et al. 2024) and batched question rounds with a recommended answer (grilling; gstack decision briefs). v3 keeps the five reasoning lenses and the cross-model Red Team (the two parts that were already right), cuts six gates to two, treats learnings as overrides, argues sequence not scope, adds PACKET mode and a four-risk exit gate, verifies the Linear write, and loads ~2.5k words at start instead of 28k. Output now carries loop sentence, appetite, skeleton M1 with executable acceptance criteria and `tier:*`, sequence line, Later Shelf with kill dates, and a decision log, which is exactly what `/ce-plan` → `/packets` → `/goal` consume.
**Based on:** scratchpad reports `research-caspian-audit.md`, `research-caspian-usage.md`, `research-caspian-synthesis.md`; user decision (2026-09-21, "rebuild").

## D-024: `/factory` is the night line; a budget stops it, a ledger reports it

**Why:** Typing `/goal <objective>` per night made the human choose the work; the queue already knows. `/factory` takes no argument, drains everything `spec-ready` and ungated in the repo, and stops on the first of: queue empty, chunk cap, stop time (no new chunk after stop minus 45 min, never kill mid-PR), or a hard stop. Prior art converged on per-item budgets plus a ceiling, "don't start what you can't finish", two stop paths (graceful finishes and merges; hard parks the branch unmerged), and an incrementally written ledger so a crash still leaves a morning. Claude Code natively gives the keep-going loop, dollar and turn caps, and typed stop reasons; wall clock, chunk cap, and ledger are the skill's. Recommendations taken: interactive v1 in a terminal (headless Routine launch waits on the unattended-approval problem), ledger as `docs/factory/runs/<date>.json` in-repo (an `os.factory_runs` table when the migrations pipeline owner is found), budget config as a `factory` key in the existing `.linear-project.json` with defaults in DISPATCH.md. Not named `goal` (D-022).
**Based on:** `docs/research/2026-09-23-factory-run-shape.md`; user decision (2026-09-23, "I'll take your recos").

## D-025: Chunks land in group PRs; CI is tiered by default

**Why:** D-021's small chunks are the right unit of work and review, but at one PR per chunk they made CI the bottleneck. On Motus a 12-chunk feature cost about 8 runner-hours on one iMac, and each PR spent about 10 of its 19 minutes on UI tests unrelated to the change. The fix separates the review unit from the CI unit:
- A **landing group** of about 4 consecutive chunks on one epic chain shares a branch and a PR, with one commit per chunk.
- Group PRs rebase-merge, so one revert still undoes one chunk.
- Escalation-list and `gate:human` chunks still land alone.
- Every repo's CI is tiered: a path-mapped PR gate under about 10 minutes, one build reused by every test step, and full suites, archives and deploy jobs on the default branch as the backstop.
- Flaky tests are quarantined, not deleted, and a runner is added before coverage is cut.

This extends D-010: merges stay strictly sequential, now per group.
**Based on:** `docs/research/2026-09-26-ci-speed-vs-fidelity.md`; user decision (2026-09-26, "do the reco… all repos, now and in the future"). Canonical text: zmcray/dev-workflow#9.

## D-026: dev-workflow is the one source; software-factory is archived

**Why:** Two repos held the factory's rules and they disagreed on five points (the 2026-10-09 setup review). dev-workflow is what deploys: the core block, `rules/`, the commands, the skill sync and the launch agents all run from it, and every wired repo's AGENTS.md points at its paths. Moving the other way would have touched every app repo, both Macs and 26 Codex skill files, and would have put private rules in a public repo. software-factory's docs, templates and skills moved into `factory/` with their history (git subtree); its research and plans joined `docs/`. The repo is archived with a pointer README. Renaming dev-workflow to "factory", with a symlink at the old path, is a separate follow-up.
**Based on:** User decision (2026-10-09, "recos"); `docs/plans/factory-hardening-2026-10-09.md` Unit 3.

## D-027: Every class merges on green

**Why:** The core block has merged every PR on green since September (229 factory chunks), while D-009 still said auto-merge was earned per class. Drafting `flow:design` chunks was weighed and rejected: a draft does not stop the run, but every chunk chained behind it waits for the morning, and design chunks usually sit at the head of chains of 6 to 11 issues. The safety comes from CI instead: PR CI runs the real suites, and a red main is reverted rather than built on. Three things still wait for a person: a parked chunk (draft PR + `gate:human`), a migration chunk awaiting apply (green PR, not merged), and a failed chunk. A repo can still opt out with `"automerge": false` in `.linear-project.json`.
**Based on:** User decision (2026-10-09, "recos"); the 2026-10-09 pulse ledger (chains waiting behind one chunk).

## D-028: A stuck chunk fails and the run moves on

**Why:** The old block said stop the run; `/factory` said mark it failed. A chunk still red after its retry (one tier up) is marked `failed` with a Linear comment, its PR is closed or left as a draft, and the run skips chunks that depend on it or share its files. It never merged, so it cannot hurt anything else. Hard stops are kept for what can: an unmergeable PR, a red baseline at run start, and a red main that one revert does not fix (`rules/goal-runs.md`; `commands/factory.md` > Red main).
**Based on:** Settled in the rules text by the proof-before-merge and slim-core work (2026-10-09); recorded here.

## D-029: `night-eligible` is retired

**Why:** /packets told a human to apply it, but the factory never checked it, so it gated nothing. The night queue is `spec-ready` with no `gate:human` and no `ops`. A person enters the loop through `gate:human`, which the factory does honour. The label is removed from the docs and from Linear.
**Based on:** User decision (2026-10-09).

## D-030: Plan filenames put the date last

**Why:** The global rule is `docs/plans/<short-description>-YYYY-MM-DD.md`, but the Compound Engineering `ce-plan` skill wrote the date first. The fix is at the source: the house fork of `ce-plan` now writes date-last names, so the core block needs no override note. Plans already written with the date first keep their names.
**Based on:** User decision (2026-10-09).
