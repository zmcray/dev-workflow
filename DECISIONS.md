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

**Why:** The mid-2026 vendor convergence: agents subscribe to the queue (issue reaches night-eligible = dispatch event) via Routines, webhooks, or a GitHub Actions cron. Removes the human as nightly launch operator.
**Based on:** Cursor event-driven cloud agents (Aug 19, 2026); Codex event integrations; Claude Code Routines/Dispatch.

## D-008: Verification ladder with an independent, cross-model reviewer

**Why:** The gate must be independent of the producing agent. Cross-model independence (Codex reviews Claude's work and vice versa) is strictly stronger than cross-session independence: different models have different blind spots. Ladder: build/tests → self-check vs acceptance criteria + artboard (screenshot loop) → adversarial cross-model review → CI re-runs everything as the hard gate.
**Based on:** Augment dual-verifier CI pattern; Tenki review-gate; the three-harness setup (D-014).

## D-009: Auto-merge is earned per task class, starting with class:safe

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

**Why:** The factory needs a versioned, harness-readable home for strategy, decisions, and templates ("specs live in the repo" applies to the factory itself). `software-factory` is that home; `dev-workflow` will be deprecated once templates and docs migrate and every wired repo points here.
**Based on:** User decision (2026-09-02).

## D-018: Home-grown OS objectives + roadmap remain the strategy layer above Linear

**Why:** Linear tracks execution (issues, phases); the Supabase OS (`os.objectives`, `os.roadmap_items`) tracks objectives and weekly commitment. The factory registered as objective `os-two-shift-factory` under the `os` workstream so strategy sessions and weekly reviews surface it.
**Based on:** Existing McRay Group OS conventions (roadmap contract v1, 2026-07-21).
