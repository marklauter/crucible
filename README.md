[![tests](https://github.com/marklauter/crucible/actions/workflows/tests.yml/badge.svg)](https://github.com/marklauter/crucible/actions/workflows/tests.yml)
[![bash](https://img.shields.io/badge/bash-4%2B-blue?logo=gnubash)](https://www.gnu.org/software/bash/)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

![MSL Armory](https://raw.githubusercontent.com/marklauter/crucible/main/images/msl.armory.small.png "MSL Armory")

# crucible

*Another weapon from the MSL Armory.*

A tiny bash test runner, packaged as a Claude Code plugin. One file, no dependencies beyond bash 4+, drops into any repo.

```bash
bash plugins/crucible/crucible.sh                  # discover *_test.sh under $PWD
bash plugins/crucible/crucible.sh tests/           # discover under a specific dir
bash plugins/crucible/crucible.sh tests/foo_test.sh
bash plugins/crucible/crucible.sh --filter rename  # run only tests whose name matches regex
bash plugins/crucible/crucible.sh --list           # enumerate discovered tests without running
bash plugins/crucible/crucible.sh -v tests/        # on pass, also dump captured stdout/stderr
bash plugins/crucible/crucible.sh --ascii          # use ok/FAIL/skip markers instead of ✓/✗/↷
```

Or install it as a plugin in Claude Code so the `writing-bash-tests` skill teaches the conventions:

```text
/plugin marketplace add <path-or-github-repo>
/plugin install crucible@crucible
```

A minimal test file:

```bash
# tests/calculator_test.sh
CALC="$PROJECT_ROOT/bin/calculator.sh"

test_addition() {
    local out
    out=$("$CALC" 2 + 3)
    assert_equal 5 "$out"
}

test_divide_by_zero_errors() {
    run "$CALC" 1 / 0
    assert_failure
    assert_stderr_contains "divide by zero"
}
```

## Documentation

The full docs live in the **[crucible wiki](https://github.com/marklauter/crucible/wiki)**:

- [Installation](https://github.com/marklauter/crucible/wiki/Installation) — Linux, macOS, Windows.
- [Your first test](https://github.com/marklauter/crucible/wiki/Your-first-test) — walkthrough for new adopters.
- [Reference](https://github.com/marklauter/crucible/wiki/Test-file-conventions) — conventions, assertions, the `run` helper, flow control, flags, environment, exit codes, gotchas.
- [Recipes](https://github.com/marklauter/crucible/wiki/Recipes) — patterns by scenario: testing a CLI, asserting on stderr, skipping on missing deps, testing non-zero exits, fixtures.
- [Out of scope](https://github.com/marklauter/crucible/wiki/Out-of-scope) — what crucible deliberately leaves out, and why.

## Why another one

[Bats](https://github.com/bats-core/bats-core) is the obvious choice. It works. Two things push some people elsewhere:

- Install step — bats has to be installed (`apt`, `brew`, `npm install -g bats`, or a vendored submodule). Crucible is one script — `curl` it in.
- DSL — bats tests use `@test "name" { ... }`, which is parsed and rewritten before execution. Crucible tests are real bash functions — `bash -n` lints them, `set -x` debugs them, and `grep` finds them like any other shell code.

Crucible keeps the parts of bats that earn their keep — file/function naming, per-test subshell isolation, lightweight assertions, first-class stdout/stderr capture via `run` — and drops the DSL.
