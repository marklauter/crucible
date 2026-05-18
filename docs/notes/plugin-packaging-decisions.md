# Plugin packaging decisions

Decisions made while converting crucible from a standalone bash runner into a Claude Code plugin. One section per resolved open question; updated as questions resolve.

The framing that grounds these decisions: the repo's identity is a Claude plugin that is a skill that knows how to run a bash script to test bash scripts. The plugin is the shippable artifact; everything else is repo infrastructure.

## Marketplace naming — `msl.armory.crucible`

The marketplace `name` is `msl.armory.crucible`. The plugin `name` stays `crucible`. Install command is `/plugin install crucible@msl.armory.crucible`.

The doubled `crucible@crucible` (which would result from naming both "crucible") was visually awkward. The `msl.armory.` prefix also leaves room for other MSL Armory plugins to live alongside crucible in the same marketplace family without renaming later.

## Skills are self-contained

A skill referencing an external file path expects that file to exist on the consumer's machine. For installed plugin users, only the plugin's own tree is present — `examples/` and `tests/` (kept at repo root, per the decision below) are not part of the install. A SKILL that says "see `examples/greet_test.sh`" is broken for the installed user it exists to teach.

Skills inline their own examples. Reference shapes, canonical samples, and worked walkthroughs live inside the SKILL body. Path references inside skill prose use generic placeholders (`$PROJECT_ROOT/bin/your-script.sh`) rather than the source tree's literal paths.

## Examples and tests stay at repo root

`examples/` and `tests/` remain at the repo root, outside `plugins/crucible/`. The plugin directory holds only what ships to a user via `/plugin install`.

The analogy: when you install a NuGet package you don't also receive its GitHub wiki and unit test code. `examples/greet.sh` and `examples/greet_test.sh` are the showcase the maintainers use to demonstrate and validate the runner. `tests/self_test.sh` is QA for the runner itself. Neither is something an installed plugin user needs; both are repo artifacts.

CI invokes `bash plugins/crucible/crucible.sh examples/` and `bash plugins/crucible/crucible.sh tests/` from the repo root, which keeps the dev-loop simple.

## Plugin manifest is metadata-only — autodiscovery handles the rest

`plugin.json` carries identity and polish fields; it does not enumerate skills or commands. Claude Code autodiscovers skills from `skills/<name>/SKILL.md` at the plugin root.

Required and optional fields the plugin uses: `name` (also the namespace prefix for skill invocation), `description`, `version`, `author`, `license`, `homepage`, `repository`, `keywords`. The `homepage` points at the wiki — that's where documentation lives — and `repository` points at the GitHub repo. Both are polish for the plugin manager UI.

## Skills, not commands

The `commands/` directory is the legacy pattern; the Claude Code docs explicitly recommend `skills/` for new plugins. Crucible ships skills exclusively — there is no `commands/` directory.

## Skills teach, they do not command

A skill is a college degree in a box — instructional material the agent reads to learn how to perform a class of task. It teaches *how to fight*, not *fight now*. A skill named "run the tests" that just expands to "execute `bash crucible.sh tests/`" is a directive, not a degree, and does not belong.

The implication: there is no `/crucible:run` skill. If the agent knows what crucible is and what the user wants, the agent invokes the runner directly. The skill teaches the agent enough about crucible — its flags, its output format, debugging hints, common failure modes — that the agent can decide *when* and *how* to invoke it, and can also teach a human collaborator to do the same.

## Three skills planned for this plugin

- `writing-bash-tests` — how to author test files against crucible. Already drafted.
- `running-bash-tests` (working name) — operator's manual for the runner: invocation patterns, output interpretation, `--filter` / `--list` / `-v` use, common failure modes, how to teach a human collaborator to use it.
- `writing-bash-scripts` (working name) — bash craftsmanship as a skill, analogous to writing-csharp in msl.armory: idioms, hygiene, defensive patterns, style. The scripts being tested by crucible.

Each is invokable in both modes — the user can type `/crucible:<skill-name>` to load it explicitly, and the agent can also load it whenever the task context matches its `description`. `disable-model-invocation` stays `false` (its default) on every skill in this plugin. Invocation is just knowledge loading; there is no reason to lock one of the two paths.

## `/crucible-new-test` — dissolved into `writing-bash-tests`

The original question asked what a `/crucible-new-test` slash command should scaffold: bare stub, target-inspected stubs, or always-both-styles. The skills-teach-don't-command stance dissolves it. There is no slash command, and scaffolding is a capability that emerges from the agent loading `writing-bash-tests`. The skill teaches the canonical shape — `SCRIPT_UNDER_TEST="$PROJECT_ROOT/..."` header, alternating basic and `run`-based sections, naming convention — and points at `examples/greet_test.sh` as the reference.

The residual quality question — is `writing-bash-tests` concrete enough that a cold-loaded agent can scaffold a working test? — is untested and tracked as a separate validation task on the refactor list.

## Plugin usage is the primary path; no top-level wrapper

Crucible's primary distribution is `/plugin install crucible@msl.armory.crucible`. The runner is reachable via the plugin install; the `writing-bash-tests` skill teaches an agent how to use it.

Non-plugin users who want only the bash script can still `curl` it from `plugins/crucible/crucible.sh` in the source tree, but that path is a secondary affordance — not a design constraint. No thin wrapper at the repo root, no shorter URL, no release-asset distribution at this stage. If `/plugin install` is unavailable to a user, the curl path is documented in the wiki but is not what shapes the layout.

The release-asset distribution (stable `releases/latest/download/crucible.sh` URL) is a future option tied to the release-tagging task; it is not a refactor decision.
