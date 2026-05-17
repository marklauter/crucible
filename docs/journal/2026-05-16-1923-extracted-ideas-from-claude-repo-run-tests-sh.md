# Extracted ideas from claude-repo run-tests.sh

Date: 2026-05-16 19:23
Tags: crucible,bash,test-framework,extraction
Catalogued what to keep, generalize, and add from D:\claude\claude\plugins\skills\tests\run-tests.sh.

## Source

`D:\claude\claude\plugins\skills\tests\run-tests.sh` — ~210 lines, plugin-scoped.

## Kept as-is

- File convention `*_test.sh`; function convention `test_*`
- Optional `setup` / `teardown` per file
- Per-test subshell + `cd "$(mktemp -d)"`
- `set -e` inside the test → assertions are just functions that `return 1`
- Source the file into the runner so `declare -F` can list tests; `unset -f` between files
- Color when tty + `NO_COLOR` opt-out
- Assertion shape: `assert_equal expected actual [msg]`, all printf to stderr on fail

## Generalized

- `PLUGIN_ROOT` → `PROJECT_ROOT` (git toplevel, else `$PWD`)
- Discovery default: `$PWD` walk, not a hardcoded plugin path

## Added (innovation, not in original)

- `run <cmd>` populating `$status $stdout $stderr $output $lines` — stdout and stderr **separated by default**
- Run-aware assertions (`assert_stdout_*`, `assert_stderr_*`, `assert_status`, `assert_success`, `assert_failure`, `assert_line`)
- Auto-dump of last capture on run-aware failure — the marquee UX
- `skip [reason]` / `fail [msg]` flow control
- `--filter <regex>`

## Rejected (deliberate)

- Bats-style `@test "name"` DSL (preprocessor cost)
- TAP / JUnit output, parallelism, `setup_file`/`teardown_file` — defer to real demand
