# CONCEPTS.md Format

`CONCEPTS.md` is the one project glossary. It is shared with compound-engineering: `ce-compound` and `ce-compound-refresh` add terms to the same file during the Learn phase, and this skill adds them during grilling. One file, one format, two writers. Never create a second glossary (`CONTEXT.md`, `GLOSSARY.md`) beside it.

## Structure

```md
# Concepts

{One or two sentences: shared domain vocabulary for this project. Glossary only, not a spec.}

## {Cluster name, e.g. Booking}

### Reservation
A future commitment to seat a Party at a specified date and time.
*Avoid:* Booking, appointment

A Reservation owns its Party but does not own a Table. Lifecycle: Booked, Seated, Completed, No-Show.

### Party
The guests committed to a Reservation. Each Reservation has exactly one Party.

## Flagged ambiguities

- "account" had been used for both Customer and User. These are distinct.
```

## Rules

- **Be opinionated.** When several words exist for one concept, pick the best and list the rest on an `*Avoid:*` line directly under the definition.
- **One-sentence definitions.** Say what the term IS in this domain and what separates it from its neighbours. A second paragraph is earned only by non-obvious behavioural rules (lifecycle, ownership, cancellation semantics).
- **The file stands on its own.** No file paths, class names, table names, thresholds, dates, owners, PR or issue links, or version-specific claims. State the behaviour, not the number.
- **Only project-specific terms.** General programming vocabulary (caches, queues, sessions) stays out even when used heavily. The test: would a new engineer need this defined to follow a ticket?
- **Cluster by domain relationship** under `##` headings once natural groups emerge; a flat list is fine while the file is small. Terms are `###` headings.
- **Settled distinctions go to `## Flagged ambiguities`** at the tail, one line each. That section is the audit trail for vocabulary decisions made during grilling.
- **If an entry leans on another project-specific term, define that term too.**

## Location

One `CONCEPTS.md` at the repo root. Create it lazily, when the first term is resolved. If the file already exists, match its existing clusters and heading style rather than reshaping it.
