# Caspian lenses, questions, and briefs

Loaded at Phase 1, 3, and 4. Kept short on purpose; the skill file holds the process.

## Premise challenge (Phase 1, prose, thirty seconds)

- Is this the right problem, or a proxy for a deeper one? ("A dashboard" often means "I don't trust my numbers.")
- What happens if we do nothing? If the honest answer is "not much," that is the finding.
- What is the most direct path to the outcome? Sometimes it is "don't build this." Say so; a kill at Phase 1 is a win.

No solutioning here. The only output is: the problem is real and worth solving, or it is not.

## Forcing questions (Phase 1, batched, 2-3 per run, recommended answer on each)

Stance: specificity is the only currency; interest is not demand; the status quo is the real competitor; the user's words beat the founder's pitch.

| # | Question | Push back on |
|---|---|---|
| Q1 Demand | Who would be genuinely upset if this disappeared tomorrow? | "People would like it." Mild interest dressed as demand. |
| Q2 Status quo | What is the user doing about this right now, without you? | "Nothing" (no pain). "A huge mess" with no attempt to fix it. |
| Q3 Specificity | Name the actual human. What gets them promoted or fired? | A category. A title with no context. "Our users." |
| Q4 Wedge | Smallest version someone would pay for this week? | A platform. "They'd need the whole thing." |
| Q5 Evidence | What have you observed (not asked) them do? | Surveys. Hypotheticals. "They said they would." |
| Q6 Future-fit | In three years, more essential or less? | A feature, not a product. Erased by a platform shift. |

Routing: new idea → Q1, Q2, Q3. Has users, no revenue → Q2, Q4, Q5. Paying customers → Q4, Q5, Q6. Internal tool → Q2 and Q5 only, plus "which STRATEGY.md track does this serve." Smart-skip anything already answered. If the learning `founder-closes-interrogation` is active, this round is the whole interrogation.

## The five lenses (Phase 3; run at least two, name them, say what each surfaced)

Method diversity beats persona diversity. Five names reasoning the same way converge and call it consensus. Five methods on the same problem surface the disagreements that matter.

1. **Inversion (premortem).** It is twelve months out and this flopped. Most likely autopsy? Then flip each core assumption and see if the plan survives.
2. **First principles.** Forget how it is done today. What is actually true about this user's situation, and what is inherited convention?
3. **Analogy.** Who outside this space solved a problem shaped exactly like this, and what did they do?
4. **Naive outsider.** Explain it to someone who has never touched the category. Where do they get confused or call BS? This catches jargon hiding fuzzy thinking.
5. **Dependency graph.** What has to be true first? Which feature is load-bearing for the most others? Where is the riskiest link? This is the executor's check on the dreamer.

## Four risks (Phase 3, one line each per M1 feature)

Value (will they use it), usability (can they work it), feasibility (can we build it with what we have), viability (does it work for the business). "Untested" is a legal answer and an important one. The four-risk exit in Phase 5 requires each risk to have a named test in M1 or the word "accepted" with a reason.

## Skeleton test (Phase 3, the only scope cut)

A feature enters M1 only if the loop sentence breaks without it. Everything else is Later Shelf: defer reason, kill condition, re-price date. If M1 still exceeds the appetite, re-cut once. Then argue **sequence**, not scope: two or three orderings of the same M1, recommend the one that retires the dominant risk first.

## Briefs (Phase 4; fresh context; the reviewer never sees the conversation)

### Red Team (prefer Codex, a different model)

Hand it: press release, problem statement, M1 list with rationale, Later Shelf, and the sequence alternatives **without saying which was chosen**.

> You are a brutally honest product reviewer with no stake in this plan and no knowledge of how it was made. Your job is not to validate it. Find what is wrong. Answer with numbered findings only:
> 1. Strongest case that this is the wrong problem or the wrong customer.
> 2. What the team most likely got attached to that they should cut.
> 3. The riskiest assumption holding up the plan, and whether it is tested or hoped.
> 4. Which alternative ordering is actually best, and why.
> 5. What everyone missed.
> Be direct and terse. No compliments. If the plan is sound, name the two things most likely to break it anyway.

### Eng review (fresh context; may see ground truth)

Hand it: M1 list with four-risk notes, sequence, dependency line, current Linear state, `AGENTS.md`, and a file tree.

> You are a skeptical staff engineer reviewing a plan you did not write. Do not judge the product. Find where the plan breaks in the building. Numbered findings only:
> 1. The real dependency chain. Which feature is load-bearing for the most others? Does the sequence respect it?
> 2. The most under-estimated feature, and why.
> 3. Any existing constraint (repo, backlog, listed dependency) the plan ignores or contradicts.
> 4. Which "feasibility: fine" call is wrong.
> 5. What the builder hits in week one that is not in the plan.
> Cite the specific feature. If it is buildable, name the two most fragile links anyway.

A reply without numbered findings is a failed run. Re-run once, then report the failure. Findings are adjudicated by the user in one batched round; nothing auto-incorporates; holds are logged too.
