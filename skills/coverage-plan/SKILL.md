---
name: coverage-plan
description: Audit a repository's real test coverage, risk-rank what's untested, and write an actionable coverage plan. Detects the stack and coverage tooling, corrects the default-denominator traps that make coverage numbers read far higher than they actually are, ranks gaps by security and business risk rather than line count, and installs a ratcheting threshold so coverage can't silently regress. Use when asked to "check test coverage", "why is coverage so low/high", "write a testing plan", "what should we test next", "add coverage thresholds", or when preparing coverage evidence for SOC 2 / HIPAA / an enterprise security questionnaire.
---

# Coverage plan

Produces an honest coverage baseline for a repository, ranks the gaps by actual risk, and writes
an actionable plan — a workflow refined auditing real production TypeScript and Python monorepos,
generalized to any language.

## Why this skill exists

**Coverage tools lie by default, and they lie in the flattering direction.** On the repo this
skill was built for, a web app's Vitest config reported 96.01% statement coverage. The real number,
once the config was fixed, was 1.75% — a 55x overstatement. The tool wasn't broken; it was doing
exactly what its default does: measuring only files a test happened to import, and staying silent
about the hundreds that were never touched. Every major coverage tool has some version of this
trap (see `ECOSYSTEMS.md`), and it always fails upward — never once does the default make a number
look worse than reality. Treat every coverage percentage you haven't personally verified as
optimistic until proven otherwise.

The other thing a percentage cannot tell you is *what kind* of testing is missing — not "which
files," but which entire test **shapes** don't exist yet (an authorization test that exercises the
real gate instead of a stub; an integration test against a real database instead of a mock). See
`RISK-MODEL.md`.

## Workflow

1. **Detect.** Run `scripts/detect.sh` (read-only — identifies stack(s), package manager, test
   runner, coverage tool, monorepo layout, and any existing coverage config/thresholds). A repo can
   have more than one stack; handle each one. Read the actual config files it finds — don't infer
   from the language alone, since teams override defaults.

2. **Measure honestly.** Run the coverage command for each stack. Before reporting any number,
   **verify the denominator**: compare the file count in the coverage report against the file count
   on disk (`find src -name '*.ts' | wc -l` or equivalent, minus stated exclusions). If they don't
   roughly match, the report is measuring the wrong set — find the include/all-files flag for that
   tool in `ECOSYSTEMS.md`, fix the config, and re-run. **This step is not optional and not
   skippable.** Report statement *and* branch coverage separately — branch is usually far worse and
   is where auth/validation bugs actually live.

3. **Risk-rank the gaps.** Don't sort by uncovered-line-count. Use the ordering in
   `RISK-MODEL.md` — auth/authz first, then tenant/row-scoping boundaries, then irreversible or
   money-moving actions, then PII/PHI handling, then unattended execution (cron/queue/webhook),
   then app-assembly/error-handling, then everything else purely for the number.

4. **Name the missing test kinds**, not just the missing files. If every test in a layer mocks the
   same boundary (a DB client, an auth middleware), say explicitly what that blind spot is and what
   test shape would close it — see the "coverage-blindness" list in `RISK-MODEL.md`. This is
   usually the single most valuable finding in the whole exercise, and it never shows up as a
   percentage.

5. **Write the plan.** Follow `PLAN-TEMPLATE.md`. Save it to the repo's docs location (ask if
   unclear — `docs/coverage-plan.md` is a reasonable default) unless the user asked for chat output
   only.

6. **Install the ratchet, if asked to implement (not just plan).** Set each stack's coverage
   threshold to *current measured coverage, rounded down* — never an aspirational number — and wire
   the coverage command into CI so a regression fails the build. Raise the floor later as coverage
   improves; never lower it without a stated reason in the commit message.

## Ground rules

- **Never weaken or delete a test to make a number move.** If existing tests are wrong, say so and
  ask before changing them — this mirrors the general testing rule and applies doubly here, since
  the entire point of this skill is catching that kind of shortcut, not committing it.
- **State every exclusion.** Generated code (ORM clients, protobuf/OpenAPI stubs, migrations) is a
  legitimate `exclude`, but a silent exclusion is exactly the same trick as an unfixed denominator.
  List what's excluded and why, in the plan.
- **Don't propose a number chase.** If a user wants "80% coverage" as a goal in itself, push back:
  explain the ratchet-not-target framing from `RISK-MODEL.md` and ask whether they actually want
  the risk-ranked plan instead, or truly want a hard percentage gate (sometimes there's a real
  external reason — a customer contract, an existing team OKR — in which case respect it, but make
  them say so explicitly).
- **Compliance framing (SOC 2 / HIPAA / similar):** map specific coverage work to control IDs when
  asked (e.g. an authorization-contract-test suite → SOC 2 CC6.1 / HIPAA §164.312(a)(1)), but state
  plainly, every time, that **no framework mandates a coverage percentage** — coverage is one cheap
  way to produce testing evidence, not a compliance requirement in itself. Don't let the output be
  misread as "N% = compliant."

## Reference files

- `ECOSYSTEMS.md` — per-language detection, coverage commands, the denominator trap and its fix,
  threshold config syntax. Read only the section(s) relevant to the detected stack(s).
- `RISK-MODEL.md` — the risk-ranking order and the coverage-blindness patterns to call out.
- `PLAN-TEMPLATE.md` — the output document skeleton.
