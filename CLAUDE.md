# CLAUDE.md

Project conventions and mechanical reminders for Claude sessions working on **crucible** — a single-file bash test runner.

## Layout

- `crucible.sh` — the runner (the entire artifact).
- `examples/` — minimal scripts under test (`greet.sh`) and their tests.
- `tests/` — crucible's own self-tests (dogfooded against the runner).
- `docs/notes/` — wiki-style atomic notes (`taking-notes` skill).
- `docs/journal/` — dated append-only journal entries (`journaling` skill).
- `.github/workflows/tests.yml` — CI on Linux + Windows; runs examples, self-tests, and `shellcheck`.

## Conventions

- Test files end in `_test.sh`; functions start with `test_`. See README.md for the full convention list.
- Source code uses bash 4+ idioms (`mapfile`, `[[ =~ ]]`, `declare -F`).
- Tests do NOT inherit `set -u` from the runner — the runner deliberately avoids global `set -u` so user test files aren't poisoned.

## Release-bump checklist

1. Bump `CRUCIBLE_VERSION` near the top of `crucible.sh` (currently `0.1.0`). Pattern: `MAJOR.MINOR.PATCH`.
2. Make sure `bash crucible.sh --version` prints the new value.
3. Add a journal entry under `docs/journal/` describing what the release contains (use the `journaling` skill).
4. Tag the commit: `git tag v$(bash crucible.sh --version | cut -d' ' -f2)`.

## Running checks locally

```bash
bash crucible.sh examples/ tests/      # full suite — must be 45+ green
shellcheck --exclude=SC2329 crucible.sh examples/*.sh tests/*.sh
```

`SC2329` (unused function warning) is suppressed because every assertion and the `run` helper are invoked indirectly via sourcing — shellcheck cannot see those call sites.

## When adding a new flag

The flag list lives in **two** places:
- The header comment block at the top of `crucible.sh`.
- The `_crucible_print_help` heredoc (what `--help` actually prints).

Update both, or the next reviewer will flag the drift. This duplication is a known follow-up (see `docs/notes/crucible-follow-ups-flagged-by-the-review-loop.md`).
