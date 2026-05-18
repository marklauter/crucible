---
name: writing-bash-tests
description: Use when writing, running, or reviewing bash tests with crucible — files ending in `_test.sh` containing `test_*` functions, invoked via `crucible.sh`. Covers the conventions (file/function naming, setup/teardown, per-test isolation), the assertion library, the `run` helper for stdout/stderr/status capture, and the `skip` / `fail` flow control verbs.
---

# Writing Bash Tests with Crucible

Crucible tests are plain bash functions in `*_test.sh` files. Discovery is by naming convention; isolation is per-test; stdout, stderr, and exit status are first-class through the `run` helper. The runner is a single bash file (`crucible.sh`); this skill teaches the conventions for authoring against it.

## Philosophy

The principles that shaped crucible's design. Hold these in mind when writing or reviewing tests.

### Real bash, not a DSL

A crucible test is a bash function. `bash -n` lints it, `set -x` traces it, `grep -r 'test_addition'` finds it. No `@test` macros, no parse-and-rewrite, no language inside the language. Anything you can do in bash, you can do in a test.

### Test the artifact through its real interface

A crucible test invokes the script or binary under test as a subprocess — through command substitution for trivial cases, through `run` when status or stderr matters. The test exercises the real surface a caller would see. Unit-style mocking belongs in a typed language; bash earns its keep at the boundary, and the test follows.

### Per-test isolation

Each `test_*` runs in its own subshell with a fresh tmpdir as cwd. Variables set in one test are invisible to the next. Files written in one test vanish before the next starts. `setup()` and `teardown()` run inside the same subshell as the test; a failure in either fails the test.

### Streams are first-class

The triple — `$status`, `$stdout`, `$stderr` — is the contract a CLI exposes. Crucible exposes the same triple to the test. After `run cmd args...`, stream-specific assertions check the right channel: `assert_stdout_contains` for normal output, `assert_stderr_match` for diagnostics, `assert_status 2` for the exit code. The common bug — right message on the wrong stream, or right exit code with the wrong message — surfaces because the assertions distinguish them.

### Discovery is the registration

File ends in `_test.sh`, function starts with `test_`, and the runner finds it. No `describe`, no `it`, no manifest. The naming is the registration, the registration is the contract, and the contract is grep-able.

### Fail loud at parse time

A test file with a syntax error fails the run; it does not produce "0 passed, exit 0." A `bash -n` precheck runs before the file is sourced, and a syntax error is reported as a failure for that file. The CI signal is honest.

### Captures dump on failure

When a `run`-aware assertion fails, the runner dumps `$status`, `$stdout`, and `$stderr` to stderr automatically. Tests stay free of diagnostic `echo` calls — the dump is the investigation.

### Explicit flow control

`skip` removes a test from the count with a recorded reason; `fail` ends a test with a labeled failure. Both are explicit verbs — the test never improvises around `return` codes to express "should not run today" or "impossible state reached."

### No global `set -u`

The runner does not enable `set -u` globally — test files inherit a clean environment and are not poisoned by upstream strictness. A test that wants strict unset-variable checks adds `set -u` in its own `setup()`.

## Guidance

Concrete patterns for writing tests against crucible. Each subsection mirrors a Philosophy heading.

### Real bash, not a DSL

- A test is a bash function named `test_<something>`. The body is normal bash — `if`, `for`, `case`, command substitution, pipelines, variable expansion.
- File names end in `_test.sh`. The runner discovers them recursively under each argument path; with no argument, it discovers under `$PWD`.
- One file holds one logical group of tests against one script or behavior. Multiple files cohabit a directory freely.
- `bash -n path/to/foo_test.sh` parses without running — the same check the runner does before sourcing.

### Test the artifact through its real interface

- `$PROJECT_ROOT` gives the absolute path to the repo root (git toplevel, or `$PWD` outside a repo). Use it for paths to scripts under test:

  ```bash
  GREET="$PROJECT_ROOT/examples/greet.sh"
  ```

- Trivial success-path checks use `$(...)` command substitution:

  ```bash
  test_greet_writes_hello_world() {
      local out
      out=$("$GREET" world)
      assert_equal "hello, world" "$out"
  }
  ```

- Any test that cares about status or stderr uses `run`:

  ```bash
  test_greet_missing_name_writes_usage_to_stderr() {
      run "$GREET"
      assert_status 2
      assert_stdout_empty
      assert_stderr_contains "usage:"
  }
  ```

- `run cmd args...` does not fail the test on a non-zero exit — that's the point. The test then asserts on `$status` explicitly.

### Per-test isolation

- Each test starts at `cwd=$(mktemp -d)`. Write fixtures into `$PWD` freely; the runner clears the tmpdir after the test.
- `setup()` runs before each test in the file; `teardown()` runs after. Both run inside the same subshell as the test, so variables they set are visible to the test.
- `setup()` and `teardown()` are file-scoped — defined once per `_test.sh` file. The runner unsets them between files so a previous file's hooks do not leak.
- Keep writes inside `$PWD`. The per-test cleanup only handles the tmpdir; an absolute path outside it persists across tests and the test author owns the cleanup.

### Streams are first-class

After `run cmd args...`, these are populated:

- `$status` — exit code as a string.
- `$stdout` — captured stdout, no trailing newline.
- `$stderr` — captured stderr, no trailing newline.
- `$output` — `$stdout` plus `$stderr`, in that order, separated by a newline only when both are non-empty.
- `$lines` — `$stdout` split on newlines into an indexed array; empty when `$stdout` is empty.

Assertion families:

- Status: `assert_status <n>`, `assert_success`, `assert_failure`.
- Stdout: `assert_stdout_eq`, `assert_stdout_contains`, `assert_stdout_match`, `assert_stdout_empty`.
- Stderr: `assert_stderr_eq`, `assert_stderr_contains`, `assert_stderr_match`, `assert_stderr_empty`.
- Combined: `assert_output_eq`, `assert_output_contains`, `assert_output_match`, `assert_output_empty`.
- Per-line: `assert_line <n> <expected>` — checks `${lines[n]}`.

Prefer stream-specific assertions over `$output`. `assert_stdout_contains` and `assert_stderr_match` express intent; `assert_output_contains` lets a misrouted message pass silently. Reach for `assert_output_*` only when the test genuinely should not care which stream the content landed on.

Run-aware assertions require a preceding `run` in the same test. Calling them before `run` fails with a clear message naming the assertion.

### Discovery is the registration

- Function names: prefix `test_`, then a snake_case description of the behavior under test. `test_returns_zero_on_empty_input` reads as a sentence; `test1` or `testFoo` does not.
- File names: the script being tested plus `_test.sh`. `greet.sh` is tested by `greet_test.sh`.
- A function whose name does not start with `test_` is invisible to the runner — useful for test helpers, broken for would-be tests. When a helper starts to look like a test, rename or move it.

### Fail loud at parse time

- A test file that does not parse fails the run. The failure message names the file and the parser error; the rest of the suite continues.
- Keep test files declaration-only at the top level — source variables, define functions, return. A top-level `exit N` would kill the runner mid-suite; the runner guards against it, but the guard is not a license.

### Captures dump on failure

- A failing `run`-aware assertion dumps `$status`, `$stdout`, and `$stderr` automatically. Leave the diagnostic `echo` calls out — the dump already happened.
- `assert_equal` on multi-line values dumps both operands in labeled blocks instead of the single-line `%q` form, which would be unreadable.
- `--verbose` (`-v`) dumps captures on pass as well — useful when investigating "is this test actually exercising what I think it is?"

### Explicit flow control

- `skip [<reason>]` marks the current test skipped and stops it. The reason appears in the runner output. Use for environment-conditional tests:

  ```bash
  test_uses_docker() {
      command -v docker >/dev/null || skip "docker not installed"
      run docker run --rm hello-world
      assert_success
  }
  ```

- `fail [<msg>]` explicitly fails the current test with a labeled message. Useful when a precondition the assertions cannot express has been violated.
- `set -e` is active inside the test, so a failed assertion (return non-zero) aborts the test immediately. Cleanup that must run on failure goes in `teardown()`.

### No global `set -u`

- A test that wants strict unset-variable checks enables `set -u` in its own `setup()` — scoped to that file, not imposed on others.
- The runner uses `${var:-default}` expansions throughout so test files can rely on the same hygiene without inheriting it implicitly.

### Running the suite

```bash
bash plugins/crucible/crucible.sh                  # discover *_test.sh under $PWD
bash plugins/crucible/crucible.sh tests/           # discover under a directory
bash plugins/crucible/crucible.sh tests/foo_test.sh  # run one file
bash plugins/crucible/crucible.sh --filter rename  # function names matching the regex
bash plugins/crucible/crucible.sh --list           # enumerate without running
bash plugins/crucible/crucible.sh -v tests/        # dump captures on pass too
bash plugins/crucible/crucible.sh --ascii          # ok/FAIL/skip markers instead of ✓/✗/↷
```

Environment:

- `NO_COLOR=1` disables ANSI colors.
- `CRUCIBLE_ASCII=1` is equivalent to `--ascii`.
- `PROJECT_ROOT` is exported automatically; override it before invoking when the git toplevel default is wrong.

Exit codes: `0` on all-pass-or-skip, non-zero on any failure or discovery error. CI relies on this directly.

## Validation

### The writing loop

1. Write the test. Save the file with the `_test.sh` suffix; name the function with the `test_` prefix.
2. `bash -n path/to/the_test.sh` — confirm the file parses.
3. `bash plugins/crucible/crucible.sh --list path/to/the_test.sh` — confirm the runner sees the function.
4. `bash plugins/crucible/crucible.sh path/to/the_test.sh` — run it. Iterate to green.
5. `shellcheck path/to/the_test.sh` — confirm clean. Suppress `SC2154` for `$stdout`/`$stderr`/`$status` (populated by `run`), `SC2016` for intentionally-literal single-quoted bodies in fixture generators, and `SC2103` for `cd` inside a test subshell.

### Self-review heuristics

- Read the test name aloud. Does it state the behavior under test? `test_returns_404_when_user_missing` reads as a sentence; `test_user_missing` does not.
- Does the test invoke the artifact through its real interface? A test that sources a function and asserts on it directly is a unit test of a helper, not an integration test of the script — move it or rewrite it to invoke the script as a subprocess.
- Was `run` needed? When the test cares about status or stderr, `run` is needed. When it only cares about success-path stdout, command substitution is fine.
- Are the assertions stream-specific? `assert_output_contains` is a code smell unless the test genuinely should not care which stream the content landed on.
- Could `setup()` collapse repetition? When the same three lines lead every test in a file, they belong in `setup()`.

### Reference shape

The canonical shape: a short header comment naming the script under test, an absolute path to that script at the top, then sections alternating basic assertions and `run`-based assertions. New test files start from this shape and earn their deviations.

A complete example — tests for a hypothetical `greet.sh` at `$PROJECT_ROOT/bin/greet.sh`:

```bash
#!/usr/bin/env bash
# Tests for bin/greet.sh — demonstrates basic assertions and `run` capture.

GREET="$PROJECT_ROOT/bin/greet.sh"

# ---- basic assertions (no `run`) ----

test_greet_writes_hello_world() {
    local out
    out=$("$GREET" world)
    assert_equal "hello, world" "$out"
}

test_greet_file_is_executable() {
    assert_file_exists "$GREET"
}

# ---- run capture: status + stdout + stderr separated ----

test_greet_success() {
    run "$GREET" world
    assert_success
    assert_stdout_eq "hello, world"
    assert_stderr_empty
}

test_greet_missing_name_writes_usage_to_stderr() {
    run "$GREET"
    assert_status 2
    assert_stdout_empty
    assert_stderr_contains "usage:"
}

test_greet_shout_uppercases() {
    run "$GREET" --shout claude
    assert_success
    assert_stdout_eq "HELLO, CLAUDE!"
}

# ---- per-line indexing ----

test_lines_array_populated() {
    run bash -c 'printf "a\nb\nc\n"'
    assert_success
    assert_line 0 "a"
    assert_line 1 "b"
    assert_line 2 "c"
}
```
