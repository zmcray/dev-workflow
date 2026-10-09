# State of Practice — Agent-Fleet Software Development (August 2026)

Four research passes run 2026-08-24 (three) and late Aug 2026 (cloud/VM zeitgeist). This is the evidence base for `DECISIONS.md` and `ARCHITECTURE.md`. Rendered version: [The Two-Shift Factory artifact](https://claude.ai/code/artifact/7c5ff443-e231-4af0-885d-a8f356c171fd).

**Freshness warning:** vendor features and pricing here move monthly. Treat claims as accurate to Aug 2026; re-verify before infrastructure spend.

---

## Pass 1 — Overnight / background agent fleets

### Tool landscape
- **Claude Code cloud sessions + Routines**: Anthropic-hosted sandboxes; Routines = saved agent configs on cron (≥1h), webhooks, or GitHub events. Used as "cron jobs replaced by agents."
- **Codex cloud tasks**: per-task sandboxes; subagents (explorer/worker roles, up to 6 concurrent). Consensus: cloud for independent reviewable work owning distinct modules; local for high-context supervised work. Also runs as an MCP server.
- **Cursor background agents**: eight-agent parallel window; editor-centric.
- **Devin**: biggest claim/reality gap in the category (vendor 67% PR merge rate vs ~15% in independent Answer.AI testing).
- **Jules** (free tier) and **Copilot coding agent** ($10/mo): the cheap on-ramps.
- **Terragon shut down**; **Conductor** (local Mac worktree orchestrator with file-claiming) is the surviving orchestration startup.

### Convergent patterns
1. **Worktree-per-agent isolation** universal; ceiling ~6–10 active worktrees ([AIDEN](https://aidenapp.org/parallel-agents-git-worktree), [Willison](https://simonw.substack.com/p/embracing-the-parallel-coding-agent)).
2. **Small scoped issues, one agent each**: ~28% of small well-defined agent PRs merge almost instantly; ambiguous ones stall ([O'Reilly](https://www.oreilly.com/radar/agentic-code-review/)).
3. **Spec-first with a dual verifier gate** — agent self-checks vs spec, CI re-runs the same check independently ([Augment](https://www.augmentcode.com/guides/ai-agent-pre-merge-verification)).
4. **Tiny diffs / stacked PRs** (Graphite; GitHub stacked-PRs preview, pitched "for the agent era").
5. **CI as the gate; auto-merge earned** per task type ([Tenki](https://tenki.cloud/blog/github-agentic-workflows-review-gate)).
6. **The merge queue is the new bottleneck**: high-AI teams merge ~2x more PRs but stall on queueing; agents re-queue failures (self-DoS); AI-co-authored PRs carry ~1.7x latent issues. Fixes: dynamic batching, pre-flight mergeability checks ([tianpan.co](https://tianpan.co/blog/2026-07-02-the-merge-queue-is-the-new-bottleneck)).
7. **Human review capacity is the real ceiling** — winning teams build review infra: first-pass review agents, risk triage, circuit breakers ([Codacy](https://blog.codacy.com/ai-breaking-code-review-how-engineering-teams-survive-pr-bottleneck)).
8. **Flaky tests are the top overnight failure mode** — agents burn CI budget on flakes ([paddo.dev](https://paddo.dev/blog/claude-code-auto-fix-pr-lifecycle/)).
9. **Overnight orchestrator runs are real but messy** — 59 PRs across 21 repos in one documented night; lessons: pre-check mergeability, rebase on conflict, companion audit docs ([Developers Digest](https://www.developersdigest.tech/blog/12-tools-in-one-night-with-claude-code)).
10. **Task-type routing**: cloud fleets for well-specced/low-stakes work; local interactive for high-context/taste-heavy.

## Pass 2 — Spec-driven dev + design-first tooling

### Spec-driven development
Field consolidated on **Specify → Plan → Tasks → Implement** with human gates at every boundary:
- **GitHub Spec Kit** (~93k stars, agent-agnostic reference implementation), **Amazon Kiro** (spec-first IDE, EARS-notation requirements, strongest traceability), **OpenSpec** (~52k stars, lightweight repo-resident, closest to our AGENTS.md style). Also Tessl (regulated), BMAD (multi-persona), Cursor Plan Mode.
- Best practices: constitution-first (AGENTS.md before feature specs), **EARS notation** for acceptance criteria, specs in the repo never a wiki, 1–3 pages/feature, explicit out-of-scope. Reported ~10x fewer regenerate-from-scratch cycles.
- Sources: [MarkTechPost SDD roundup](https://www.marktechpost.com/2026/05/08/9-best-ai-tools-for-spec-driven-development-in-2026-kiro-bmad-gsd-and-more-compare/), [Spec Kit vs Kiro](https://codemyspec.com/blog/spec-kit-vs-kiro).

### Design / mockup tools
- **Claude Design** (Apr 2026): multi-artboard canvas, chat + direct manipulation, imports design systems from repos and self-checks against them, syncs with Claude Code ([DataCamp](https://www.datacamp.com/blog/claude-design)).
- **Figma Make + Figma MCP + Code Connect**: prompt-to-prototype grounded in your libraries; MCP streams tokens/components into agent context; Code Connect maps Figma components to real code components ([Figma MCP docs](https://developers.figma.com/docs/figma-mcp-server/)).
- **v0** (mockup = production shadcn component), **Paper** (HTML/CSS canvas with an MCP server — agents edit the mockup live), **Magic Patterns**, **Polymet**, **Lovable**.
- **Screenshot-driven iteration**: Figma MCP (truth) + agent (interpreter) + Playwright MCP (validation) is the standard triad; DOM/a11y-tree access beats pixel-only loops.

### Meta-findings
1. The spec is the prompt. 2. Human gates at phase boundaries, not continuous supervision. 3. Mockups moving to agent-legible substrates — the approved mockup IS implementation input. 4. Design systems as ground truth (tools ingest tokens/components and self-check). 5. Agents that screenshot their own output converge dramatically faster. 6. The issue tracker is the agent dispatch layer ([Linear for Agents](https://linear.app/agents); Copilot Linear GA Jul 23, 2026).

## Pass 3 — Agent-driven iOS pipelines

- **Runtimes**: Claude Code + **XcodeBuildMCP** (~82 tools, Sentry-maintained, JSON errors by file:line — headless build-fix loops) is the workhorse; Apple's `xcrun mcpbridge` MCP adds DocumentationSearch/ExecuteSnippet/RenderPreview; Xcode 26.3 embeds the Claude Agent SDK natively ([xcodebuildmcp.com](https://www.xcodebuildmcp.com/), [practitioner's guide](https://blakecrosley.com/guides/ios-agent-development)).
- **The pbxproj problem is the central constraint**: agents corrupt the UUID-cross-referenced format. Solutions in adoption order: Xcode 16+ buildable folders; **Tuist/XcodeGen generated projects** (standard answer for parallel agents); SPM-first; merge drivers as backstop. #1 practitioner rule: a PreToolUse hook blocking agent pbxproj writes ([Tuist on conflicts](https://tuist.dev/blog/2025/03/21/git-conflicts)).
- **Simulator verification**: tap/type/screenshot/a11y-tree loops run hands-off in ~45s; XCUITest = deterministic regression layer; [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) = CI visual layer ([Zenn walkthrough](https://zenn.dev/shimo4228/articles/xcodebuildmcp-ios-verification?locale=en)).
- **CI costs**: GH macOS runners ~$0.062/min (~10x Linux); Xcode Cloud 25 free hrs/mo; Cirrus $150/mo flat unlimited; Depot from $20/mo; self-hosted Mac mini $20–35/mo amortized — best lever at volume ([Bitrise runner roundup](https://bitrise.io/blog/post/best-github-actions-runners-in-2026-and-hidden-pricing-traps-to-avoid)).
- **Distribution**: fastlane match + pilot on an ASC API key; **signing stays human-owned** ("agents cannot debug code signing beyond reading the error").
- **Overnight iOS runs work** with: headless worktrees, generated projects + the write-block hook, XcodeBuildMCP self-verification. Effectiveness scales with **agent-documentation quality, not project size** (8-production-app finding).

## Pass 4 — Cloud VM / sandbox parallelization (the late-Aug zeitgeist)

1. **The unit of parallelism moved from worktree to forked microVM snapshot.** Morph Infinibranch <250ms full-VM forks; **Cursor Builds default Aug 17** (fork live initialized machines, 3x faster starts, fleets survive bad commits); Blaxel 25ms resume. Differentiation shifted from cold-start to snapshot/fork semantics ([Morph](https://www.morphllm.com/comparisons/daytona-alternative)).
2. **Durable-execution orchestration is the hard part, not the sandbox.** Cursor: Temporal-based, 50M+ daily actions, >99% reliability; **40%+ of Cursor's own monorepo PRs come from cloud agents** ([Cursor lessons](https://cursor.com/blog/cloud-agent-lessons)).
3. **Anthropic cloud stack matured fast**: cloud sessions → Routines/Dispatch → Managed Agents (worker fleets scaled on queue depth, May 2026) → self-hosted sandbox environments beta (Aug 6) ([Managed Agents docs](https://platform.claude.com/docs/en/managed-agents/overview)).
4. **Event-driven cloud agents are the Aug 2026 meta**: agents subscribed to PRs/Slack/cron holding a goal (Cursor Aug 19; Codex GitLab Aug 19) ([explainx](https://www.explainx.ai/blog/cursor-event-driven-cloud-agents-isolated-vms-august-2026)).
5. **Best-of-N validated but verifier-bound**: 1−(1−p)ⁿ lift is real; practice is best-of-3-to-8 with an LLM/execution verifier; 100-way tournaments are demos ([verification-horizon arXiv](https://arxiv.org/pdf/2606.26300), [LLM-as-a-Verifier](https://wavect.io/blog/llm-as-a-verifier/)).
6. **Sandbox vendors commoditizing** (E2B mindshare, Daytona speed, Modal GPU+scale, Vercel/Cloudflare bundling); "swarms" as agent societies remain marketing — production reality is fan-out + verify + select.
7. **Solo-dev overnight fleets are DIY but tractable**: Linear/GitHub issues as queue → cron/webhook dispatcher → one cloud session per issue → merge-on-green → morning review ([amux](https://amux.io/guides/claude-code-headless/), [Claude Code GH Actions](https://code.claude.com/docs/en/github-actions)).

---

## What this repo took from each pass

| Finding | Factory decision |
|---|---|
| Review capacity is the ceiling | Two-shift model, gates at boundaries (D-001) |
| Spec-first + EARS + dual verifier | Build packet (D-002) |
| Agent-legible mockups | Design gate on canvas (D-003) |
| Tracker as dispatch layer | Linear labels + night queue (D-004) |
| Tiny diffs, scope partitioning | One agent/issue/env (D-005) |
| Forked microVMs, 40% Cursor stat | Cloud-default night substrate (D-006) |
| Event-driven meta | Dispatch = issue reaching night-eligible (D-007) |
| Independent gate; cross-model blind spots | Codex ↔ Claude/Cursor review (D-008) |
| Auto-merge as earned privilege | class:safe graduation (D-009) |
| Flakes + merge pileups kill nights | Quarantine, 3-cap, sequential merges (D-010) |
| pbxproj constraint + XcodeBuildMCP | iOS line design (D-011, D-012) |
| Best-of-N verifier-bound | class:hard, cap 3, cross-harness (D-013) |
| Orchestration startups consolidating | Platform primitives only (D-015) |
| Docs quality > model choice | Learn phase fixes templates (D-016) |
