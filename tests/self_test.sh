#!/usr/bin/env bash
# Crucible's own tests. These run the runner against tiny synthetic test
# files and assert on the exit code and combined output. This is the most
# direct way to validate the runner itself — we treat it as a script under
# test and use crucible's own `run` helper to exercise it.
#
# shellcheck disable=SC2154  # $stdout/$stderr/$status are populated by run().
# shellcheck disable=SC2016  # mk_test bodies are intentionally single-quoted (literal).
# shellcheck disable=SC2103  # cd .. inside a test is fine; tests run in a subshell.

CRUCIBLE="$PROJECT_ROOT/plugins/crucible/crucible.sh"

# Write a test file into the current tmpdir and return its path.
mk_test() {
    local name="$1"; shift
    local path="$PWD/${name}_test.sh"
    {
        echo '#!/usr/bin/env bash'
        printf '%s\n' "$@"
    } > "$path"
    printf '%s' "$path"
}

# ---- basic assertion behavior ----

test_assert_equal_passes_on_match() {
    local f
    f=$(mk_test pass \
        'test_eq() { assert_equal "a" "a"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "✓ test_eq"
    assert_stdout_contains "all passed"
}

test_assert_equal_fails_on_mismatch() {
    local f
    f=$(mk_test fail \
        'test_eq() { assert_equal "a" "b"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stdout_contains "✗ test_eq"
    assert_stderr_contains "expected"
}

test_assert_contains_failure_shows_actual() {
    local f
    f=$(mk_test contains \
        'test_c() { assert_contains "alpha beta" "gamma"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stderr_contains "alpha beta"
}

# ---- run helper: stdout / stderr separation ----

test_run_separates_streams() {
    local f
    f=$(mk_test sep \
        'test_s() {' \
        '    run bash -c "echo out; echo err >&2"' \
        '    assert_success' \
        '    assert_stdout_eq "out"' \
        '    assert_stderr_eq "err"' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "✓ test_s"
}

test_run_failure_does_not_abort_test() {
    # A non-zero exit from the command under `run` must NOT trip set -e.
    local f
    f=$(mk_test rfail \
        'test_r() {' \
        '    run bash -c "exit 7"' \
        '    assert_status 7' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "✓ test_r"
}

test_run_aware_assertion_dumps_capture_on_failure() {
    # When assert_stdout_eq fails, stdout/stderr/status should appear in the
    # diagnostic output — this is the "first-class" promise.
    local f
    f=$(mk_test dump \
        'test_d() {' \
        '    run bash -c "echo actually-this"' \
        '    assert_stdout_eq "expected-that"' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stderr_contains "actually-this"
    assert_stderr_contains "expected-that"
    assert_stderr_contains "status:"
}

test_lines_array_indexable() {
    local f
    f=$(mk_test lines \
        'test_l() {' \
        '    run bash -c "printf %s\\\\n one two three"' \
        '    assert_line 0 "one"' \
        '    assert_line 2 "three"' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
}

# ---- isolation: each test gets a fresh cwd ----

test_each_test_gets_fresh_cwd() {
    local f
    f=$(mk_test isol \
        'test_a() { echo hi > marker; assert_file_exists marker; }' \
        'test_b() { assert_file_not_exists marker; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "✓ test_a"
    assert_stdout_contains "✓ test_b"
}

# ---- setup / teardown ----

test_setup_runs_before_each_test() {
    local f
    f=$(mk_test setup \
        'setup() { echo seeded > seed; }' \
        'test_a() { assert_file_exists seed; }' \
        'test_b() { assert_file_exists seed; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
}

test_teardown_failure_fails_the_test() {
    local f
    f=$(mk_test teardown \
        'teardown() { return 1; }' \
        'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stdout_contains "✗ test_a"
}

# ---- skip / fail ----

test_skip_marks_test_skipped() {
    local f
    f=$(mk_test skip \
        'test_s() { skip "needs network"; assert_equal 1 2; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "↷ test_s"
    assert_stdout_contains "needs network"
    assert_stdout_contains "skipped"
}

test_explicit_fail_fails_the_test() {
    local f
    f=$(mk_test xfail \
        'test_x() { fail "nope"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stderr_contains "nope"
}

# ---- discovery & filtering ----

test_discovery_walks_directory() {
    mkdir -p sub
    mk_test a > /dev/null
    cd sub || return 1
    mk_test b > /dev/null
    cd ..  || return 1
    run env NO_COLOR=1 bash "$CRUCIBLE" "$PWD"
    assert_success
    # Both files should have been picked up.
    assert_stdout_contains "a_test.sh"
    assert_stdout_contains "b_test.sh"
}

test_filter_runs_only_matching_tests() {
    local f
    f=$(mk_test filt \
        'test_one() { assert_equal 1 1; }' \
        'test_two() { assert_equal 1 2; }')   # would fail if executed
    run env NO_COLOR=1 bash "$CRUCIBLE" --filter test_one "$f"
    assert_success
    assert_stdout_contains "✓ test_one"
    assert_not_empty "$stdout"
    assert_not_contains "$stdout" "test_two"
}

test_filter_with_no_argument_errors() {
    local f
    f=$(mk_test fnoarg 'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --filter
    assert_failure
    assert_stderr_contains "--filter requires"
}

test_filter_with_dash_argument_errors() {
    local f
    f=$(mk_test fdash 'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --filter --help "$f"
    assert_failure
    assert_stderr_contains "--filter requires"
}

test_filter_with_invalid_regex_errors() {
    local f
    f=$(mk_test fbad 'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --filter '[unclosed' "$f"
    assert_failure
    assert_stderr_contains "invalid --filter regex"
}

test_missing_path_errors() {
    run env NO_COLOR=1 bash "$CRUCIBLE" /this/does/not/exist
    assert_failure
}

# ---- run-aware assertion called before run ----

test_assert_status_before_run_fails_cleanly() {
    local f
    f=$(mk_test noprun \
        'test_n() { assert_status 0; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stderr_contains "before run"
}

# ---- assertion family coverage ----

test_assert_match_passes_on_regex_match() {
    local f
    f=$(mk_test mok 'test_m() { assert_match "hello world" "^hello"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
}

test_assert_match_fails_on_no_match() {
    local f
    f=$(mk_test mfail 'test_m() { assert_match "hello" "^bye"; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stderr_contains "to match"
}

test_assert_empty_and_not_empty() {
    local f
    f=$(mk_test e \
        'test_e1() { assert_empty ""; }' \
        'test_e2() { assert_not_empty "x"; }' \
        'test_e3() { assert_empty "x"; }')   # this one fails
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stdout_contains "✓ test_e1"
    assert_stdout_contains "✓ test_e2"
    assert_stdout_contains "✗ test_e3"
}

test_assert_true_and_false() {
    local f
    f=$(mk_test tf \
        'test_t() { assert_true true; }' \
        'test_f() { assert_false false; }' \
        'test_tfail() { assert_true false; }')   # fails
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    assert_stdout_contains "✓ test_t"
    assert_stdout_contains "✓ test_f"
    assert_stdout_contains "✗ test_tfail"
}

# ---- multi-file isolation: setup/teardown do not leak across files ----

test_setup_from_one_file_does_not_leak_into_next() {
    mkdir -p multi
    cat > multi/a_test.sh <<'EOF'
setup() { echo from-a > witness; }
test_a() { assert_file_exists witness; }
EOF
    cat > multi/b_test.sh <<'EOF'
test_b() { assert_file_not_exists witness; }
EOF
    run env NO_COLOR=1 bash "$CRUCIBLE" multi/
    assert_success
    assert_stdout_contains "✓ test_a"
    assert_stdout_contains "✓ test_b"
}

# ---- NO_COLOR suppression ----

test_no_color_suppresses_escape_sequences() {
    local f
    f=$(mk_test nc 'test_n() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    # ANSI CSI introducer is ESC [ ; if it appears anywhere the suppression failed.
    assert_not_contains "$stdout" $'\033['
}

# ---- help ----

test_help_flag_prints_usage_and_exits_zero() {
    run env NO_COLOR=1 bash "$CRUCIBLE" --help
    assert_success
    assert_stdout_contains "Usage:"
    assert_stdout_contains "PROJECT_ROOT"
}

# ---- assert_output_* family parity ----

test_assert_output_contains_passes() {
    local f
    f=$(mk_test outc \
        'test_o() {' \
        '    run bash -c "echo on-out; echo on-err >&2"' \
        '    assert_output_contains "on-out"' \
        '    assert_output_contains "on-err"' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
}

# ---- multi-line assert_equal renders as labeled blocks ----

test_multiline_assert_equal_uses_block_dumper() {
    local f
    f=$(mk_test ml \
        'test_m() {' \
        '    local exp actual' \
        '    exp=$(printf "line1\nline2\nline3")' \
        '    actual=$(printf "line1\nDIFFERENT\nline3")' \
        '    assert_equal "$exp" "$actual"' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_failure
    # The block dumper labels the operands and shows each indented on its own line.
    assert_stderr_contains "expected:"
    assert_stderr_contains "actual:"
    assert_stderr_contains "DIFFERENT"
    # The %q single-line form would have produced something like $'line1\nDIFFERENT\nline3';
    # ensure that single-line escape is NOT what we see.
    assert_not_contains "$stderr" 'expected $'
}

# ---- ASCII fallback ----

test_ascii_flag_replaces_unicode_markers() {
    local f
    f=$(mk_test ascii \
        'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --ascii "$f"
    assert_success
    assert_stdout_contains "ok test_a"
    assert_not_contains "$stdout" "✓"
}

test_crucible_ascii_env_replaces_unicode_markers() {
    local f
    f=$(mk_test asciienv \
        'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 CRUCIBLE_ASCII=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "ok test_a"
}

# ---- example: greet --shout without a name errors with usage ----

test_greet_shout_without_name_prints_usage() {
    run "$PROJECT_ROOT/examples/greet.sh" --shout
    assert_failure
    assert_stderr_contains "usage:"
}

# ---- file-level: syntax error in a test file is reported as a failure ----

test_syntax_error_in_test_file_reports_failure() {
    local path="$PWD/syntax_test.sh"
    # Deliberately malformed: unterminated function body.
    printf 'test_a() {\n' > "$path"
    run env NO_COLOR=1 bash "$CRUCIBLE" "$path"
    assert_failure
    assert_stdout_contains "(syntax error)"
}

test_well_formed_file_with_no_tests_is_silent_zero() {
    local f
    f=$(mk_test empty 'helper() { :; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "all passed"
}

# ---- --filter matching zero tests exits 2 ----

test_filter_matching_zero_tests_exits_two() {
    local f
    f=$(mk_test fz 'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --filter zzz_no_match "$f"
    assert_status 2
    assert_stderr_contains "no tests matched filter"
}

# ---- --list enumerates without running ----

test_list_enumerates_without_executing() {
    local f
    f=$(mk_test ls \
        'test_a() { assert_equal 1 2; }' \
        'test_b() { assert_equal 1 2; }')   # both would fail if executed
    run env NO_COLOR=1 bash "$CRUCIBLE" --list "$f"
    assert_success
    assert_stdout_contains "test_a"
    assert_stdout_contains "test_b"
}

test_list_honors_filter() {
    local f
    f=$(mk_test lsf \
        'test_keep_me() { :; }' \
        'test_skip_me() { :; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" --list --filter keep "$f"
    assert_success
    assert_stdout_contains "test_keep_me"
    assert_not_contains "$stdout" "test_skip_me"
}

# ---- --verbose dumps captures on pass when run was called ----

test_verbose_dumps_captures_on_pass() {
    local f
    f=$(mk_test vrb \
        'test_v() {' \
        '    run bash -c "echo on-out; echo on-err >&2"' \
        '    assert_success' \
        '}')
    run env NO_COLOR=1 bash "$CRUCIBLE" -v "$f"
    assert_success
    # Capture dump appears on stderr.
    assert_stderr_contains "on-out"
    assert_stderr_contains "on-err"
    assert_stderr_contains "status: 0"
}

test_verbose_silent_on_pass_when_no_run_call() {
    local f
    f=$(mk_test vnr 'test_nr() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" -v "$f"
    assert_success
    assert_stderr_empty
}

# ---- skip guard: calling skip outside a test subshell must not kill the runner ----

test_skip_at_file_toplevel_does_not_kill_runner() {
    # `skip` at module level runs during `source` in the parent runner shell,
    # where _CRUCIBLE_SKIP_FILE is unset. The guard must refuse to exit; the
    # runner should still execute the actual test inside the file.
    local f
    f=$(mk_test toplevelskip \
        'skip "should-not-skip-anything"' \
        'test_a() { assert_equal 1 1; }')
    run env NO_COLOR=1 bash "$CRUCIBLE" "$f"
    assert_success
    assert_stdout_contains "✓ test_a"
    assert_stderr_contains "skip() called outside a test"
}
