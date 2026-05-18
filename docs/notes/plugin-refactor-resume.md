# Plugin refactor — resume here

Where the in-flight conversion of crucible from a standalone bash runner into a Claude Code plugin stands. Read this first when resuming.

## Start of session: rebuild the task list

The TaskList tool does not persist across sessions. To resume work:

1. Read this note end to end.
2. Read [[plugin-packaging-decisions]] for the canonical record of decisions already made.
3. Run `git status` and `git log -5` to confirm the working tree matches the snapshot below.
4. Construct a fresh task list with TaskCreate covering the pending work below, in roughly the order shown.
5. Resume the open questions before the pending work — they unblock the rest.

## Where we are

Crucible is mid-conversion from a tiny single-file bash test runner into a Claude Code plugin packaged as a skill-plus-script pair.

The framing that grounds every decision: the repo's identity is shifting from a bash script to a Claude plugin that is a skill that knows how to run a bash script to test bash scripts. The skill is the primary artifact; the runner is the tool the skill wields.

Scope is this repo only. The msl.armory migration is downstream and out of scope for this refactor's done-state.

**HEAD commit:** `3bb099a` — merge of local refactor commits with a remote README touch-up.

Recent history (newest first):

- `3bb099a` Merge branch 'main' — integrates local refactor with the remote.
- `ccf2692` flesh out the plugin: skill body, manifests, decisions — SKILL body, README rewrite, plugin.json polish, marketplace name set to `msl.armory.crucible`, decisions note, this resume note.
- `0104a32` Update README.md — small remote touch-up (period removal in the tagline).
- `976c9fa` package crucible as a claude code plugin — layout move, manifests, stubbed SKILL, path updates.

Local and `origin/main` are in sync. Working tree clean.

## Open questions still to resolve

### #26 — automate version-sync between `crucible.sh` and `plugin.json`

Two version strings need to agree: `CRUCIBLE_VERSION="0.1.0"` in `plugins/crucible/crucible.sh` and `"version": "0.1.0"` in `plugins/crucible/.claude-plugin/plugin.json`. The release-bump checklist tells humans to bump both, but humans forget.

Options considered:

- **A. CI gate.** A workflow step that greps both versions and fails if they disagree. About six lines added to `.github/workflows/tests.yml`. Caught at PR time, no new tooling.
- **B. Bump script.** `scripts/bump-version.sh <new>` updates both files in one shot. Better release-day UX but still depends on a human remembering to run it — same failure mode as the checklist.
- **C. Single source of truth + generation.** Either crucible.sh reads from plugin.json at runtime (ugly JSON parse in bash) or a `VERSION` file feeds both via a build step. Overkill for two files; resists the single-file philosophy.

Current lean: **A**, alone. B is a small later upgrade if release ergonomics actually bite, but the gate is enough.

Implementation sketch:

```yaml
- name: Verify version sync
  shell: bash
  run: |
    script=$(sed -n 's/^CRUCIBLE_VERSION="\(.*\)"$/\1/p' plugins/crucible/crucible.sh)
    plugin=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' plugins/crucible/.claude-plugin/plugin.json | head -1)
    [ "$script" = "$plugin" ] || { echo "version drift: script=$script plugin=$plugin" >&2; exit 1; }
```

Awaiting: user confirmation of A before implementing.

### #27 — separate plugin README inside `plugins/crucible/`?

Most plugin marketplaces show some text in the plugin's "details" panel when a user runs `/plugin list`. Does that pull from `plugin.json.description`, or from a `README.md` inside the plugin directory? If the latter, the plugin needs its own `README.md` (likely a slimmer cousin of the repo root README).

Resolving this needs either a `WebFetch` of the plugins-reference page (`https://code.claude.com/docs/en/plugins-reference`) or a hands-on `/plugin install` test.

Current lean: **no separate README until the plugin-manager UI tells us we need one.** The root README is comprehensive; a duplicate inside the plugin risks drift. This is a low-confidence lean — verify before committing to it.

## Pending work

In suggested resolution order. Construct a fresh task list from this section at session start. The bracketed IDs reference the prior session's tasks for cross-referencing the conversation history.

1. **Resolve open question #26** (version-sync automation). Confirm Option A; implement the CI gate.
2. **Resolve open question #27** (separate plugin README). Verify with docs or hands-on test; decide.
3. **Run reviewing-documentation pass** over `README.md` and `plugins/crucible/skills/writing-bash-tests/SKILL.md`. Triage findings; fix in a follow-up commit. [was #28]
4. **Author `running-bash-tests` skill** at `plugins/crucible/skills/running-bash-tests/SKILL.md`. Operator's manual: invocation patterns, output interpretation, `--filter` / `--list` / `-v` use, common failure modes, how to teach a human collaborator. [was #39]
5. **Author `writing-bash-scripts` skill** at `plugins/crucible/skills/writing-bash-scripts/SKILL.md`. Bash craftsmanship analogous to `writing-csharp` in msl.armory — idioms, hygiene, defensive patterns, style. [was #40]
6. **Commit the two new skills.** [was #41]
7. **Cold-test `writing-bash-tests`.** Spin a fresh agent with only that skill loaded, give it a small bash script it has not seen, ask for a `_test.sh` covering the script's behavior, run the generated test through crucible. Identify gaps in the SKILL — vague guidance, missing patterns, surprises — and patch the SKILL. Iterate until cold scaffolding consistently produces a working test. Cover at least two shapes: a script that prints to stdout, and a script with flags + stderr usage. [was #42]
8. **Verify the plugin installs and loads locally.** User runs `/plugin marketplace add D:/crucible/crucible` then `/plugin install crucible@msl.armory.crucible` in a Claude Code session. Confirm skills surface; confirm `/crucible:writing-bash-tests` activates on a bash-test prompt. [was #34]
9. **Update follow-ups note.** Audit `docs/notes/crucible-follow-ups-flagged-by-the-review-loop.md`; some items may be superseded by the plugin layout. [was #35]
10. **Journal entry.** Use the `journaling` skill — dated entry under `docs/journal/` capturing the refactor: what shifted, why, what remains. [was #36]
11. **Tag v0.2.0 release.** Bump `CRUCIBLE_VERSION` (crucible.sh) and `version` (plugin.json) to `0.2.0` together. Follow the `CLAUDE.md` release-bump checklist. Push origin main and the tag. [was #37]
12. **Downstream — audit the crucible wiki** at `github.com/marklauter/crucible/wiki`. Installation page should mention `/plugin install crucible@msl.armory.crucible` alongside the curl method. Separate git repo from this one; not blocking the refactor's done state. [was #38]

## Decisions captured

Full reasoning lives in [[plugin-packaging-decisions]]. Summary below.

- **Marketplace name:** `msl.armory.crucible`. Plugin name stays `crucible`. Install command: `/plugin install crucible@msl.armory.crucible`.
- **Examples and tests stay at repo root.** The plugin directory holds only what ships via `/plugin install`. Examples and self-tests are repo artifacts, not user-facing material — analogous to a NuGet package not shipping its GitHub wiki and unit tests.
- **`plugin.json` is metadata-only.** Autodiscovery handles skills from `skills/<name>/SKILL.md`. Added `homepage` (the wiki URL) and `repository` (the GitHub URL) for plugin-manager polish.
- **Skills, not commands.** The `commands/` directory is the legacy pattern; the Claude Code docs explicitly recommend `skills/` for new plugins. Crucible ships skills exclusively — no `commands/` directory at all.
- **Skills teach, they do not command.** A skill is a college degree in a box — instructional material, not a directive. Both user and model invocation paths stay open (`disable-model-invocation` stays `false` on every skill in this plugin). Invocation is just knowledge loading.
- **Three skills planned for this plugin:**
  - `writing-bash-tests` — drafted, uncommitted.
  - `running-bash-tests` — todo (operator's manual for the runner).
  - `writing-bash-scripts` — todo (bash craftsmanship, analogous to `writing-csharp`).
- **Skills are self-contained.** A skill referencing an external file path expects that file to exist on the consumer's machine; for installed plugin users, only the plugin tree is present. Skills inline their own examples; path references inside skill prose use generic placeholders like `$PROJECT_ROOT/bin/your-script.sh`, not the source tree's literal paths.
- **`/crucible-new-test` is dissolved.** Scaffolding capability emerges from loading `writing-bash-tests` — the skill teaches the canonical shape, the agent produces files from that knowledge. Residual quality question tracked as the cold-test task.
- **Plugin usage is the primary distribution.** `/plugin install` is canonical. Non-plugin users can `curl` from `plugins/crucible/crucible.sh` but that path is a secondary affordance, not a layout constraint. No top-level wrapper script. Release-asset distribution (a stable `releases/latest/download/crucible.sh` URL) is a future option tied to the v0.2.0 tagging task.

## Completed work

- Layout move: `crucible.sh` relocated to `plugins/crucible/crucible.sh` (git history preserved via `git mv`).
- Manifests: `.claude-plugin/marketplace.json` and `plugins/crucible/.claude-plugin/plugin.json` authored.
- Path references updated in `.github/workflows/tests.yml`, `CLAUDE.md`, `README.md`, `tests/self_test.sh`.
- Full `writing-bash-tests` SKILL.md authored — Philosophy / Guidance / Validation, with the canonical test-file shape inlined for self-containment.
- README rewritten for plugin identity; install section reordered to lead with `/plugin install`.
- `plugin.json` polished with `homepage`, `repository`, expanded description for the multi-skill scope.
- Marketplace name decided and applied: `msl.armory.crucible`.
- Decisions note authored at `docs/notes/plugin-packaging-decisions.md`.
- Slash command format verified: skills are the modern path; `commands/` is legacy and not used in this plugin.
- Suite verified green: 45 tests passing under the new layout; shellcheck clean.

All of the above is committed and pushed to `origin/main`. Working tree clean.

## Related notes

- [[plugin-packaging-decisions]] — canonical record of resolved questions and their reasoning.
- [[crucible-follow-ups-flagged-by-the-review-loop]] — pre-refactor follow-ups; needs audit (pending-work item 10).
- [[using-crucible]] — pre-refactor; may need updates for plugin identity.
