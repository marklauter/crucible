# Using crucible

Tags: help,crucible
Cheat-sheet: how to invoke the runner, write tests, capture stdout/stderr, and skip or fail.

## Invoke

```
bash crucible.sh                  # discover *_test.sh under $PWD
bash crucible.sh tests/           # under a directory
bash crucible.sh tests/foo_test.sh
bash crucible.sh --filter rename  # run tests matching a regex
bash crucible.sh --list           # enumerate without running
bash crucible.sh -v tests/        # on pass, also dump captured stdout/stderr
bash crucible.sh --ascii          # ASCII markers instead of ✓/✗/↷
```

## Test-file conventions

- Filename ends in `_test.sh`.
- Test functions start with `test_`; they run in **alphabetical order** within a file.
- Optional `setup()` runs before each test; `teardown()` runs after.
- Each test runs in a subshell, `cwd` is a fresh `mktemp -d`, `set -e` is on.
- `PROJECT_ROOT` is exported (git toplevel, else `$PWD`); use it for absolute paths.
- Top level of a test file must be inert (only function/variable definitions).

## Assertions

Equality: `assert_equal expected actual [msg]`, `assert_not_equal`.
Strings: `assert_contains haystack needle`, `assert_not_contains`, `assert_match string regex`, `assert_empty`, `assert_not_empty`.
Commands: `assert_true cmd...`, `assert_false cmd...`.
Files: `assert_file_exists path`, `assert_file_not_exists`.

## Capturing stdout/stderr

```bash
run mycmd arg1 arg2
```

Populates `$status`, `$stdout`, `$stderr`, `$output` (stdout then stderr), `$lines` (zero-indexed array).

Run-aware assertions: `assert_status N`, `assert_success`, `assert_failure`, plus the `_eq` / `_contains` / `_match` / `_empty` family for each of `stdout`, `stderr`, `output`. Also `assert_line n expected`.

Failed run-aware assertions auto-dump the latest `status`/`stdout`/`stderr` — no diagnostic echoes needed.

## Flow control

- `skip [reason]` — mark the current test skipped (`↷` in output) and stop it.
- `fail [msg]` — explicit failure; equivalent to `return 1` with a labeled message.

## Common gotchas

- `run` is a function: no pipelines, shell keywords, or builtins like `exit`. Wrap in `bash -c '...'`.
- `exit 77` is reserved for `skip` — outside a `run` it will be interpreted as a skip.
- Background processes started inside a test are not auto-killed; clean up in `teardown`.
- Helpers must not be named `test_*` (they'd run as tests) — use `_helper` or unprefixed names.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | all selected tests passed (or none ran without `--filter`) |
| 1 | one or more tests failed |
| 2 | misuse: unknown flag, missing path, invalid filter regex, filter matched zero tests |

See [Using crucible](using-crucible.md) (this note) or `README.md` for fuller treatment.
