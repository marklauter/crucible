# Add sample recipes folder for wiki references

Tags: todo,crucible,docs
Build a small recipes book under examples/ (or recipes/) showing 6-10 realistic test patterns that the wiki can deep-link into.

## Why

The `examples/greet.sh` pair is trivial — it proves the runner works but doesn't sell the library's real shape. A small recipes book gives:

- Concrete patterns the wiki can hot-link instead of repeating in prose.
- Onboarding material a colleague can copy from instead of writing tests from scratch.
- Coverage of edge cases users will hit (testing scripts with stdin, scripts with multiple flags, scripts that produce JSON, scripts under different `LC_ALL`, scripts that fork).

## Candidate recipes

Each as its own `<topic>.sh` script + `<topic>_test.sh`:

1. **Argument parsing** — script with positional + flag args; tests for happy path, missing arg, unknown flag.
2. **stdin handling** — script that reads stdin, transforms, writes stdout. Use `run bash -c '...'` to pipe.
3. **JSON output** — script that emits JSON; tests use `run` then `jq` (document the `jq` dependency).
4. **Exit code matrix** — script with three distinct error exits (2, 3, 4); tests assert each.
5. **Stderr-only diagnostics** — script that writes progress to stderr and data to stdout; tests assert the split.
6. **Multi-line output** — exercise `$lines` and `assert_line`.
7. **Filesystem side effects** — script that writes files; tests assert via `assert_file_exists` and content.
8. **Subdirectory traversal** — script that walks a dir; tests use `setup` to seed a fixture tree.
9. **Optional dependency gate** — recipe that uses `skip` when a tool isn't installed.
10. **Long-running command with timeout** — wrap with `timeout` external utility; assert behavior.

## Where it lives

Two options:

- Keep under `examples/` (current convention) — alphabetical sort, easy to find.
- New `recipes/` directory — clearer intent, separates "one demo" from "a catalogue".

Lean toward `recipes/` so `examples/` stays as "the minimum that proves the runner works" and `recipes/` is the catalogue.

## Wiki integration

Each recipe gets a sibling wiki page (or section) that:
- States the pattern in one paragraph.
- Links to the test file at a specific line range (`recipes/argparse_test.sh#L20-L40`).
- Notes any platform caveats.

## Next

Defer until at least one colleague is actively using crucible — recipe priorities are best driven by what they actually trip on. Tag stays `todo`; remove when work begins.
