[![tests](https://github.com/marklauter/crucible/actions/workflows/tests.yml/badge.svg)](https://github.com/marklauter/crucible/actions/workflows/tests.yml)
[![bash](https://img.shields.io/badge/bash-4%2B-blue?logo=gnubash)](https://www.gnu.org/software/bash/)
[![claude code](https://img.shields.io/badge/Claude%20Code-plugin-d97757?logo=anthropic)](https://docs.claude.com/en/docs/claude-code/plugins)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

![MSL Armory](https://raw.githubusercontent.com/marklauter/crucible/main/images/msl.armory.small.png "MSL Armory")

# crucible

*Another weapon from the MSL Armory*

A tiny bash test runner — one file, no dependencies beyond bash 4+. Use it as a standalone script, or install it as a Claude Code plugin and let the `writing-bash-tests` skill teach the conventions to your agent.

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

## Run it

```bash
bash crucible.sh                  # discover *_test.sh under $PWD
bash crucible.sh tests/           # discover under a specific dir
bash crucible.sh tests/foo_test.sh
bash crucible.sh --filter rename  # run only tests whose name matches regex
bash crucible.sh --list           # enumerate discovered tests without running
bash crucible.sh -v tests/        # on pass, also dump captured stdout/stderr
bash crucible.sh --ascii          # use ok/FAIL/skip markers instead of ✓/✗/↷
```

## Install

As a Claude Code plugin (primary) — installs the runner alongside the skills that teach an agent to author and operate it:

```text
/plugin marketplace add marklauter/crucible
/plugin install crucible@msl.armory.crucible
```

As a standalone script — copy or `curl` `plugins/crucible/crucible.sh` into your repo and invoke it directly:

```bash
curl -O https://raw.githubusercontent.com/marklauter/crucible/main/plugins/crucible/crucible.sh
bash crucible.sh tests/
```

## Documentation

The full docs live in the [crucible wiki](https://github.com/marklauter/crucible/wiki):

- [Installation](https://github.com/marklauter/crucible/wiki/Installation) — Linux, macOS, Windows.
- [Your first test](https://github.com/marklauter/crucible/wiki/Your-first-test) — walkthrough for new adopters.
- [Reference](https://github.com/marklauter/crucible/wiki/Test-file-conventions) — conventions, assertions, the `run` helper, flow control, flags, environment, exit codes, gotchas.
- [Recipes](https://github.com/marklauter/crucible/wiki/Recipes) — patterns by scenario: testing a CLI, asserting on stderr, skipping on missing deps, testing non-zero exits, fixtures.
- [Out of scope](https://github.com/marklauter/crucible/wiki/Out-of-scope) — what crucible deliberately leaves out, and why.

## Why another one

[Bats](https://github.com/bats-core/bats-core) is the obvious choice. It works. Two things push some people elsewhere:

- Install step — bats has to be installed (`apt`, `brew`, `npm install -g bats`, or a vendored submodule). Crucible is one script — `curl` it in, or install the plugin.
- DSL — bats tests use `@test "name" { ... }`, which is parsed and rewritten before execution. Crucible tests are real bash functions — `bash -n` lints them, `set -x` debugs them, and `grep` finds them like any other shell code.

Crucible keeps the parts of bats that earn their keep — file/function naming, per-test subshell isolation, lightweight assertions, first-class stdout/stderr capture via `run` — and drops the DSL.
