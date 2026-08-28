#!/usr/bin/env bash
# detect.sh — read-only stack/coverage-tooling detection for the coverage-plan skill.
# Never runs tests or coverage itself; only inspects config files and directory structure.
# Usage: detect.sh [root_dir]  (defaults to current directory)

# Deliberately not using `set -e`: this is a best-effort read-only report where any single
# grep/find returning "no matches" (exit 1) is a normal, expected outcome, not a failure.
set -u

ROOT="${1:-.}"
cd "$ROOT"

echo "== coverage-plan detect: $(pwd) =="
echo

find_workspaces() {
  # Look for common monorepo markers; fall back to repo root as the single workspace.
  local found=0
  if [ -f "pnpm-workspace.yaml" ] || [ -f "turbo.json" ] || \
     grep -q '"workspaces"' package.json 2>/dev/null; then
    echo "-- Monorepo markers found (pnpm-workspace.yaml / turbo.json / package.json workspaces) --"
    found=1
  fi
  if [ -f "lerna.json" ]; then
    echo "-- lerna.json found --"
    found=1
  fi
  if [ "$found" -eq 0 ]; then
    echo "-- No monorepo markers; treating as a single workspace --"
  fi
  echo
}

detect_node() {
  local pkgs
  pkgs=$(find . -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null || true)
  [ -z "$pkgs" ] && return
  echo "## Node / TypeScript / JavaScript"
  while IFS= read -r pkg; do
    local dir; dir=$(dirname "$pkg")
    echo "--- $pkg ---"
    if grep -q '"vitest"' "$pkg" 2>/dev/null; then
      echo "  runner: vitest"
      # Prefer a standalone vitest.config.* over vite.config.* (a project may have both; the
      # standalone file, when present, is the one actually driving `vitest run`).
      local cfg
      cfg=$(find "$dir" -maxdepth 1 -name "vitest.config.*" 2>/dev/null | head -1)
      if [ -z "$cfg" ]; then
        cfg=$(find "$dir" -maxdepth 1 -name "vite.config.*" 2>/dev/null | head -1)
      fi
      [ -n "$cfg" ] && echo "  config: $cfg"
      if [ -n "$cfg" ] && grep -q "coverage" "$cfg" 2>/dev/null; then
        echo "  coverage block: present in $cfg"
        grep -q "include" "$cfg" 2>/dev/null && echo "    - has coverage.include (good — check it covers all of src/)" \
          || echo "    - NO coverage.include found — likely under-measuring (see ECOSYSTEMS.md: Vitest trap)"
        # Match an actual `thresholds:` key, not the word appearing in a comment
        # (e.g. "// Report only — no thresholds yet" is not a configured threshold).
        if grep -vE '^\s*//|^\s*\*' "$cfg" 2>/dev/null | grep -qE 'thresholds\s*:'; then
          echo "    - has thresholds configured"
        else
          echo "    - NO thresholds — coverage can regress silently"
        fi
      else
        echo "  coverage block: NOT FOUND — coverage likely never configured for this workspace"
      fi
      grep -q '@vitest/coverage-v8\|@vitest/coverage-istanbul' "$pkg" 2>/dev/null && echo "  coverage provider dep: present" \
        || echo "  coverage provider dep: MISSING (@vitest/coverage-v8 or -istanbul not installed)"
    elif grep -q '"jest"' "$pkg" 2>/dev/null; then
      echo "  runner: jest"
      local cfg
      cfg=$(find "$dir" -maxdepth 1 -name "jest.config.*" 2>/dev/null | head -1)
      [ -n "$cfg" ] && echo "  config: $cfg"
      grep -q "collectCoverageFrom" "$pkg" "$cfg" 2>/dev/null && echo "    - has collectCoverageFrom" \
        || echo "    - NO collectCoverageFrom — likely under-measuring (see ECOSYSTEMS.md: Jest trap)"
    else
      echo "  runner: not detected (check for mocha/ava/tap or a custom setup)"
    fi
    echo
  done <<< "$pkgs"
}

detect_python() {
  local found=""
  found=$(find . -maxdepth 4 \( -name "pyproject.toml" -o -name "pytest.ini" -o -name "setup.cfg" -o -name ".coveragerc" \) -not -path "*/.venv/*" -not -path "*/venv/*" 2>/dev/null || true)
  [ -z "$found" ] && return
  echo "## Python"
  while IFS= read -r f; do
    echo "--- $f ---"
    grep -q "pytest-cov\|\[tool.coverage" "$f" 2>/dev/null && echo "  coverage tooling referenced here" || true
    grep -q "branch\s*=\s*true\|branch = True" "$f" 2>/dev/null && echo "    - branch coverage: enabled" \
      || echo "    - branch coverage: not explicitly enabled (off by default — see ECOSYSTEMS.md)"
    grep -q "fail_under" "$f" 2>/dev/null && echo "    - fail_under threshold: present" \
      || echo "    - fail_under threshold: NOT set"
  done <<< "$found"
  echo
}

detect_go() {
  [ -f "go.mod" ] || find . -maxdepth 3 -name "go.mod" -not -path "*/vendor/*" 2>/dev/null | grep -q . || return
  echo "## Go"
  find . -maxdepth 3 -name "go.mod" -not -path "*/vendor/*" 2>/dev/null | while IFS= read -r f; do
    echo "  module: $f"
  done
  echo "  reminder: use -coverpkg=./... or untested packages are silently absent (see ECOSYSTEMS.md)"
  echo
}

detect_jvm() {
  local found=""
  found=$(find . -maxdepth 3 \( -name "pom.xml" -o -name "build.gradle" -o -name "build.gradle.kts" \) 2>/dev/null || true)
  [ -z "$found" ] && return
  echo "## Java / Kotlin"
  while IFS= read -r f; do
    echo "--- $f ---"
    grep -qi "jacoco" "$f" 2>/dev/null && echo "  jacoco: referenced" || echo "  jacoco: NOT referenced — no coverage tooling detected"
  done <<< "$found"
  echo
}

detect_ruby() {
  [ -f "Gemfile" ] || return
  echo "## Ruby"
  grep -qi "simplecov" Gemfile Gemfile.lock 2>/dev/null && echo "  simplecov: referenced" || echo "  simplecov: NOT referenced"
  find . -maxdepth 2 -name ".simplecov" 2>/dev/null | grep -q . && echo "  .simplecov config: present" || echo "  .simplecov config: NOT found (may be inline in spec_helper.rb)"
  echo
}

detect_dotnet() {
  find . -maxdepth 3 -name "*.csproj" -o -name "*.sln" 2>/dev/null | grep -q . || return
  echo "## .NET"
  grep -rl "coverlet" --include="*.csproj" . 2>/dev/null | head -5 | while IFS= read -r f; do echo "  coverlet referenced: $f"; done
  echo
}

detect_rust() {
  [ -f "Cargo.toml" ] || return
  echo "## Rust"
  grep -q "\[workspace\]" Cargo.toml 2>/dev/null && echo "  workspace: yes — remember --workspace --all-features" || echo "  single crate"
  echo
}

detect_php() {
  find . -maxdepth 2 \( -name "phpunit.xml" -o -name "phpunit.xml.dist" \) 2>/dev/null | grep -q . || return
  echo "## PHP"
  local cfg
  cfg=$(find . -maxdepth 2 \( -name "phpunit.xml" -o -name "phpunit.xml.dist" \) 2>/dev/null | head -1)
  echo "  config: $cfg"
  grep -q "<source>" "$cfg" 2>/dev/null && echo "    - <source> include block present" \
    || echo "    - NO <source> block — only executed files will be counted (see ECOSYSTEMS.md)"
  echo
}

find_workspaces
detect_node
detect_python
detect_go
detect_jvm
detect_ruby
detect_dotnet
detect_rust
detect_php

echo "== CI coverage wiring =="
if [ -d ".github/workflows" ]; then
  grep -rl "coverage" .github/workflows/*.yml 2>/dev/null | while IFS= read -r f; do echo "  referenced in: $f"; done
  grep -rl "coverage" .github/workflows/*.yml 2>/dev/null | grep -q . || echo "  no workflow file references 'coverage' — likely not run in CI"
else
  echo "  no .github/workflows directory found"
fi
echo
echo "== Done. This is detection only — no tests were run. =="
