# Bootstrapped crucible from the claude-plugin test runner

Date: 2026-05-16 19:22
Tags: crucible,bash,test-framework,bootstrap
Generalized the plugin-scoped run-tests.sh into a standalone single-file runner with run/stdout/stderr capture as a first-class feature.

## Context

The user pointed at `D:\claude\claude\plugins\skills\tests\run-tests.sh` — a ~210-line bash test runner scoped to one plugin. Conventions worth keeping: `*_test.sh` discovery, `test_*` functions, optional `setup`/`teardown`, per-test subshell in `mktemp -d`, `set -e` inside tests so assertions can just `return 1`. The plan: extract the ideas, reimagine as a reusable standalone runner, deliberately not copy bats, and make stdout/stderr capture first-class because that was the named gap.

The crucible repo at `D:\crucible\crucible\` was empty (just `.git`). Greenfield — no migration, no existing tests to keep green.

## Attempted

Shipped both halves in one cut rather than the user's suggested "phase 1 working, phase 2 capture": with no existing users the staged delivery added churn without buying anything. Built:

- `crucible.sh` — single file, ~500 lines, drops into any repo
- `examples/greet.sh` + `examples/greet_test.sh` — exemplar
- `tests/self_test.sh` — dogfooded
- `README.md` — conventions, full assertion catalogue, comparison to bats

Differentiator: `run <cmd>` populates `$status $stdout $stderr $output $lines`, with stdout and stderr **separated by default** (bats merges by default — real gap). Run-aware assertions (`assert_stdout_*`, `assert_stderr_*`, `assert_status`) auto-dump the capture on failure, so users never write diagnostic `echo`s.

## Outcome

First green run: examples 6/6, self-tests 15/16. One real failure: unknown-path arg was swallowed by `_crucible_discover` returning non-zero into a `while read` loop that ignored the return code, producing "no tests found" with exit 0. Added an up-front existence check in `main`. Both suites green: 22/22.

The auto-dump-on-failure UX (`status:` / `stdout:` / `stderr:` indented under the `FAIL:` line) made the "first-class capture" promise feel concrete in the demo.

## Decision

Shipped as one phase. Documented in README what we deliberately did NOT build (TAP/JUnit, parallelism, bats-style `@test "name"` DSL, `setup_file`/`teardown_file`) so the simplicity ceiling is visible.

Saved a project memory at `C:/Users/Owner/.claude/projects/D--crucible/memory/project_crucible.md` covering origin, the capture-separation invariant, and what to defer.

## Next

User asked for a "short independent opus review loop" — three iterations of code review + triage + fix.

Candidate notes: capture-separation-by-default rationale; the `set -e` + `return 1` assertion convention.
