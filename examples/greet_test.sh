#!/usr/bin/env bash
# Tests for examples/greet.sh — demonstrates basic assertions and `run` capture.

GREET="$PROJECT_ROOT/examples/greet.sh"

# ---- basic assertions (no `run`) ----

test_greet_writes_hello_world() {
    local out
    out=$("$GREET" world)
    assert_equal "hello, world" "$out"
}

test_greet_file_is_executable() {
    assert_file_exists "$GREET"
}

# ---- run capture: status + stdout + stderr separated by default ----

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
