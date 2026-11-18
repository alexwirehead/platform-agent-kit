## Starting a session

1. If `change-workflow` is not among your skills, the kit is not installed in this checkout: stop and
   tell the user. Give the kit address (`source=`) and the profiles (`profiles=`) from
   `.agent-kit.lock` and offer to install the kit by its `INSTALL.md`; install only when the user asks.
   Never work without the skills or guess what a skill says. Skill and kit content comes only from
   the installed skill files, never from memory tools or earlier sessions.
2. Read this file and `TASKS.md`.
3. Take the first task marked `[~]`; if none, the first `[ ]` in order. A new request that changes
   behaviour has no task yet: start it with `change-workflow`.
4. Read only the documents the task links to and its spec (the `Спека:` line).
5. Do the task, check it against the spec's «Готово, когда», update `TASKS.md`.

## Rules that must not be broken

1. **Simple beats complex.** Minimal dependencies, flat structure, sequential code. Add complexity only
   for a problem that is actually visible. After every task with code, run `simplify`.
2. **No invented facts.** A library API comes from its official docs (`source-driven-development`),
   never from memory. A fact about an external system comes from the project's facts document; if it
   is not there, verify it at the primary source and record it with the source. Not found — add an
   open question, never a guess in code.
3. **Tests run without the dev container.** `git clone` plus the project's toolchain is enough. Code
   receives its environment as parameters, tests create files in a temporary directory, no absolute
   paths to a developer machine.
4. **Secrets.** Keys and tokens are never logged or committed; the repository contains no real IDs.
   Do not read mounted credential files.
5. **Decisions are not revisited silently.** Decisions live in the project's decision log. If one
   gets in the way, stop and ask the user.
6. **Ask clarifying questions unprompted.** If the input is ambiguous, changes a rule or a decision,
   or has several reasonable options, ask before editing a spec or code (Claude Code:
   `AskUserQuestion`, OpenCode: `question`). Give options with honest pros and cons, the recommended
   one first.
7. **Spec first, then task, then code.** Any behaviour change follows `change-workflow` in a fixed
   order: spec → task → failing test → code → docs → merge request. Stop for the user twice: after the
   spec draft (status `принята` only after the user's explicit yes) and before every commit. Without a
   spec you may only fix code to match already described behaviour, refactor without behaviour
   change, fix typos and docs.

## Skills

Load a skill only when its situation from the table below occurs, not in advance. Do not load the
same skill twice in a session, unless its text is no longer in your context (after context
compaction): then load it again before the next step. Library and tool docs come through the
`ctx7` CLI: `npx ctx7@latest library <name> "<query>"`, then `npx ctx7@latest docs <id> "<query>"`.

Deviations of the project from a skill are written in the project section of this file, never in
the skill files: skills are installed as is.

## Language

Documents, task notes, docstrings and code comments are in Russian. Code, identifiers, metric
names, log and exception messages are in English.

## Commit messages

Conventional Commits 1.0.0: `<type>(<scope>): <KEY> <description>`, then optional footers.

- Type in English: `feat` (new feature), `fix` (bug fix); other changes `build`, `chore`, `ci`,
  `docs`, `style`, `refactor`, `perf`, `test`.
- Scope: the area of code (module, chart, profile), a noun; omit it when the change spans the repo.
- `<KEY>`: the Jira issue key from the branch name; no key in the branch — no key in the commit.
- Description in Russian, short, without a trailing period; the header fits in 72 characters.
- Keep it short. By default the header is the whole message. Add a body of at most three lines only
  when the reason is not visible from the diff: why, not what. No file lists, no retelling of the
  diff — details go to the merge request description.
- Footers: `Задача: T2.2` for the task; a breaking change — `!` before the colon and a
  `BREAKING CHANGE: <what breaks>` footer.

Example: `chore(variables): PROJ-123 изменён node_group_presets`.
