## Build Status
[![tests](https://github.com/marklauter/crucible/actions/workflows/tests.yml/badge.svg)](https://github.com/marklauter/crucible/actions/workflows/tests.yml)
[![bash](https://img.shields.io/badge/bash-4%2B-blue?logo=gnubash)](https://www.gnu.org/software/bash/)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

![MSL Armory](https://raw.githubusercontent.com/marklauter/crucible/main/images/msl.armory.small.png "MSL Armory")

# crucible

*Another weapon in the MSL Armory.*

A tiny bash test runner. One file, no dependencies beyond bash 4+, drops into any repo.

```
bash crucible.sh                  # discover *_test.sh under $PWD
bash crucible.sh tests/           # discover under a specific dir
bash crucible.sh tests/foo_test.sh
bash crucible.sh --filter rename  # run only tests whose name matches regex
bash crucible.sh --list           # enumerate discovered tests without running
bash crucible.sh -v tests/        # on pass, also dump captured stdout/stderr
bash crucible.sh --ascii          # use ok/FAIL/skip markers instead of ✓/✗/↷
```

For a one-page cheat sheet, see [docs/notes/using-crucible.md](docs/notes/using-crucible.md).

## Why another one

[Bats](https://github.com/bats-core/bats-core) is the obvious choice. It works. But it ships its own DSL preprocessor (`@test "name" { ... }` is not real bash, it's parsed and rewritten before execution), and its `run` helper merges stdout+stderr by default. Crucible keeps the parts of bats that earn their keep — file/function naming conventions, per-test isolation, lightweight assertions — and drops the DSL. Tests are plain bash functions; you can read them with `bash -n`, debug them with `set -x`, and grep them like any other shell code.

The one place crucible spends complexity is **stdout/stderr capture**, which it treats as first-class.

## Conventions

- Test files end in `_test.sh`.
- Test functions start with `test_`. They run in alphabetical order within a file (this is `declare -F` behavior, not configurable).
- Optional `setup()` runs before each test; `teardown()` runs after.
- Each test runs in a subshell with `cwd` set to a fresh `mktemp -d`.
- `set -e` is active inside the test, so a failed assertion (which returns 1) aborts the test immediately.
- `PROJECT_ROOT` is exported to every test: it's `git rev-parse --show-toplevel` if available, else `$PWD` when the runner started. Use it for absolute paths to scripts under test.
- **Test files must be inert at the top level.** Only function definitions and variable assignments belong outside functions. Top-level commands run during `source` in the runner shell; a stray `exit N` will terminate the entire runner (`bash -n` syntax checking catches malformed files before sourcing, but not runtime side effects of top-level code).

## A minimal test file

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

## Assertions

All assertions return non-zero on failure, which `set -e` translates into test failure.

**Argument order:** equality assertions (`assert_equal`, `assert_not_equal`) put `expected` first and `actual` second, matching xUnit. Matcher-style assertions (`assert_contains`, `assert_not_contains`, `assert_match`) put the value-under-test first and the matcher second — which is the order you'd read aloud ("assert this haystack contains needle", "assert this string matches regex").

| Assertion | Notes |
|---|---|
| `assert_equal <expected> <actual> [msg]` | string equality |
| `assert_not_equal <unexpected> <actual> [msg]` | |
| `assert_contains <haystack> <needle> [msg]` | substring |
| `assert_not_contains <haystack> <needle> [msg]` | |
| `assert_match <string> <regex> [msg]` | bash `=~` |
| `assert_empty <string> [msg]` | |
| `assert_not_empty <string> [msg]` | |
| `assert_true <cmd...>` | command must exit 0 |
| `assert_false <cmd...>` | command must exit non-zero |
| `assert_file_exists <path> [msg]` | |
| `assert_file_not_exists <path> [msg]` | |

## Capturing stdout, stderr, and exit code

`run <cmd> [args...]` invokes the command without failing the test on a non-zero exit. It populates:

| Variable | Contents |
|---|---|
| `$status` | exit code |
| `$stdout` | captured stdout (trailing newlines stripped) |
| `$stderr` | captured stderr (trailing newlines stripped) |
| `$output` | `$stdout` then `$stderr`, joined by a newline when both are non-empty (stream order is fixed; real-time interleaving is lost) |
| `$lines` | zero-indexed bash array of stdout lines |

Run-aware assertions:

| Assertion | |
|---|---|
| `assert_status <expected>` | |
| `assert_success` | `$status == 0` |
| `assert_failure` | `$status != 0` |
| `assert_stdout_eq <expected>` | |
| `assert_stdout_contains <needle>` | |
| `assert_stdout_match <regex>` | |
| `assert_stdout_empty` | |
| `assert_stderr_eq <expected>` | |
| `assert_stderr_contains <needle>` | |
| `assert_stderr_match <regex>` | |
| `assert_stderr_empty` | |
| `assert_output_eq <expected>` | combined stream (see `$output` above) |
| `assert_output_contains <needle>` | |
| `assert_output_match <regex>` | |
| `assert_output_empty` | |
| `assert_line <n> <expected>` | indexed line from `$lines` (negative indices count from the end; out-of-range yields `""`) |

**When a run-aware assertion fails, the captured status, stdout, and stderr are printed automatically.** No need to add diagnostic `echo`s. Example output for a failing test:

```
  FAIL: stdout != expected
    expected:
      hello, world
    status: 0
    stdout:
      goodbye, world
    stderr: (empty)
  ✗ test_greeting
```

## Gotchas

### With `run`

`run` is a regular bash function, which constrains what it can execute:

- **No pipelines or shell keywords.** `run echo foo | grep f` parses as `(run echo foo) | grep f` — only `echo foo` is captured. `run if true; then ...` is a syntax error. Wrap shell syntax in `bash -c '...'`:
  ```bash
  run bash -c 'echo foo | grep f'
  ```
- **`run exit N` kills the test.** `exit` is a builtin and runs in the current (test subshell) shell, terminating the entire test. Always: `run bash -c "exit $N"`.
- **Aliases do not expand** (bash disables alias expansion in non-interactive shells).
- **NUL bytes in captured output are dropped.** Bash command substitution (`$(cat …)`) discards NUL bytes. If you're testing a tool that emits binary data, capture to a file and check the file directly.
- **Nesting `run` is allowed but rarely useful.** If `run` invokes a shell function that itself calls `run`, the inner call's captures are written to the same globals; once the outer `run` returns, those globals reflect the *outer* command (the implementation overwrites them at the end). The inner captures are only visible inside the function the outer `run` invoked.

### With tests

- **Exit code 77 is reserved for `skip`.** If a script you invoke with `run` happens to `exit 77` for its own reasons, that exit code is captured in `$status` like any other — no conflict. But `exit 77` from a test body (or a helper directly called from a test) will be interpreted by the runner as `skip` because tests run in subshells that propagate their exit code.
- **`test_*` is the discovery prefix.** Any function whose name starts with `test_` will be executed as a test — including helpers like `test_make_fixture`. Name helpers without the prefix (e.g., `make_fixture`, `_make_fixture`) to keep them out of the run list.
- **Background processes started inside a test are not killed** when the test ends. The test subshell exits, but `sleep 100 &` (or similar) gets reparented and keeps running. If you start background work, clean it up explicitly in `teardown`.
- **Filenames with newlines are not supported** by discovery — `find` output is read line-by-line.

## Flow control

- `skip [reason]` — marks the current test as skipped (yellow `↷` in output) and stops it. Use to gate tests on optional dependencies: `command -v docker >/dev/null || skip "needs docker"`.
- `fail [msg]` — explicit failure with optional message. Equivalent to `return 1` but clearer.

## Discovery

- With no arguments, walks `$PWD` for `*_test.sh`.
- With arguments, each must be an existing file or directory. Missing paths exit with code 2.

## Flags

| Flag | Effect |
|---|---|
| `--filter <regex>` | run only tests whose function name matches. Invalid regex or zero matches → exit 2. |
| `--list` | enumerate discovered tests without running them. Honors `--filter`. |
| `-v`, `--verbose` | on pass, also dump captured `$status` / `$stdout` / `$stderr` if `run` was called. |
| `--ascii` | use ASCII markers (`ok` / `FAIL` / `skip`) instead of `✓` / `✗` / `↷`. Same as `CRUCIBLE_ASCII=1`. |
| `-h`, `--help` | show built-in help. |

## Environment

| Variable | Purpose |
|---|---|
| `PROJECT_ROOT` | exported to tests; defaults to git toplevel, else `$PWD`. Override by setting it before invocation. |
| `NO_COLOR=1` | disables ANSI colors (also disabled when stdout is not a tty). |
| `CRUCIBLE_ASCII=1` | uses ASCII markers (`ok` / `FAIL` / `skip`) instead of `✓` / `✗` / `↷`. Same as the `--ascii` flag. Useful on consoles without UTF-8 support. |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | all selected tests passed (or no tests were found without `--filter`) |
| 1 | one or more tests failed (including file-level failures like syntax errors) |
| 2 | misuse: unknown flag, missing path, invalid `--filter` regex, or `--filter` matched zero tests |

## What crucible doesn't do (yet)

- No TAP / JUnit XML output. Add if a CI demands it.
- No parallel execution. Tests are isolated by tmpdir + subshell, so adding parallelism is feasible — it just costs complexity that nothing yet needs.
- No `setup_file` / `teardown_file`. Easy to add when a real test wants them.
