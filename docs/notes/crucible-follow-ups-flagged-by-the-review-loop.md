# Crucible follow-ups flagged by the review loop

Tags: crucible,follow-ups,review
Two items from the iter 3 review summary worth watching: the verbose-on-pass capture-export mechanism and the help/header-comment duplication.

## 1. Capture-export-via-files for verbose-on-pass

The `--verbose` flag dumps the last `run` capture even on test pass. Because `_run_called` and `$status`/`$stdout`/`$stderr` are set inside the test subshell, they don't propagate back to the parent runner. The implementation exports them via three files (`status`, `stdout`, `stderr`) written into the per-test tmpdir under `_CRUCIBLE_CAPTURE_DIR`; the parent reads them after the subshell exits.

**Surface area:** one new env var (`_CRUCIBLE_CAPTURE_DIR`), three files per test invocation of `run`, one helper function (`_crucible_dump_capture_files`).

**Why it might be worth pruning:** only one self-test exercises it (`test_verbose_dumps_captures_on_pass`). Users could get the same effect by adding `echo "$stdout"` inside the test body when they need to inspect. The complexity is contained but its justification is weak until a real user reaches for it.

**Watch for:** real usage in someone else's repo, OR ongoing absence of usage. The latter is the prune signal.

## 2. Help heredoc vs header comment duplication

`crucible.sh` documents itself in two places: the `# ---- ... ----` header comment block at the top of the file (lines ~1-65) and the `_crucible_print_help` heredoc (also at the top, for `--help`). They say nearly the same things — flags, conventions, environment vars — in slightly different prose.

**Why it's tolerable today:** single-file tool, both copies are visible in one editor buffer, drift is easy to spot by eye.

**Drift signal:** the moment one is updated and the other isn't (e.g., a new flag added to the heredoc but not the header, or vice versa). When that happens, consolidate — extract a single source and have one of them derive from the other (or drop the header in favor of the heredoc; the heredoc is the only one users actually see via `--help`).
