# CI speed vs fidelity for small agent chunks

Date: 2026-09-26. Trigger: the Motus circuit player was cut into 12 chunks. At one PR per chunk, that meant about 8 runner-hours of CI on one self-hosted iMac. Two web research passes plus a local measurement.

## Local measurement (Motus, run 36243649241)

| Step | Time |
|---|---|
| App unit tests (MotusTests, ~400 tests) | under 10 s |
| MotusKit `swift test` | about 1 min |
| App build (simulator) | 42 s, then compiled again inside the test job |
| Release archive on every PR | 112 s |
| PR UI smoke tests (10 tests, serial) | about 10 min. One onboarding accessibility matrix test takes 125 s. |
| Whole PR run, jobs serialized on one runner | about 19 min |
| Post-merge full run on main | about 24 min, and it occupies the same runner |

Most PR time goes to UI tests unrelated to the change. It also goes to compiling twice.

## Findings (with sources)

1. **Selective (impacted) testing is the biggest lever.** Monzo went from a 52 to a 15 minute median PR run with Tuist selective testing, binary cache and generation, running about 200 tests instead of 23k+ per change ([Tuist: Monzo](https://tuist.dev/customers/monzo); vendor case study). Trendyol reports about 8x faster unit CI. Every team backstops it with the full suite on main or nightly. The risk is a missed dependency edge. Open-source option without Tuist: [XcodeSelectiveTesting](https://github.com/mikeger/XcodeSelectiveTesting). See also [Tuist selective testing for Xcode projects](https://tuist.dev/blog/2025/02/18/selective-testing-for-xcode-projects).
2. **Build once, test many.** `build-for-testing` then `test-without-building` removes duplicate compiles at no fidelity cost.
3. **Fast presubmit, full postsubmit.** At Google, fast presubmit results predict about 95% of postsubmit outcomes, and the full suite runs continuously after merge ([Efficacy of presubmit](https://testing.googleblog.com/2018/09/efficacy-presubmit.html)). The "not rocket science rule" and [DORA trunk-based development](https://dora.dev/capabilities/trunk-based-development/) keep main always green.
4. **Batch merges, keep review units small.** Merge queues batch PRs into one CI run and bisect on failure ([Graphite on batching](https://graphite.com/blog/merge-queue-batching); vendor). Shopify validates against a predictive branch ([Shopify merge queue](https://shopify.engineering/introducing-the-merge-queue)). Uber's SubmitQueue speculates and let large diffs bypass the queue, cutting P95 wait by 74% ([Uber](https://www.uber.com/blog/bypassing-large-diffs-in-submitqueue/)).
5. **Review quality falls past about 200 to 400 LOC per review** ([SmartBear/Cisco study summary](https://mikeconley.ca/blog/2009/09/14/smart-bear-cisco-and-the-largest-study-on-code-review-ever/)). This argues for small review units, not small CI units, so per-commit review inside a grouped PR keeps the benefit.
6. **Capacity is cheap for self-hosted Macs.** One engineer replaced about $4k a month of hosted macOS minutes with three Macs at about $64 a month, giving 12+ concurrent slots ([writeup](https://jeffverkoeyen.com/blog/2025/10/17/SelfHostingMacMinis/)). Shopify targets sub-10-minute required mobile pipelines ([Shopify dynamic mobile CI](https://shopify.engineering/building-a-dynamic-mobile-ci-system)).
7. **Flaky tests** should be quarantined on a rolling success rate: still running, non-blocking, reviewed weekly ([test quarantine design](https://trinhngocthuyen.com/posts/tech/test-quarantine/)).

**AI-agent-specific practice (2025–2026):** no published batching policy exists yet. Teams reuse merge queues and stacking. Treat this as a gap, not a finding.

**Unverified and excluded:** reports of GitHub-native stacked PRs in 2026 public preview. The source dates conflicted.

## What we adopted

D-025: landing groups (group PRs) plus CI tiers. It is canonical in `dev-workflow/AGENTS.workflow.md`, and every wired repo syncs it.
