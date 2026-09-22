# Caspian 10x: synthesis of three research passes (2026-09-21)

Inputs: `research-caspian-audit.md` (cold read of the 28k-word skill), `research-caspian-usage.md` (30 sessions, 6 PRDs, git traces), and a benchmark pass (CE ce-doc-review / ce-strategy / ce-brainstorm, gstack office-hours / plan-ceo-review / spec / autoplan, mattpocock grilling / to-spec / wayfinder, Ryan Singer's own shaping skills, SVPG, and the multi-agent-debate + persona literature).

## The diagnosis in one line

Caspian's thinking is good and its output is not consumed: 40% of the issues it writes get built, 0 of 6 PRDs contain the Later Shelf / appetite / skeleton the wrapper mandates, and every issue leaves without acceptance criteria, so nothing it produces is `spec-ready` for the factory it feeds.

## What the evidence says

**Usage (30 runs, median 8 turns, ~1.5 h).** It finishes (27/30). Drift detection and the compound-learnings loop are real. But: six lock gates get answered "lock / lcok / keep it all"; the validation interrogation was cut off by the user, a learning was recorded, and the skill re-ran the same probes three weeks later; one gate fired on an artifact that was never rendered; the D5 back-write to the PRD fails silently on the happy path.

**Design (28k words, ~45k tokens cold start).** 6-8k words are duplication; ~1.5k words reference retired tooling (`/zmcray:build`, Cowork GraphQL, `mvp:m*` labels) and now contradict AGENTS.md. Five named personas run one-per-phase and never in tension; the five lenses are the real mechanism and have zero enforcement. The Red Team pass IS structurally independent (fresh context, cross-model via Codex) and is the strongest part of the design.

**Literature on councils and personas.** Identity-label personas on the same model do not improve reasoning (Zheng et al. 2024, 162 personas, no gain; Gupta et al. 2024, demographic personas cut accuracy up to 33%). What does work: (a) heterogeneous *models* (Heter-MAD, 2502.08788; Du et al. ChatGPT+Bard), (b) structurally enforced opposing stances (Liang et al. MAD), (c) role-play as a reasoning scaffold, not a name. Same-model debate often flips correct answers to wrong (Ziems et al. 2025). Both Anthropic and OpenAI guidance: one strong agent with good tools first; fan out only for breadth-first, independent work; expect ~15x tokens.

**Comparable skills.** Every strong peer uses batched question rounds with a recommended answer attached (grilling's frontier rounds; gstack's D-briefs with `Recommendation:` and completeness scores; spec's 3-5 numbered questions). Every strong peer has a hard "not building" artifact (Shape Up no-gos, to-spec Out of Scope, gstack NOT in scope). gstack and autoplan keep a decision log with one row per decision. Ryan Singer's own shaping skills warn they are GIGO. Nobody has shipped a betting table or a four-risk exit gate; those slots are open.

## The 10x shape

Keep: the Red Team pass (cross-model, fresh context), drift detection, compound learnings, the PRD-in-repo + Linear write, the kick-back rule downstream.

Change:
1. **Output contract first.** Every PRD carries loop sentence, appetite, skeleton M1, Later Shelf (defer reason + kill condition + re-price date), executable acceptance criteria per feature, and a dependency order line. Every issue leaves with a build packet stub and a `tier:*`. This is what makes Caspian's output `spec-ready` for `/ce-plan` → `/packets` → `/goal`.
2. **Personas → lenses + stances.** Drop the five names. Keep five lenses as a checklist the run must show it applied (lint: ≥2 lenses named per decision). Put the *opposition* where the evidence says it works: the Red Team on a different model, briefed without the council's recommendation.
3. **Gates: six → two.** One "frame + press release + mode: lock or amend" checkpoint (rendered before asking, always), one scope/sequence checkpoint, then ship. All questions in batched rounds with a recommended answer. Undisputed items in one multi-select.
4. **Honor stored learnings as overrides,** not notes. `founder-closes-interrogation` means one probe, then move.
5. **Argue sequence, not scope.** Phase 5 alternatives default to orderings of the same scope; scope cuts happen via the skeleton test, once.
6. **Add PACKET mode** (~30 min): one feature, existing PRD, skip framing and press release, one Red Team, issues into an existing milestone. Matches spec-day cadence.
7. **Load by phase.** Four files at start (~10k words), the rest at the phase that needs them. Purge retired tooling and dedupe anti-sycophancy / refresh tiers to one home each.
8. **Verify the write.** After Linear write, re-read the PRD, assert `linear_issues` non-empty and frontmatter valid; fail loudly.
9. **Four-risk exit gate.** Before ship: value / usability / feasibility / viability each has a named test or a stated "accepted" — the one thing no comparable skill does.
10. **Janitor + shelf exit.** Surface stale active sessions at kickoff; Later Shelf items with expired kill conditions surface at the Bet stage.

Expected effect: ~2-3 h → ~1 h per NEW run, ~30 min PACKET runs, cold start halved, and issues that enter the night queue without a second planning pass.
