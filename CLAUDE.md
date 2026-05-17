# CLAUDE.md

Project conventions and mechanical reminders for Claude sessions working on **crucible** — a tiny bash test runner, packaged as a Claude Code plugin (a skill that knows how to run a bash script to test bash scripts).

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest, makes the repo installable via `/plugin marketplace add`.
- `plugins/crucible/.claude-plugin/plugin.json` — plugin manifest.
- `plugins/crucible/crucible.sh` — the runner (the executable artifact).
- `plugins/crucible/skills/writing-bash-tests/SKILL.md` — the skill that teaches the conventions below.
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

1. Bump `CRUCIBLE_VERSION` near the top of `plugins/crucible/crucible.sh` (currently `0.1.0`). Pattern: `MAJOR.MINOR.PATCH`.
2. Bump the matching `version` field in `plugins/crucible/.claude-plugin/plugin.json` so the plugin manifest and the script agree.
3. Make sure `bash plugins/crucible/crucible.sh --version` prints the new value.
4. Add a journal entry under `docs/journal/` describing what the release contains (use the `journaling` skill).
5. Tag the commit: `git tag v$(bash plugins/crucible/crucible.sh --version | cut -d' ' -f2)`.

## Running checks locally

```bash
bash plugins/crucible/crucible.sh examples/ tests/      # full suite — must be 45+ green
shellcheck --exclude=SC2329,SC2317 plugins/crucible/crucible.sh examples/*.sh tests/*.sh
```

`SC2329` (unused function) and `SC2317` (unreachable code) are suppressed because every assertion and the `run` helper are invoked indirectly via sourcing — shellcheck cannot see those call sites, so it flags both the definitions and the bodies as dead.

## When adding a new flag

The flag list lives in **two** places:
- The header comment block at the top of `plugins/crucible/crucible.sh`.
- The `_crucible_print_help` heredoc (what `--help` actually prints).

Update both, or the next reviewer will flag the drift. This duplication is a known follow-up (see `docs/notes/crucible-follow-ups-flagged-by-the-review-loop.md`).
