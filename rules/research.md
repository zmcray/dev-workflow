<!-- Moved from the canonical AGENTS.md block (MCR-2720). Read on demand; binding when it applies. -->

# Research corpus

Every project keeps reusable research in `docs/research/`. The corpus is the evidence layer, separate from strategy and delivery documents:

```text
docs/research/
├── README.md          # Corpus rules, evidence vocabulary, contribution workflow
├── INDEX.md           # Searchable map of topics, coverage, and open gaps
├── topics/            # Cross-source syntheses with stable claim IDs
├── sources/           # One evidence card per paper, dataset, or first-party source
└── templates/         # Required topic and source-card shapes
```

- **Sources record evidence.** Capture the method, population, exact findings, limitations, durable link, and which claim IDs the source supports. Label telemetry, experiments, surveys, qualitative work, literature reviews, first-party product statements, and vendor research distinctly.
- **Topics synthesize evidence.** State bounded findings with stable claim IDs, confidence, scope, disagreement, product implications, what the evidence does not prove, and explicit triggers for further research.
- **The index routes discovery.** Keep topic status, last-review dates, coverage, source inventory, and gaps current so an agent can find relevant work without rereading the repository.
- **PRDs and plans make decisions.** They cite topic claim IDs rather than duplicating research prose. Decision documents may interpret the evidence, but must distinguish findings from assumptions and product judgment.
- **Research is cumulative.** Before commissioning more, search the corpus and reuse what applies. Extend it only when a load-bearing claim is unknown, conflicting, materially stale, or outside the studied population/context. If the remaining question is product-specific, prefer an instrumented test with success and kill conditions.
- **New evidence returns to the corpus.** Add or update source cards, topic synthesis, and index coverage before closing research-bearing work. Do not store participant personal data, credentials, paywalled copies, or copyrighted full texts.

Every Think or Plan phase that depends on user, market, workflow, or behavioral claims begins by reading `docs/research/INDEX.md`. The resulting design doc or plan includes a short **Research decision**: `reuse`, `extend`, or `none needed`, with linked claim IDs and any additional research required. Absence of relevant corpus evidence is a signal to evaluate the gap, not an automatic mandate to research.
