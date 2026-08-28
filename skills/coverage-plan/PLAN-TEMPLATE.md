# Output plan skeleton

Use this structure for the written plan. Headings are a guide, not a rigid contract — merge or
drop sections that don't apply (e.g. a single-language single-workspace repo doesn't need a
per-workspace breakdown), but don't skip the denominator-correction callout or the coverage-
blindness section even if they seem obvious in context; they're the parts most likely to get
skimmed past later.

---

## 1. Honest baseline

State the measured number(s) per stack/workspace, and **if a denominator problem was found and
fixed, say so explicitly with the before/after and the magnitude of the correction** — this is
often the single most important sentence in the document. Example shape:

> `apps/web` reported 96.01% before `coverage.include` was set (measuring 8 of 359 source files).
> The corrected number is 1.75%.

List any stated exclusions (generated code, etc.) and why.

## 2. Structural findings

The 2-4 sentence-level facts about *how* the test suite is built that explain the number better
than any list of files — e.g. "every route test stubs the auth middleware," "the suite has no
API-mocking layer at all," "coverage.py's branch flag was never enabled." These are usually more
actionable than the risk-ranked table below, because fixing one structural issue unblocks many
individual files at once.

## 3. Risk-ranked gaps

A table, ordered per `RISK-MODEL.md` (auth/authz → tenant boundaries → money/irreversible → PII/PHI
→ unattended execution → app-assembly/error-handling → everything else). Columns: target,
current %, why it's ranked here. Keep this scannable — link to specific files/line ranges, don't
paste code.

## 4. Missing test kinds

Explicit list of test *shapes* that don't exist yet, not just files that lack tests — e.g.
"authorization-contract tests against the real middleware" or "tenant-isolation tests against a
real database instead of a mocked client." Say what each would catch that the current suite
cannot. This section is what turns a coverage report into an actual plan.

## 5. Ratchet / gate configuration

The concrete config change per stack (threshold values, where they go, what CI step runs it).
Values must be current-measured-and-rounded-down, per `RISK-MODEL.md` — never aspirational.

## 6. Sequencing

Group into roughly 3 tiers by cost/value, not a rigid schedule:
- **Now** — cheap, high-signal, no new infrastructure needed.
- **Next** — needs a new test kind/harness piece (mocking layer, integration DB, contract-test
  scaffold) but is otherwise contained.
- **Later** — larger builds, or items blocked on something outside the test suite itself.

## 7. Compliance mapping (only if the user asked for SOC 2 / HIPAA / similar framing)

State up front: **no framework mandates a coverage percentage.** Then map only the items that
genuinely produce control evidence to their control IDs (e.g. an authorization-contract suite →
SOC 2 CC6.1 / HIPAA §164.312(a)(1)). Don't stretch — most of the risk-ranked list is engineering
hygiene, not compliance evidence, and conflating the two undermines both.

## 8. Verification

How to prove each new test actually tests something — the standard is "removing the thing it
guards makes it fail," not "it runs green." For a new authorization test: temporarily delete the
role check and confirm the test fails, then restore it. For a new tenant-isolation test: remove a
scope clause locally and confirm it fails. State this as the acceptance bar for anyone implementing
the plan, not just as something the plan author did once.
