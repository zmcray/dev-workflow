# Classifier pass for the pitfall study

The judged numbers (corrections and hand-backs per 100 messages) need one agent pass over the extracted messages. Run it from a Claude Code session in dev-workflow, on a cheap model, one subagent per group of repos.

## Prompt for each subagent

Read every line of the JSONL files you are given, in `.local/agent-pitfalls-<days>d-<date>/messages/`. Each line is one message Zack typed (`text`) and the tail of the agent reply before it (`prev_assistant`).

A **correction** is Zack pushing back on what the agent did or proposed: "no", "why would you", "I said", "it still doesn't work", repeating an earlier instruction, rejecting an approach, pointing out a missed requirement. Plain approvals ("yes", "merge", "reco") are not corrections.

Label each correction with one class:

- `hands-work-back`: the agent gave Zack a step it could do itself
- `broken-human-steps`: steps written for Zack that don't match his machine or screens
- `unverified-done`: the agent claimed done or fixed without proof on the real thing
- `wrong-intent`: the agent built or planned what Zack didn't mean
- `duplicate-source-of-truth`, `copied-stale-pattern`, `config-env-drift`, `process-git`, `over-engineering`, `scope-creep`, `unclear-communication`, `ui-polish`, `regression`
- `other`: say what in a few words

Write `.local/agent-pitfalls-<days>d-<date>/judged-<group>.json` as `{"messages_read": N, "corrections": [{"repo", "date", "session", "class"}]}`. Never copy Zack's words into a file outside `.local/`.

## Then report

- Corrections per 100 messages, overall and per class.
- Hand-backs per 100 messages (`hands-work-back`).
- The same numbers from `baseline-2026-10-16.json` next to them.
