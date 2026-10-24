## Starting a session

1. Read this file and `TASKS.md`.
2. Take the first task marked `[~]`; if none, the first `[ ]` in order.
3. Read only the documents the task links to and its spec (the `Спека:` line).
4. Do the task, check it against the spec's «Готово, когда», update `TASKS.md`.

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
7. **Spec first, then task, then code.** Any behaviour change follows `change-workflow`. Without a
   spec you may only fix code to match already described behaviour, refactor without behaviour
   change, fix typos and docs.

## Skills

Load a skill only when its situation from the table below occurs, not in advance. Do not load the
same skill twice in a session. Library and tool docs come through the `ctx7` CLI:
`npx ctx7@latest library <name> "<query>"`, then `npx ctx7@latest docs <id> "<query>"`.

Deviations of the project from a skill are written in the project section of this file, never in
the skill files: skills are installed as is.

## Language

Documents, task notes, docstrings, code comments and commit messages are in Russian. Code,
identifiers, metric names, log and exception messages are in English.
