# Ecosystem reference — detection, commands, denominator traps, thresholds

Read only the section(s) matching the detected stack(s). Verify against current tool docs before
relying on version-specific behavior here — defaults change across majors (Vitest 4 removing
`coverage.all` is the case that motivated this file, and it's exactly the kind of thing that will
happen again).

---

## TypeScript / JavaScript

### Vitest (v8 or istanbul provider)

- **Detect:** `vitest.config.ts`/`.js`, or a `test`/`vitest` block in `vite.config.ts`; `vitest` in
  `package.json` devDependencies.
- **Run:** `vitest run --coverage` (needs `@vitest/coverage-v8` or `@vitest/coverage-istanbul`
  installed — check `package.json`, add if missing).
- **The trap:** Vitest 4 removed `coverage.all`. Without an explicit `coverage.include`, the report
  contains only files a test module actually imported — untouched files are absent from the
  denominator, not scored 0%. A repo with 350 source files and 8 imported-by-tests files will
  report near-100% while testing 2% of its surface.
- **Fix:** set `coverage.include` to the full source glob, e.g. `include: ['src/**/*.{ts,tsx}']`,
  separate from `test.include` (the test-file glob). Confirm the fix worked by checking the
  reported file count against `find src -name '*.ts*' | grep -v test | wc -l`.
- **Thresholds:** `coverage.thresholds = { statements, branches, functions, lines }` (or per-glob
  via `coverage.thresholds['<glob>']` in v4). CI fails the run if any drop below.

### Jest

- **Detect:** `jest.config.*`, or a `jest` key in `package.json`.
- **Run:** `jest --coverage`.
- **The trap:** `collectCoverage: true` alone has the same shape as Vitest's old default — only
  required-by-a-test files are measured.
- **Fix:** set `collectCoverageFrom: ['src/**/*.{ts,tsx,js,jsx}']` explicitly (supports negation
  patterns for exclusions, e.g. `'!src/**/*.d.ts'`).
- **Thresholds:** `coverageThreshold: { global: { statements, branches, functions, lines } }`,
  with per-path overrides for stricter gates on sensitive directories.

### c8 / nyc (Istanbul-based, non-Jest/Vitest runners)

- **Detect:** `c8` or `nyc` in devDependencies, or an `.nycrc`.
- **Run:** `c8 <test command>` or `nyc <test command>`.
- **The trap:** `--all` (c8) / `all: true` (nyc `.nycrc`) is off by default — same denominator
  issue.
- **Fix:** `c8 --all --src=src <cmd>`, or `"all": true` + `"include": ["src/**"]` in `.nycrc`.

---

## Python

- **Detect:** `pytest.ini`/`pyproject.toml [tool.pytest.ini_options]` + `pytest-cov` in
  requirements/`pyproject.toml`, or bare `coverage.py` (`.coveragerc` / `[tool.coverage.*]`).
- **Run:** `pytest --cov=<package> --cov-report=term-missing --cov-branch`, or
  `coverage run -m pytest && coverage report`.
- **The trap, two-sided:**
  1. `--cov` with no argument, or `--cov=.`, sweeps in `.venv/`, migrations, and the test files
     themselves, deflating the number with irrelevant denominator noise in the *other* direction —
     still wrong, just wrong the other way.
  2. Default coverage.py measurement is **import-time only** for branch coverage — `branch = true`
     is opt-in, not default. Without it, an `if/else` with only one arm ever executed reports as
     fully covered.
- **Fix:** scope `--cov` to the actual package (`--cov=myapp`, not `--cov=.`), and set in
  `pyproject.toml`:
  ```toml
  [tool.coverage.run]
  source = ["myapp"]
  branch = true
  omit = ["*/migrations/*", "*/tests/*"]
  ```
- **Thresholds:** `[tool.coverage.report] fail_under = <int>` (statement %; coverage.py has no
  built-in separate branch-% gate — check the branch number by hand in CI output if it matters,
  which per `RISK-MODEL.md` it usually does for auth/validation code).

---

## Go

- **Detect:** `go.mod` present.
- **Run:** `go test -coverprofile=coverage.out ./...` then `go tool cover -func=coverage.out`.
- **The trap:** coverage is computed **per package**, and a package with zero `_test.go` files is
  silently absent from the report rather than shown at 0%. `go test ./...` alone under-reports the
  denominator by exactly the untested packages — the ones you most need to see.
- **Fix:** add `-coverpkg=./...` so every package in the module is counted against every test run,
  not just the package the test file lives in:
  `go test -coverpkg=./... -coverprofile=coverage.out ./...`
- **Thresholds:** no built-in gate; parse `go tool cover -func=coverage.out` output (last line is
  the `total:` percentage) and fail CI on it manually, or use a wrapper like `go-test-coverage`.

---

## Java / Kotlin (Maven / Gradle)

- **Detect:** `pom.xml` with `jacoco-maven-plugin`, or `build.gradle(.kts)` with the `jacoco`
  plugin.
- **Run:** `mvn test jacoco:report`, or `./gradlew test jacocoTestReport`.
- **The trap:** in a multi-module project, each module's JaCoCo report is independent — a module
  with no tests produces no report at all, and naive tooling that only reads per-module reports
  never notices it's missing. The aggregate/root report can also silently exclude un-configured
  modules.
- **Fix:** use JaCoCo's aggregate report goal
  (`jacoco:report-aggregate` in Maven, or the `jacoco` Gradle plugin's
  `JacocoReport` task wired to depend on `:allprojects`) so every module is enumerated even at 0%.
- **Thresholds:** JaCoCo `<rules>` in the Maven plugin config, or Gradle's
  `jacocoTestCoverageVerification` task with `violationRules`.

---

## Ruby

- **Detect:** `simplecov` in `Gemfile`, `.simplecov` file, or `SimpleCov.start` in `spec_helper.rb`.
- **Run:** `bundle exec rspec` (SimpleCov hooks in via `spec_helper.rb`, not a separate command).
- **The trap:** without `track_files`, SimpleCov only reports files that were `require`d during the
  run — files never loaded are invisible, same shape as the Vitest/Jest trap. Branch coverage is
  also off by default.
- **Fix:** in `.simplecov`:
  ```ruby
  SimpleCov.start do
    track_files "{app,lib}/**/*.rb"
    enable_coverage :branch
  end
  ```
- **Thresholds:** `SimpleCov.minimum_coverage 80`, `minimum_coverage_by_file`, or
  `refuse_coverage_drop` (fails if lower than the last run — a good built-in ratchet).

---

## C# / .NET

- **Detect:** `.csproj`/`.sln` with `coverlet.collector` or `coverlet.msbuild` referenced.
- **Run:** `dotnet test --collect:"XPlat Code Coverage"` (coverlet.collector), producing a
  `coverage.cobertura.xml`.
- **The trap:** assemblies/projects with no test project referencing them are absent from the
  merged report — same shape as Go's per-package gap and Java's per-module gap.
- **Fix:** run coverage from a test-aggregation project that references every source project, or
  merge with `coverlet` `--merge-with` across all test projects and explicitly pass
  `/p:Include="[*]*"` to include assemblies with zero hits.
- **Thresholds:** `/p:Threshold=<int>` `/p:ThresholdType=line,branch` `/p:ThresholdStat=total` on
  the coverlet MSBuild invocation.

---

## Rust

- **Detect:** `cargo-llvm-cov` or `cargo-tarpaulin` referenced in CI/docs, or `Cargo.toml` workspace
  with multiple crates.
- **Run:** `cargo llvm-cov --workspace --all-features --html`.
- **The trap:** without `--workspace`, only the crate you're in scope for is measured; a workspace
  member with no tests of its own is skipped rather than scored.
- **Fix:** always pass `--workspace --all-features`.
- **Thresholds:** `cargo llvm-cov --fail-under-lines <pct>` (also `--fail-under-branches` /
  `--fail-under-functions` on recent versions — check `cargo llvm-cov --help` for the installed
  version's flags).

---

## PHP

- **Detect:** `phpunit.xml`/`phpunit.xml.dist` with `pcov` or `xdebug` coverage driver installed.
- **Run:** `phpunit --coverage-text` (or `--coverage-html`), driver auto-selected from whichever
  extension is loaded (`pcov` is much faster than `xdebug` for this).
- **The trap:** without an explicit `<source>` (PHPUnit 10+) or legacy `<whitelist>`/`<include>`
  block, only files actually executed during the run are counted — files never `require`d are
  invisible.
- **Fix:** in `phpunit.xml`:
  ```xml
  <source>
    <include>
      <directory suffix=".php">src</directory>
    </include>
  </source>
  ```
- **Thresholds:** no built-in fail-under gate pre-PHPUnit-10; parse the text/clover report in CI
  and fail on it, or use `infection` (mutation testing) alongside for a stronger signal than a
  raw percentage.

---

## Cross-cutting notes (all languages)

- **E2E / browser coverage is a separate axis.** Playwright/Cypress instrumentation (e.g. via
  `nyc`/Istanbul babel plugin for E2E) measures a different thing than unit coverage and generally
  shouldn't be merged into the same number without saying so explicitly in the plan — a 90% "total"
  that's secretly 60% unit + 30% E2E-only reads very differently than 90% unit.
- **Generated code is a legitimate exclusion, but state it.** ORM clients (Prisma, SQLAlchemy
  autogen), protobuf/gRPC stubs, OpenAPI-generated clients, and migrations belong in `exclude`.
  List the excluded globs and the reason in the plan output — an unstated exclusion is the same
  trick as an unfixed denominator, just implemented differently.
- **Monorepos:** measure and threshold each workspace/module independently, then optionally report
  a rollup. A single repo-wide number hides which part is actually weak — exactly what happened in
  the motivating case (one workspace at 1.75%, sitting next to two others above 48%, invisible
  behind a blended average).
