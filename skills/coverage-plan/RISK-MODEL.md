# Risk model — rank by blast radius, not line count

A coverage percentage treats a 200-line string formatter and a 200-line authorization check as
equally important. They are not. Rank uncovered code by what happens when it's wrong, then by size
only within a tier.

## Ranking order

1. **Authentication & authorization.** Session/token handling, role gates, permission checks. Weight
   **branch** coverage heavily here specifically — a route with 0% branch coverage (every request
   in the test suite took the same code path) is worse than a route with 0% statement coverage on a
   file nobody calls yet, because it means the failure path (wrong role, expired token, missing
   permission) has never once been exercised.
2. **Multi-tenant / row-scoping boundaries.** Any place a `WHERE`/`filter`/`scope` clause is the
   only thing standing between one customer's data and another's. This is the highest-consequence,
   lowest-visibility category: the code often looks completely correct on read, and a missing scope
   clause produces no error, no crash, no log line — just silent data leakage to the wrong tenant.
3. **Money and irreversible actions.** Payments, refunds, bids/offers, deletions, state transitions
   that notify or charge someone. A bug here either costs money directly or can't be undone by
   re-running anything.
4. **PII/PHI or other regulated-data handling.** Classification at intake, retention, export,
   erasure/right-to-be-forgotten flows. Distinct from #2 (tenant isolation) — this is about the
   *type* of data, not who can see it.
5. **Unattended execution.** Cron jobs, queue consumers, webhook handlers, scheduled migrations.
   Nobody is watching in real time when these run, so a silent failure mode here can persist for a
   long time before anyone notices — unlike a user-facing bug, which someone eventually reports.
6. **Application assembly and error handling.** The app-factory function itself (middleware order,
   CORS/CSP/body-size limits), and the global error handler (does it leak stack traces / internal
   error messages to the client). Almost always at or near 0% because no test ever imports the real
   app factory — tests build a stripped-down substitute instead. Cheap to fix with one smoke test
   and worth doing early because it's cheap, not because it's the highest risk.
7. **Everything else.** Rank by uncovered-statement-count purely for the number, and say so plainly
   in the plan — "the rest of this list moves the percentage, not the risk."

## Coverage-blindness patterns

These are the things a percentage cannot show, and they are usually more valuable to name than any
single uncovered file. State them explicitly whenever found — don't bury this in a table.

- **Mocked-boundary blindness.** A test that mocks the database (or any I/O boundary) and asserts
  the exact query/payload the code under test produces will happily pass at 100% while a real bug
  ships — the person writing the test reads the implementation and encodes it into the assertion,
  so the test and the bug agree. This catches *regressions* (a later change breaks the query) but
  can never catch the *original* mistake. High coverage of a fully-mocked service layer is not
  evidence the underlying logic is correct — only that it's pinned.
- **Stubbed-gate blindness.** Route/endpoint tests that substitute a fake or bypassed auth
  middleware (common when the "real" middleware needs a live token issuer) verify that the gate is
  *wired into the route*, not that the gate itself *works*. Look for whether auth middleware tests
  exist against the real implementation, separately from route tests that stub it.
- **Assertion-free execution.** Coverage instruments lines *run*, not outcomes *checked*. A test
  that calls a function and asserts nothing about the result, or a snapshot test that never gets
  reviewed when it changes, executes the code and moves the number without verifying behavior.
- **High-coverage trivia masking low-coverage branches.** Straight-line code (string builders,
  formatters, simple mappers) naturally reports very high statement coverage from just a few calls,
  while its conditional edge cases (empty input, a rare enum value, an error branch) sit at far
  lower branch coverage. A file at "99% statements" can still be 50% branches — check both, always,
  and don't let a high statement number stand in for the file being well-tested.
- **Report-only thresholds.** A coverage config with `reporter` but no `thresholds`/gate configured
  means the number can silently regress in either direction and nobody would know until asked. This
  is a finding in itself, separate from what the number currently reads.

## Ratchet, don't target

Unless the user states an external reason for a specific number (a customer contract, an existing
team OKR, an auditor's ask), don't propose an aspirational threshold. Set the gate to *current
measured coverage, rounded down*, so:

- CI catches regressions immediately (the actual value of a threshold).
- The floor rises naturally as coverage work lands, with no need to remember to bump it.
- Nobody is asked to hit a number that was invented rather than earned.

If asked "what should our target be," the honest answer is usually "there isn't one that means
anything — the risk-ranked list is the target." Say that, then let the user decide if they still
want a hard percentage on top.
