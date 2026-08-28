# coverage-plan

A [Claude Code](https://claude.com/claude-code) skill that produces an honest test-coverage
baseline for a repository, risk-ranks what's actually untested, and writes an actionable plan —
instead of trusting whatever percentage your coverage tool prints by default.

## Why this exists

Coverage tools lie by default, and they lie in the flattering direction. Here's a minimal,
reproducible example: a three-file project where only one file has a test.

**Before** (Vitest's default coverage config — only measures files a test happened to import):

```
 % Coverage report from v8
----------|---------|----------|---------|---------|-------------------
File      | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
----------|---------|----------|---------|---------|-------------------
----------|---------|----------|---------|---------|-------------------

=============================== Coverage summary ===============================
Statements   : 100% ( 2/2 )
Branches     : 100% ( 0/0 )
Functions    : 100% ( 2/2 )
Lines        : 100% ( 2/2 )
================================================================================
```

*(Vitest's default report lists no files at all here — the 2/2 statements are `math.js`, the only
file any test imported.)*

**After** (fixing the denominator with `coverage.all: true` and an explicit `include`):

```
 % Coverage report from v8
----------------|---------|----------|---------|---------|-------------------
File            | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
----------------|---------|----------|---------|---------|-------------------
All files       |      25 |        0 |   33.33 |   28.57 |                   
 stringUtils.js |       0 |        0 |       0 |       0 | 2-7               
 validators.js  |       0 |        0 |       0 |       0 | 2-6               
----------------|---------|----------|---------|---------|-------------------

=============================== Coverage summary ===============================
Statements   : 25% ( 2/8 )
Branches     : 0% ( 0/5 )
Functions    : 33.33% ( 2/6 )
Lines        : 28.57% ( 2/7 )
================================================================================
```

*(`math.js` is 100% and elided from this table since it has no uncovered lines; the two
never-imported files now appear, dragging the real number down to 25%.)*

The tool wasn't broken — it was doing exactly what its default does: measuring only files a test
happened to import, and staying silent about the ones that were never touched. Every major
coverage tool (Jest, Vitest, pytest-cov, go test, SimpleCov, JaCoCo...) has some version of this
trap. It always fails upward — the default never makes a number look worse than reality.

The other thing a percentage can't tell you is *what kind* of testing is missing — not "which
files," but which entire test **shapes** don't exist yet (an authorization test that exercises the
real gate instead of a stub; an integration test against a real database instead of a mock).

This skill automates both fixes: it verifies the denominator before reporting any number, and it
ranks gaps by blast radius (auth, tenant isolation, money, PII, unattended execution) instead of
raw line count.

## What it does

1. **Detects** your stack, test runner, and coverage tool (read-only).
2. **Measures honestly** — verifies the coverage report's file count against the real file count on
   disk, and fixes the config if they don't match.
3. **Risk-ranks the gaps** using a fixed ordering (auth/authz → tenant isolation → money/irreversible
   actions → PII/PHI → unattended execution → app assembly/error handling → everything else).
4. **Names the missing test *kinds***, not just missing files — e.g. "every test in this layer mocks
   the database, so a real integration-test gap exists that no percentage will ever show you."
5. **Writes a plan** to `docs/coverage-plan.md` (or wherever you prefer).
6. Optionally **installs a ratcheting coverage threshold** in CI, set to current measured coverage
   (never an aspirational number), so regressions fail the build automatically.

See [SKILL.md](skills/coverage-plan/SKILL.md) for the full workflow,
[RISK-MODEL.md](skills/coverage-plan/RISK-MODEL.md) for the ranking rationale,
[ECOSYSTEMS.md](skills/coverage-plan/ECOSYSTEMS.md) for per-language detection and denominator
fixes, and [PLAN-TEMPLATE.md](skills/coverage-plan/PLAN-TEMPLATE.md) for the output document
shape.

## Install

Copy the skill directory into your Claude Code skills folder:

**User-wide** (available in every project):
```bash
git clone https://github.com/ErmisSolutions/claude-skill-coverage-plan.git
cp -r claude-skill-coverage-plan/skills/coverage-plan ~/.claude/skills/coverage-plan
```

**Project-scoped** (checked into one repo, shared with your team):
```bash
git clone https://github.com/ErmisSolutions/claude-skill-coverage-plan.git
cp -r claude-skill-coverage-plan/skills/coverage-plan /path/to/your/project/.claude/skills/coverage-plan
```

Then, in Claude Code, just ask:

> - "check our test coverage"
> - "why is coverage so low"
> - "what should we test next"
> - "write a testing plan"
> - "add coverage thresholds"

Claude Code will pick up the skill automatically based on its description — no slash command
needed.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- A repo with an existing test suite and coverage tool (or one you're willing to add) — see
  `skills/coverage-plan/ECOSYSTEMS.md` for supported languages/tools.

## License

MIT — see [LICENSE](LICENSE).
