# Linear write (Caspian v3, Phase 5)

Loaded only at Phase 5, after the PRD is on disk. Follow AGENTS.md > Linear structure where it is stricter. Idempotent: re-running on the same PRD updates, never duplicates. Record each step's result in the session file so a failure resumes at the failed step.

1. **Gate.** The PRD is saved and status is `approved`. If the user chose "stop at the PRD" in NEW mode, stop here and leave the session resumable.
2. **Project.** Read `.linear-project.json` at the repo root (monorepo: the app's link file). Missing → this is the ship gate: offer (a) run `/zmcray-kickoff` now and continue, (b) stop at the PRD. Never create a bare project silently.
3. **Initiative.** One per product, ever. Find it by product name; create only if none exists (NEW). EXPAND and REFRESH never create one. Push the press release + problem statement + strategic fit as its description.
4. **Milestones.** One per M1 outcome, named as a user outcome (`<Epic> 1: <Outcome>`), plus `<Epic>: later` for the shelf. Update description with `Outcome:` and `Order:` lines so the order reads without opening an issue.
5. **Issues, one per M1 feature, in dependency order** so edges reference real IDs:
   - Title: imperative, one line. Priority from the sequence; never None.
   - Labels: exactly one `flow:*` (by blast radius), exactly one `tier:*` (from the PRD), `prd-source`, `spec-ready`. Never `night-eligible` (human-applied).
   - Milestone: the M1 milestone. Relations: native `blocked by` from the sequence line.
   - Body: a build-packet stub:
     ```
     ## Build packet
     Spec: <repo-relative PRD path> § <feature anchor>
     Acceptance criteria:
     - WHEN ..., the system SHALL ...  (verified by: ...)
     Artboard: <approved canvas link, or "n/a (no UI)", or "needed: design session before build">
     File scope: to be set by /packets
     Out of scope: <feature's "Not here" line>
     ```
   - Later Shelf items: one issue each, label `deferred` only (no `spec-ready`), priority Low, milestone `<Epic>: later`, body = defer reason + kill condition + re-price date. Killed features get no issue.
6. **Document.** Push the PRD as the project's Linear document (create or update by title).
7. **Back-write.** PRD frontmatter: `linear_initiative`, `linear_project`, `linear_issues` (all created IDs), `last_refreshed` for REFRESH. Then the `**Latest PRD:**` line in the repo's `PROJECT.md` if it exists.
8. **Verify (mandatory).** Re-read the PRD from disk. Assert: frontmatter starts and ends with `---`; `linear_initiative` is a real ID; `linear_issues` length equals the number of M1 features created. On any mismatch print `LINEAR WRITE FAILED at step N: <reason>` and stop. Do not print a success close.
9. **Close message** per the skill's §Ship.

Failure recovery: log step number and error to the session file; offer retry (that step onward) or pause (session stays active and resumable).
